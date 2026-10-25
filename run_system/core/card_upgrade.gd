## Card-upgrade resolver (in-run). Pure functions, no side effects — safe to unit
## test headless. `resolve(base)` returns the UPGRADED effective card data for a
## base card-info dict. A card JSON may carry an optional `upgrade` block
## ({cost?, title?, description?, vars?, effects?}): `vars` adds deltas to the
## card's vars and re-fills its effect template (an `effects` list there is a
## structural replacement, filled with the upgraded vars); `effects` alone is a
## full replacement. With neither, each effect type's default deltas apply (the
## `upgrade` key of its definition). Cost is only ever changed by the block.
## No `class_name` (project convention) — used via preload.
extends RefCounted

const CARD_VARS = preload("uid://dagno1w0jtl2n")  # res://core/content/card_vars.gd
const EFFECT_CATALOG = preload("uid://880atc7mnnie")  # res://battle_scene/combat/effect_catalog.gd


## Return a deep-copied, upgraded version of `base`. `base` is un-mutated.
static func resolve(base: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	var up: Dictionary = base.get("upgrade", {})
	if typeof(up) != TYPE_DICTIONARY:
		up = {}
	if up.has("cost"):
		result["cost"] = int(up["cost"])
	if up.has("title"):
		result["title"] = str(up["title"])
	if up.has("description"):
		result["description"] = str(up["description"])
	if up.has("vars") and typeof(base.get("vars")) == TYPE_DICTIONARY:
		# Var deltas (STS2 UpgradeValueBy): re-fill the card's template with the
		# upgraded vars; a structural upgrade.effects is filled the same way.
		var up_vars := CARD_VARS.add(base["vars"], up["vars"])
		result["vars"] = up_vars
		var template: Variant = up.get("effects_template", up.get("effects", base.get("effects_template", base.get("effects", []))))
		result["effects"] = CARD_VARS.substitute((template as Array).duplicate(true), up_vars)
	elif up.has("effects"):
		result["effects"] = (up["effects"] as Array).duplicate(true)
	else:
		result["effects"] = formula(base.get("effects", []))
	return result


## Generic numeric bump for cards without a bespoke `upgrade.effects`. ONLY the
## unambiguously-beneficial effect types are bumped; scaling / cost / self-debuff
## effects are deliberately excluded so they route to a bespoke `upgrade` block
## (Phase 5 audit). Field names match the real card JSON: damage/block/stat use
## `amount`; status applies use `stacks`.
static func formula(effects: Array) -> Array:
	var out: Array = effects.duplicate(true)
	for eff in out:
		if typeof(eff) != TYPE_DICTIONARY:
			continue
		var deltas: Dictionary = EFFECT_CATALOG.registry().definition(str(eff.get("type", ""))).get("upgrade", {})
		for field in deltas:
			eff[field] = int(eff.get(field, 0)) + int(deltas[field])
	return out


## True when `resolve()` would change something (card is meaningfully upgradeable).
## Used by the validator coverage warning and the upgrade modal (grey out no-op).
static func is_upgradeable(base: Dictionary) -> bool:
	if str(base.get("type", "")) == "curse":
		return false
	if base.has("upgrade"):
		return true
	var before: Array = base.get("effects", [])
	return formula(before) != before
