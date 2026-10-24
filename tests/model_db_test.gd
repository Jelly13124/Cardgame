extends Node

## ModelDb contract: namespaced ids, ref resolution, inject/remove/reset for
## tests and mods, read-only canonical data with mutable copies.

const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
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
	_expect(MODEL_ID.key_entry("base:reload") == "reload", "base key entry is the bare entry")
	_expect(MODEL_ID.key_entry("mymod:zap") == "mymod_zap", "mod key entry carries the namespace")
	_expect(MODEL_ID.entry_of("base:reload") == "reload", "entry_of strips the namespace")
	_expect(MODEL_ID.namespace_of("mymod:zap") == "mymod", "namespace_of")
	_expect(not MODEL_ID.is_full("reload") and MODEL_ID.is_full("base:reload"), "is_full")
	_expect(MODEL_ID.make("base", "reload") == "base:reload", "make")

	MODEL_DB.reset()
	if not MODEL_DB.has("card", "base:reload"):
		MODEL_DB.inject("card", "base", "reload", {"id": "reload", "title": "Reload", "effects": []})
	MODEL_DB.inject_dir(MOD_DIR, "mymod")

	_expect(MODEL_DB.has("card", "mymod:zap"), "mod card registered")
	_expect(MODEL_DB.has("relic", "mymod:reload"), "mod relic registered")
	_expect(MODEL_DB.resolve("card", "reload") == "base:reload", "same entry in another category does not collide")
	_expect(MODEL_DB.resolve("card", "zap", "mymod") == "mymod:zap", "bare ref resolves in its own namespace")
	_expect(MODEL_DB.resolve("card", "reload", "mymod") == "base:reload", "bare ref falls back to base")
	_expect(MODEL_DB.resolve("card", "zap") == "", "base context does not see mod content")
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
	_expect(model != null and model.ns == "mymod" and model.entry == "zap" and model.category == "card", "model fields")
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
