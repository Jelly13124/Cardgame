## Card-upgrade resolver (in-run). Pure functions, no side effects — safe to unit
## test headless. `resolve(base)` returns the UPGRADED effective card data for a
## base card-info dict. Bespoke path: a card JSON may carry an optional `upgrade`
## block ({cost?, title?, description?, effects?}) that overrides those fields
## (effects = full replacement). Formula path (no `upgrade` block): bump known
## numeric fields per effect type. Cost is only ever changed by the bespoke block.
## No `class_name` (ADR-0006) — used via preload.
extends RefCounted


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
	if up.has("effects"):
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
		match str(eff.get("type", "")):
			"deal_damage", "deal_damage_all":
				eff["amount"] = int(eff.get("amount", 0)) + 2
			"gain_block":
				eff["amount"] = int(eff.get("amount", 0)) + 3
			"gain_strength", "gain_dexterity", "gain_luck", "gain_intelligence", "gain_energy":
				eff["amount"] = int(eff.get("amount", 0)) + 1
			"apply_status", "apply_status_all":
				eff["stacks"] = int(eff.get("stacks", 0)) + 1
			"draw_cards":
				eff["amount"] = int(eff.get("amount", 0)) + 1
			_:
				pass
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
