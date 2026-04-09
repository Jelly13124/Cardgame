## StatusEffectSystem — Mixin for PlayerEntity and EnemyEntity.
## Call tick_statuses() at the START of a character's turn.
## Call add_status(name, stacks) to apply effects.
##
## Supported statuses:
##   poison    — Deal stacks damage at start of turn (stacks reduce by 1 each turn)
##   burn      — Deal stacks damage at start of turn, does NOT reduce (until cured)
##   weakness  — Multiply all damage DEALT by 0.75 while stacks > 0, reduce by 1 per turn
##   strength_up — Bonus strength for stacks turns then expires
##
## Usage in parent script:
##   var status_system = StatusEffectSystem.new()
##   func add_status(name, stacks): status_system.add_status(name, stacks, self)
##   func tick_statuses(): status_system.tick(self)
extends RefCounted
class_name StatusEffectSystem

## Internal storage: { "poison": 3, "weakness": 2, ... }
var _statuses: Dictionary = {}

const STATUS_COLORS = {
	"poison":      Color(0.4, 0.9, 0.2),
	"burn":        Color(1.0, 0.4, 0.1),
	"weakness":    Color(0.7, 0.5, 0.9),
	"strength_up": Color(1.0, 0.5, 0.2),
}

const STATUS_LABELS = {
	"poison":      "☠",
	"burn":        "🔥",
	"weakness":    "⬇",
	"strength_up": "⬆STR",
}

# ─── Public API ───────────────────────────────────────────────────────────────

## Add `stacks` of a status to `entity`. Stacks add by default.
func add_status(status_name: String, stacks: int, entity: Node) -> void:
	_statuses[status_name] = _statuses.get(status_name, 0) + stacks
	_refresh_badges(entity)

## Remove all stacks of a status.
func remove_status(status_name: String, entity: Node) -> void:
	_statuses.erase(status_name)
	_refresh_badges(entity)

## Returns stacks of a status (0 if not present).
func get_stacks(status_name: String) -> int:
	return _statuses.get(status_name, 0)

func has_status(status_name: String) -> bool:
	return _statuses.get(status_name, 0) > 0

## Called at the START of an entity's turn. Deals damage, decrements stacks.
## Returns total damage dealt (so caller can absorb into take_damage).
func tick(entity: Node) -> void:
	var to_remove: Array[String] = []

	# ── Poison: deal stacks damage, decrement by 1
	if has_status("poison"):
		var dmg = _statuses["poison"]
		if entity.has_method("take_damage"):
			entity.take_damage(dmg)
		_notify(entity, "☠ POISON %d" % dmg, STATUS_COLORS["poison"])
		_statuses["poison"] -= 1
		if _statuses["poison"] <= 0:
			to_remove.append("poison")

	# ── Burn: deal stacks damage, does NOT decrement
	if has_status("burn"):
		var dmg = _statuses["burn"]
		if entity.has_method("take_damage"):
			entity.take_damage(dmg)
		_notify(entity, "🔥 BURN %d" % dmg, STATUS_COLORS["burn"])

	# ── Weakness: reduce stacks by 1 (damage mod applied at the callsite via get_damage_multiplier)
	if has_status("weakness"):
		_statuses["weakness"] -= 1
		if _statuses["weakness"] <= 0:
			to_remove.append("weakness")
			_notify(entity, "WEAKNESS FADED", STATUS_COLORS["weakness"])

	# ── Strength Up: expire after turns
	if has_status("strength_up"):
		_statuses["strength_up"] -= 1
		if _statuses["strength_up"] <= 0:
			to_remove.append("strength_up")
			_notify(entity, "STRENGTH UP FADED", STATUS_COLORS["strength_up"])

	for s in to_remove:
		_statuses.erase(s)

	_refresh_badges(entity)

## Returns the damage multiplier this entity deals (1.0 normally, 0.75 if weakened).
func get_outgoing_multiplier() -> float:
	if has_status("weakness"):
		return 0.75
	return 1.0

# ─── Internal ─────────────────────────────────────────────────────────────────

func _notify(entity: Node, text: String, color: Color) -> void:
	var battle_scene = entity.get_tree().current_scene if entity.get_tree() else null
	if battle_scene and battle_scene.has_method("show_notification"):
		battle_scene.show_notification(text, color)

func _refresh_badges(entity: Node) -> void:
	# Look for a StatusBadgeContainer child node to display icons
	# If none exists, we skip silently — badges are optional UI
	var container = entity.get_node_or_null("StatusBadges")
	if not container: return

	for child in container.get_children():
		child.queue_free()

	for status_name in _statuses:
		var stacks = _statuses[status_name]
		if stacks <= 0: continue
		var lbl = Label.new()
		lbl.text = "%s%d" % [STATUS_LABELS.get(status_name, status_name), stacks]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", STATUS_COLORS.get(status_name, Color.WHITE))
		container.add_child(lbl)
