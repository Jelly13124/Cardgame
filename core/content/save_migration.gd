extends RefCounted

## Save migration to namespaced content IDs (phase 2a). Pure functions on the
## parsed save dictionaries; callers back the file up with `backup_once` before
## writing a migrated save. Each known ID field resolves through ModelDb with its
## category; a ref that does not resolve (retired or unknown content) is kept
## verbatim so the migration itself never drops what the player owned.
## No class_name — preload. No scene tree.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const SAVE_IO = preload("uid://seo0j510xyq1")  # res://core/save/save_io.gd

const RUN_VERSION := 2
const META_CONTENT_VERSION := 2
const BACKUP_SUFFIX := ".v1.bak"


static func run_needs_migration(d: Dictionary) -> bool:
	return int(d.get("v", 1)) < RUN_VERSION


static func meta_needs_migration(d: Dictionary) -> bool:
	return int(d.get("content_v", 1)) < META_CONTENT_VERSION


static func migrate_run(d: Dictionary) -> Dictionary:
	if not run_needs_migration(d):
		return d
	var out := d.duplicate(true)
	var hero := _ref("character", out.get("current_hero_id", ""))
	out["current_hero_id"] = hero
	var hero_data := MODEL_DB.mutable("character", hero)
	if not hero_data.is_empty():
		out["current_hero_data"] = hero_data
	elif typeof(out.get("current_hero_data")) == TYPE_DICTIONARY:
		out["current_hero_data"]["id"] = hero
	if typeof(out.get("player_deck")) == TYPE_ARRAY:
		var deck: Array = out["player_deck"]
		for i in deck.size():
			if typeof(deck[i]) == TYPE_DICTIONARY:
				deck[i]["card_id"] = _ref("card", deck[i].get("card_id", ""))
			else:
				deck[i] = _ref("card", deck[i])
	if typeof(out.get("equipped_items")) == TYPE_DICTIONARY:
		_migrate_slots(out["equipped_items"])
	if typeof(out.get("backpack")) == TYPE_ARRAY:  # bare-ok: save key
		var bag: Array = out["backpack"]  # bare-ok: save key
		for i in bag.size():
			bag[i] = _migrate_cell(bag[i])
	_migrate_list(out, "relics", "relic")
	_migrate_list(out, "tool_inventory", "tool")
	_migrate_list(out, "current_encounter", "monster")
	_migrate_list(out, "seen_random_event_ids", "event")
	_migrate_list(out, "demo_set_piece_ids_claimed", "equipment")
	_migrate_list(out, "demo_set_piece_ids_offered", "equipment")
	if out.has("demo_featured_set_id"):
		out["demo_featured_set_id"] = _ref("equipment_set", out["demo_featured_set_id"])
	out["v"] = RUN_VERSION
	return out


static func migrate_meta(d: Dictionary) -> Dictionary:
	if not meta_needs_migration(d):
		return d
	var out := d.duplicate(true)
	if typeof(out.get("upgrades")) == TYPE_DICTIONARY:
		out["upgrades"] = _migrate_keys(out["upgrades"], "base_upgrade")
	if typeof(out.get("cards_seen")) == TYPE_DICTIONARY:
		out["cards_seen"] = _migrate_keys(out["cards_seen"], "card")
	for key in ["stash", "base_loadout"]:
		if typeof(out.get(key)) == TYPE_ARRAY:
			var items: Array = out[key]
			for i in items.size():
				items[i] = _migrate_equip(items[i])
	if typeof(out.get("base_equipped")) == TYPE_DICTIONARY:
		_migrate_slots(out["base_equipped"])
	if typeof(out.get("active_bounties")) == TYPE_ARRAY:
		for entry in out["active_bounties"]:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("id"):
				entry["id"] = _ref("bounty", entry["id"])
	_migrate_list(out, "bounty_shelf", "bounty")
	if typeof(out.get("run_history")) == TYPE_ARRAY:
		for entry in out["run_history"]:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("hero_id"):
				entry["hero_id"] = _ref("character", entry["hero_id"])
	out["content_v"] = META_CONTENT_VERSION
	return out


## Copy the live save to `<file>.v1.bak` once. Returns true when written; an
## existing backup (from an earlier migration attempt) is never overwritten.
static func backup_once(relative: String) -> bool:
	var live := SAVE_IO.path(relative)
	var backup := live + BACKUP_SUFFIX
	if FileAccess.file_exists(backup) or not FileAccess.file_exists(live):
		return false
	return DirAccess.copy_absolute(live, backup) == OK


# --- helpers ------------------------------------------------------------------

static func _ref(category: String, value: Variant) -> String:
	var ref := str(value)
	if ref == "":
		return ref
	var full := MODEL_DB.resolve(category, ref)
	return full if full != "" else ref


static func _migrate_list(d: Dictionary, key: String, category: String) -> void:
	if typeof(d.get(key)) != TYPE_ARRAY:
		return
	var items: Array = d[key]
	for i in items.size():
		items[i] = _ref(category, items[i])


static func _migrate_keys(d: Dictionary, category: String) -> Dictionary:
	var out := {}
	for key in d:
		out[_ref(category, key)] = d[key]
	return out


## Equipment instance dict ({base, set_id?, ...}) or a legacy item-id string.
static func _migrate_equip(item: Variant) -> Variant:
	if typeof(item) == TYPE_STRING:
		return _ref("equipment", item)
	if typeof(item) == TYPE_DICTIONARY:
		if item.has("base"):
			item["base"] = _ref("equipment", item["base"])
		if item.has("set_id") and str(item["set_id"]) != "":
			item["set_id"] = _ref("equipment_set", item["set_id"])
	return item


static func _migrate_slots(slots: Dictionary) -> void:
	for slot in slots:
		slots[slot] = _migrate_equip(slots[slot])


## Backpack cell: null | {kind: equip, item | id} | {kind: tool, id} | currency.
static func _migrate_cell(cell: Variant) -> Variant:
	if typeof(cell) != TYPE_DICTIONARY:
		return cell
	match str(cell.get("kind", "")):
		"equip":
			if cell.has("item"):
				cell["item"] = _migrate_equip(cell["item"])
			if cell.has("id"):
				cell["id"] = _ref("equipment", cell["id"])
		"tool":
			cell["id"] = _ref("tool", cell.get("id", ""))
	return cell
