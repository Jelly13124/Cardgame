extends RefCounted

## The base-owned gear between runs (profile `base_loadout` and
## `base_equipped`, core/meta/profile_state.gd): every change goes through
## these and returns {ok, reason} (reasons: wrong_slot, not_in_backpack,
## empty_slot, backpack_full, bad_index, not_equipment) so the windows only
## render and report. Saving is the caller's (MetaProgress.save_progress()).

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd

const EQUIPMENT_SLOTS := ["head", "chest", "weapon", "hands", "accessory"]


## Wear `entry` (in the base backpack) in `slot`; a worn piece swaps back into
## the backpack.
static func equip(profile, slot: String, entry: Dictionary) -> Dictionary:
	if not _is_item(entry):
		return _fail("not_equipment")
	if not slot in EQUIPMENT_SLOTS or slot_of(entry) != slot:
		return _fail("wrong_slot")
	var idx: int = profile.base_loadout.find(entry)
	if idx < 0:
		return _fail("not_in_backpack")
	profile.base_loadout.remove_at(idx)
	var displaced: Variant = profile.base_equipped.get(slot, null)
	profile.base_equipped[slot] = entry
	if displaced != null:
		profile.base_loadout.append(displaced)  # room: the entry just left
	return {"ok": true}


## Take the piece worn in `slot` back into the backpack (of `capacity`).
static func unequip(profile, slot: String, capacity: int) -> Dictionary:
	var worn: Variant = profile.base_equipped.get(slot, null)
	if worn == null:
		return _fail("empty_slot")
	if profile.base_loadout.size() >= capacity:
		return _fail("backpack_full")
	profile.base_equipped.erase(slot)
	profile.base_loadout.append(worn)
	return {"ok": true}


## A new piece into the backpack (of `capacity`).
static func add(profile, item: Dictionary, capacity: int) -> Dictionary:
	if not _is_item(item):
		return _fail("not_equipment")
	if profile.base_loadout.size() >= capacity:
		return _fail("backpack_full")
	profile.base_loadout.append(item)
	return {"ok": true}


## Take the backpack entry at `index` out: {ok, item}.
static func remove_at(profile, index: int) -> Dictionary:
	if index < 0 or index >= profile.base_loadout.size():
		return _fail("bad_index")
	var item: Dictionary = profile.base_loadout[index]
	profile.base_loadout.remove_at(index)
	return {"ok": true, "item": item}


## Put `item` in place of the backpack entry at `index` (forge edits).
static func replace_at(profile, index: int, item: Dictionary) -> Dictionary:
	if index < 0 or index >= profile.base_loadout.size():
		return _fail("bad_index")
	if not _is_item(item):
		return _fail("not_equipment")
	profile.base_loadout[index] = item
	return {"ok": true}


## Take out every backpack entry `matches` accepts: {ok, items}.
static func remove_matching(profile, matches: Callable) -> Dictionary:
	var kept: Array = []
	var taken: Array = []
	for entry in profile.base_loadout:
		if matches.call(entry):
			taken.append(entry)
		else:
			kept.append(entry)
	profile.base_loadout = kept
	return {"ok": true, "items": taken}


## Drop malformed entries (not equipment, or worn in a slot it does not fit).
## True when anything changed.
static func sanitize(profile) -> bool:
	var changed := false
	for slot in profile.base_equipped.keys():
		var worn: Variant = profile.base_equipped[slot]
		if not _is_item(worn) or slot_of(worn) != str(slot):
			profile.base_equipped.erase(slot)
			changed = true
	var kept: Array = profile.base_loadout.filter(_is_item)
	if kept.size() != profile.base_loadout.size():
		profile.base_loadout = kept
		changed = true
	return changed


static func slot_of(item: Dictionary) -> String:
	return str(MODEL_DB.data("equipment", str(item.get("base", ""))).get("slot", ""))


static func _is_item(x: Variant) -> bool:
	return typeof(x) == TYPE_DICTIONARY and str(x.get("base", "")) != ""


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
