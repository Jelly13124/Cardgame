extends Node

## Shipped content loads cleanly through ModelDb, every card and relic is owned
## by a pool, and source code names content only by full ID. A bare content
## literal in code compares unequal to the full IDs held in run state, so it is
## a silent rule break; mark a genuine non-ID string that shares a content
## entry's name with a trailing `# bare-ok: <reason>` comment. Status names
## (several ability cards share their status's name) and theme override names
## are rule/UI keys and are skipped.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const DATA_VALIDATOR = preload("uid://bdhbhkhs5p4v3")  # res://core/content/data_validator.gd
const CARD_FACTORY_SCENE = preload("uid://diap3gdfbqvjv")  # res://ui/battle/card_framework_adapters/my_card_factory.tscn

const ID_CATEGORIES := [
	"card", "monster", "relic", "equipment", "equipment_set", "event", "tool",
	"bounty", "character", "base_upgrade", "status", "ascension", "encounter", "act", "run_config", "economy",
]
const SKIP_DIRS := ["res://addons", "res://.godot", "res://tests/fixtures", "res://.superpowers"]

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	MODEL_DB.reset()
	var errors := MODEL_DB.load_errors()
	_expect(errors.is_empty(), "content loads without errors: %s" % "; ".join(errors))
	_expect(MODEL_DB.ids("card").size() == 45, "45 cards")
	_expect(MODEL_DB.ids("monster").size() == 20, "20 monsters")
	_expect(MODEL_DB.ids("relic").size() == 30, "30 relics")
	_expect(MODEL_DB.ids("event").size() == 12, "12 events")
	_expect(MODEL_DB.ids("tool").size() == 11, "11 tools")
	_expect(MODEL_DB.has("event", "base:adrenaline_shot") and MODEL_DB.has("tool", "base:adrenaline_shot"),
		"an event and a tool may share an entry")
	_check_pools()
	var bill: Dictionary = MODEL_DB.data("character", "base:cowboy_bill")
	for card_id in bill.get("starter_deck", []):
		_expect(str(card_id).begins_with("base:"), "starter deck holds full ids: %s" % card_id)
	_check_card_lists()
	_scan_sources()
	await _check_factory()

	if failures.is_empty():
		print("[OK] content integrity passed")
		get_tree().quit(0)
		return
	push_error("content integrity failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _check_pools() -> void:
	var pooled_cards := {}
	for pool in MODEL_DB.models("card_pool"):
		for card_id in pool.data.get("cards", []):
			pooled_cards[str(card_id)] = true
	for card_id in MODEL_DB.ids("card"):
		_expect(pooled_cards.has(card_id), "card %s belongs to a pool" % card_id)
	var pooled_relics := {}
	for pool in MODEL_DB.models("relic_pool"):
		for relic_id in pool.data.get("relics", []):
			pooled_relics[str(relic_id)] = true
	for relic_id in MODEL_DB.ids("relic"):
		_expect(pooled_relics.has(relic_id), "relic %s belongs to a pool" % relic_id)


## Hero card lists live in content: each character's `exclusive_cards` and each
## run configuration's `reward_pools` must resolve to cards.
func _check_card_lists() -> void:
	for model in MODEL_DB.models("character"):
		for card_id in model.data.get("exclusive_cards", []):
			_expect(MODEL_DB.has("card", str(card_id)), "%s exclusive card %s is a card" % [model.id, card_id])
	for model in MODEL_DB.models("run_config"):
		var pools: Dictionary = model.data.get("reward_pools", {})
		for hero_id in pools:
			_expect(MODEL_DB.has("character", str(hero_id)), "%s reward pool hero %s is a character" % [model.id, hero_id])
			for card_id in MODEL_DB.data("card_pool", str(pools[hero_id])).get("cards", []):
				_expect(MODEL_DB.has("card", str(card_id)), "reward pool entry %s is a card" % card_id)


func _scan_sources() -> void:
	var entries := {}  # bare entry -> true, for every base content id
	for category in ID_CATEGORIES:
		for id in MODEL_DB.ids(category):
			entries[str(id).trim_prefix("base:")] = true
	for status in DATA_VALIDATOR.allowed_status_names():
		entries.erase(str(status))
	var retired_dirs := ["card" + "_info/", "run_system/" + "data/"]
	var content_root := "res://" + "content/"
	var override_re := RegEx.create_from_string("_override[(]\"[a-z_]+\"")
	var full_re := RegEx.create_from_string("\"base:([a-z0-9_]+)\"")
	var literal_re := RegEx.create_from_string("\"([a-z0-9_]+)\"")
	var files: Array[String] = []
	_collect("res://", files)
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line: String = lines[i]
			var code := line.get_slice("#", 0) if not line.strip_edges().begins_with("##") else ""
			if code.strip_edges().is_empty():
				continue
			var where := "%s:%d" % [path, i + 1]
			if path.find("/core/content/") == -1 and code.contains(content_root):
				failures.append("%s reads content files directly" % where)
			for retired in retired_dirs:
				if code.contains(retired):
					failures.append("%s names a retired content dir" % where)
			for m in full_re.search_all(code):
				if not _resolves_somewhere("base:" + m.get_string(1)):
					failures.append("%s names unknown content %s" % [where, m.get_string(0)])
			if line.contains("# bare-ok:"):
				continue
			code = override_re.sub(code, "", true)
			for m in literal_re.search_all(code):
				if entries.has(m.get_string(1)):
					failures.append("%s bare content literal %s" % [where, m.get_string(0)])


func _resolves_somewhere(id: String) -> bool:
	for category in ID_CATEGORIES:
		if MODEL_DB.has(category, id):
			return true
	return false


func _collect(dir_path: String, out: Array[String]) -> void:
	if dir_path.trim_suffix("/") in SKIP_DIRS:
		return
	for sub in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub), out)
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			out.append(dir_path.path_join(file_name))


func _check_factory() -> void:
	var factory = CARD_FACTORY_SCENE.instantiate()
	add_child(factory)
	await get_tree().process_frame
	var card = factory.create_card("base:reload", null)
	_expect(card != null, "factory creates base:reload")
	if card != null:
		_expect(card.card_name == "base:reload", "card node name is the full id")
		_expect(str(card.card_info.get("id", "")) == "base:reload", "card_info id is the full id")
		_expect(not card.card_info.has("name"), "card_info has no legacy name key")
		card.queue_free()
	factory.queue_free()
