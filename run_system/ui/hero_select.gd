extends Control

const MAP_PACKED = preload("res://run_system/ui/map_scene.tscn")
const HERO_DIR := "res://run_system/data/heroes/"

@onready var bill_btn = $HBoxContainer/BillButton
@onready var jerry_btn = $HBoxContainer/JerryButton

# Map from hero_id → Button so we can lock/unlock individually.
var _hero_buttons: Dictionary = {}


func _ready() -> void:
	_setup_buttons()


func _setup_buttons() -> void:
	# Discover heroes from JSON dir. The existing scene has BillButton and
	# JerryButton hardcoded; we keep them as anchors and rebind to the heroes
	# we actually find, in alphabetical id order.
	var hero_ids := _list_hero_ids()
	hero_ids.sort()

	_hero_buttons.clear()

	# Bill always exists; Jerry is gated on the jerry_unlock meta upgrade.
	for hero_id in hero_ids:
		var hero_data := _load_hero(hero_id)
		var btn: Button = _button_for_hero(hero_id)
		if not btn:
			continue
		_hero_buttons[hero_id] = btn
		_apply_button_state(btn, hero_id, hero_data)


func _list_hero_ids() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open(HERO_DIR)
	if dir == null:
		return ids
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			ids.append(file_name.get_basename())
	return ids


func _load_hero(hero_id: String) -> Dictionary:
	var path := HERO_DIR + hero_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Map well-known hero ids to the existing scene buttons. Heroes beyond
## these two need a UI redesign — flag at runtime.
func _button_for_hero(hero_id: String) -> Button:
	if hero_id == "cowboy_bill":
		return bill_btn
	if hero_id == "hero_jerry_killer":
		return jerry_btn
	push_warning("hero_select: no button slot for hero '%s' — add to scene if you want it visible" % hero_id)
	return null


func _apply_button_state(btn: Button, hero_id: String, hero_data: Dictionary) -> void:
	var hero_name := str(hero_data.get("name", hero_id))
	# Jerry-style lock: gated on the jerry_unlock meta upgrade.
	if hero_id == "hero_jerry_killer":
		var unlocked: bool = MetaProgress.get_upgrade_level("jerry_unlock") > 0
		if not unlocked:
			btn.text = "🔒 %s\n(UNLOCK 100 CORE)" % hero_name.to_upper()
			btn.disabled = true
			# Disconnect any existing handler — we don't want clicks to fire.
			for cb in btn.pressed.get_connections():
				btn.pressed.disconnect(cb["callable"])
			return
	# Unlocked path
	btn.text = hero_name.to_upper()
	btn.disabled = false
	for cb in btn.pressed.get_connections():
		btn.pressed.disconnect(cb["callable"])
	btn.pressed.connect(func(): _select_hero(hero_id))


func _select_hero(hero_id: String) -> void:
	print("Selected Commander: ", hero_id)
	# Ascension defaults to highest unlocked. UI slider added in S5.
	var asc: int = MetaProgress.max_ascension
	RunManager.start_new_run(hero_id, [], asc)
	get_tree().change_scene_to_packed(MAP_PACKED)
