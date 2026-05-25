## Persistent meta-progression. Survives across runs. Loaded from
## user://meta.json at autoload _ready; saved on every mutation.
##
## Schema: { "core": int, "upgrades": { "<id>": int } }
##   - core: current spendable Core currency
##   - upgrades: id → current level (0..3)
extends Node

const SAVE_PATH := "user://meta.json"

signal core_changed(new_value: int)
signal upgrades_changed()

var core: int = 0
var upgrades: Dictionary = {}


func _ready() -> void:
	load_progress()


func add_core(amount: int) -> void:
	core = max(0, core + amount)
	save_progress()
	emit_signal("core_changed", core)


func get_upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func can_purchase(id: String, definition: Dictionary) -> bool:
	var tiers: Array = definition.get("tiers", [])
	var lvl := get_upgrade_level(id)
	if lvl >= tiers.size():
		return false
	return core >= int(tiers[lvl].get("cost", 999999))


func purchase_upgrade(id: String, definition: Dictionary) -> bool:
	if not can_purchase(id, definition):
		return false
	var lvl := get_upgrade_level(id)
	var cost := int(definition["tiers"][lvl]["cost"])
	core -= cost
	upgrades[id] = lvl + 1
	save_progress()
	emit_signal("core_changed", core)
	emit_signal("upgrades_changed")
	return true


func reset_all() -> void:
	core = 0
	upgrades.clear()
	save_progress()
	emit_signal("core_changed", core)
	emit_signal("upgrades_changed")


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("MetaProgress: failed to open save file for write")
		return
	f.store_string(JSON.stringify({"core": core, "upgrades": upgrades}, "  "))
	f.close()


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MetaProgress: corrupt save file at %s, renaming to .bak" % SAVE_PATH)
		DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".bak")
		return
	core = int(parsed.get("core", 0))
	var raw_upgrades = parsed.get("upgrades", {})
	if typeof(raw_upgrades) == TYPE_DICTIONARY:
		upgrades = raw_upgrades
