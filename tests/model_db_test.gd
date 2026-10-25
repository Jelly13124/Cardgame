extends Node

## ModelDb contract: namespaced ids, ref resolution, inject/remove/reset for
## tests and mods, read-only canonical data with mutable copies.

const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const CARD_UPGRADE = preload("uid://d2e2bfj6oa3yp")  # res://run_system/core/card_upgrade.gd
const MOD_DIR := "res://tests/fixtures/content_mod/"

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_expect(MODEL_ID.key_entry("base:reload") == "reload", "base key entry is the bare entry")  # bare-ok: id format fixture
	_expect(MODEL_ID.key_entry("mymod:zap") == "mymod_zap", "mod key entry carries the namespace")
	_expect(MODEL_ID.entry_of("base:reload") == "reload", "entry_of strips the namespace")  # bare-ok: id format fixture
	_expect(MODEL_ID.namespace_of("mymod:zap") == "mymod", "namespace_of")
	_expect(not MODEL_ID.is_full("reload") and MODEL_ID.is_full("base:reload"), "is_full")  # bare-ok: id format fixture
	_expect(MODEL_ID.make("base", "reload") == "base:reload", "make")  # bare-ok: id format fixture

	MODEL_DB.reset()
	if not MODEL_DB.has("card", "base:reload"):
		MODEL_DB.inject("card", "base", "reload", {"id": "reload", "title": "Reload", "effects": []})  # bare-ok: id format fixture
	MODEL_DB.inject_dir(MOD_DIR, "mymod")

	_expect(MODEL_DB.has("card", "mymod:zap"), "mod card registered")
	_expect(MODEL_DB.has("relic", "mymod:reload"), "mod relic registered")
	_expect(MODEL_DB.resolve("card", "reload") == "base:reload", "same entry in another category does not collide")  # bare-ok: id format fixture
	_expect(MODEL_DB.resolve("card", "zap", "mymod") == "mymod:zap", "bare ref resolves in its own namespace")  # bare-ok: id format fixture
	_expect(MODEL_DB.resolve("card", "reload", "mymod") == "base:reload", "bare ref falls back to base")  # bare-ok: id format fixture
	_expect(MODEL_DB.resolve("card", "zap") == "", "base context does not see mod content")  # bare-ok: id format fixture
	_expect(MODEL_DB.resolve("card", "nope") == "", "unknown ref resolves to empty")
	_expect(MODEL_DB.resolve("card", "mymod:zap") == "mymod:zap", "full ref returned as is")

	var zap: Dictionary = MODEL_DB.data("card", "mymod:zap")
	_expect(str(zap.get("id", "")) == "mymod:zap", "data id is the full id")
	_expect(str(zap["effects"][0].get("card", "")) == "base:reload", "effect card ref normalized at load")
	_expect(zap.is_read_only(), "canonical data is read-only")
	_expect(zap["effects"].is_read_only() and zap["effects"][0].is_read_only(), "nested data is read-only")
	var copy: Dictionary = MODEL_DB.mutable("card", "mymod:zap")
	_expect(not copy.is_read_only(), "mutable copy is writable")
	copy["effects"][0]["card"] = "changed"
	_expect(str(MODEL_DB.data("card", "mymod:zap")["effects"][0]["card"]) == "base:reload", "mutating a copy leaves canonical data")
	var model = MODEL_DB.get_model("card", "mymod:zap")
	_expect(model != null and model.ns == "mymod" and model.entry == "zap" and model.category == "card", "model fields")  # bare-ok: id format fixture
	_expect(MODEL_DB.get_model("card", "mymod:nope") == null, "missing model is null")
	_expect(MODEL_DB.data("card", "mymod:nope").is_empty(), "missing data is empty")
	_expect(MODEL_DB.ids("card").has("mymod:zap"), "ids lists injected content")

	var pool: Dictionary = MODEL_DB.data("card_pool", "mymod:modpool")
	_expect(Array(pool.get("cards", [])).has("mymod:zap"), "pool refs normalized")
	var bad_ref_errors := 0
	for e in MODEL_DB.load_errors():
		if "missing_card" in str(e):
			bad_ref_errors += 1
	_expect(bad_ref_errors == 1, "unresolved pool ref reported once, got %d" % bad_ref_errors)

	# Card vars: `$name` fields are substituted at load; the raw list is kept.
	MODEL_DB.inject("card", "mymod", "varcard", {
		"id": "varcard", "title": "Var Card", "type": "attack", "cost": 1,
		"vars": {"damage": 6, "weak": 2},
		"effects": [{"type": "deal_damage", "amount": "$damage"}, {"type": "apply_status", "status": "weak", "stacks": "$weak"}],
		"upgrade": {"vars": {"damage": 3}},
	})
	var varcard := MODEL_DB.data("card", "mymod:varcard")
	_expect(int(varcard["effects"][0]["amount"]) == 6 and int(varcard["effects"][1]["stacks"]) == 2, "vars substituted at load")
	_expect(str(varcard["effects_template"][0]["amount"]) == "$damage", "raw effects kept as effects_template")
	_expect(int(CARD_UPGRADE.resolve(MODEL_DB.mutable("card", "mymod:varcard"))["effects"][0]["amount"]) == 9,
		"upgrade.vars adds to the var")
	MODEL_DB.inject("card", "mymod", "badvar", {
		"id": "badvar", "title": "Bad", "type": "attack", "cost": 1, "vars": {},
		"effects": [{"type": "deal_damage", "amount": "$missing"}],
	})
	var bad_var_errors := MODEL_DB.load_errors().filter(func(e): return "missing" in str(e) and "badvar" in str(e))
	_expect(bad_var_errors.size() == 1, "unknown var is a load error")
	MODEL_DB.remove("card", "mymod:zap")
	_expect(not MODEL_DB.has("card", "mymod:zap"), "remove drops a model")
	MODEL_DB.reset()
	_expect(not MODEL_DB.has("relic", "mymod:reload"), "reset drops injected content")

	if failures.is_empty():
		print("[OK] model db contract passed")
		get_tree().quit(0)
		return
	push_error("model db contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)
