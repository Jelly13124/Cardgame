## The ONE equipment hover tooltip used by every surface (character window,
## stash window, forge window, market shelf). Owner rule (2026-07-08): generated
## item names are noise — the header is RARITY · SLOT in the rarity color; only
## set pieces keep their bespoke name line (set identity is the one name that
## still matters). Affix lines follow: curses red, positives green. The base
## JSON `bonuses` summary is the legacy fallback when no rolled instance exists.
##
## Static-only helper (no class_name, ADR-0006):
##   const EQUIP_TOOLTIP = preload("res://run_system/ui/equip_tooltip.gd")
##   cell.hover_tip = EQUIP_TOOLTIP.text(data, slot, inst)
extends RefCounted

const AFFIX_POOL = preload("res://run_system/core/affix_pool.gd")

## Rarity → BBCode hex for the header (mirrors equipment_icon.gd RARITY_COLORS).
const RARITY_HEX := {
	"common": "f2f5fa",
	"uncommon": "4fb0ff",
	"rare": "ffcf45",
	"set": "6bd975",
	"cursed": "dc5257",
}


## `data` = base equipment JSON, `slot` = its slot id, `instance` = the rolled
## per-instance dict ({} for bases with nothing rolled yet, e.g. shop shelves).
static func text(data: Dictionary, slot: String, instance: Dictionary = {}) -> String:
	var item_id := str(data.get("id", ""))
	# Prefer the instance's rolled rarity/set; fall back to the base JSON.
	var rarity := str(instance.get("rarity", data.get("rarity", "common")))
	var set_id := str(instance.get("set_id", data.get("set_id", "")))
	var lines: Array[String] = []

	# Set pieces keep their bespoke name (that IS the set identity); everything
	# else leads with rarity · slot only.
	if set_id != "":
		var name_str := Settings.t("EQUIP_%s_NAME" % item_id, str(data.get("name", item_id)))
		lines.append("[b]%s[/b]" % name_str)
	var rarity_str := Settings.t("UI_FORGE_RARITY_%s" % rarity.to_upper(), rarity)
	var slot_str := Settings.t("UI_EQUIP_SLOT_%s" % slot.to_upper(), slot)
	var hex := str(RARITY_HEX.get(rarity, RARITY_HEX["common"]))
	lines.append("[b][color=#%s]%s · %s[/color][/b]" % [hex, rarity_str, slot_str])

	# Affix block: one localized line per rolled affix.
	var affixes: Array = RunManager.equip_affixes(instance) if not instance.is_empty() else []
	if affixes.is_empty():
		var bonus_line := _format_bonuses(data.get("bonuses", {}))
		if bonus_line != "":
			lines.append("")
			lines.append(bonus_line)
	else:
		lines.append("")
		for affix in affixes:
			if typeof(affix) != TYPE_DICTIONARY:
				continue
			var label := AFFIX_POOL.describe(affix as Dictionary)
			if AFFIX_POOL.is_curse(affix as Dictionary):
				lines.append("[color=#e0584c]%s[/color]" % label)
			else:
				lines.append("[color=#5fd06a]%s[/color]" % label)

	if set_id != "":
		var set_name := Settings.t("SET_%s_NAME" % set_id, set_id.replace("_", " "))
		var prefix := Settings.t("UI_EQUIP_SET_PREFIX", "Set: {name}")
		lines.append("[i]%s[/i]" % prefix.format({"name": set_name}))
	var desc := Settings.t("EQUIP_%s_DESC" % item_id, str(data.get("description", "")))
	if desc != "":
		lines.append("")
		lines.append(desc)
	return "\n".join(lines)


## Legacy base-JSON `bonuses` summary ("+2 str, +1 luc") for items without a
## rolled instance (old saves / bases that never got affixes).
static func _format_bonuses(bonuses_v: Variant) -> String:
	if typeof(bonuses_v) != TYPE_DICTIONARY:
		return ""
	var bonuses := bonuses_v as Dictionary
	var parts: Array[String] = []
	for attr in bonuses:
		parts.append("+%d %s" % [int(bonuses[attr]), str(attr).substr(0, 3)])
	return ", ".join(parts)
