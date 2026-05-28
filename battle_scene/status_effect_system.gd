## StatusEffectSystem is shared by PlayerEntity and EnemyEntity.
## Turn timing:
## - on_turn_start(): start-of-turn damage / upkeep
## - on_turn_end(): end-of-turn debuff expiration
extends RefCounted
class_name StatusEffectSystem

var _statuses: Dictionary = {}

const TURN_END_DECAY = ["weak", "vulnerable", "strength_up"]


static func format_name(status_name: String) -> String:
	return status_name.replace("_", " ").capitalize()


const STATUS_COLORS = {
	"poison": Color(0.4, 0.9, 0.2),
	"burn": Color(1.0, 0.4, 0.1),
	"weak": Color(0.7, 0.5, 0.9),
	"vulnerable": Color(0.95, 0.45, 0.2),
	"strength_up": Color(1.0, 0.5, 0.2),
	"double_damage": Color(0.2, 0.8, 1.0),
	"shock": Color(0.95, 0.95, 0.3),
}

const STATUS_LABELS = {
	"poison": "P",
	"burn": "B",
	"weak": "W",
	"vulnerable": "V",
	"strength_up": "S",
	"double_damage": "D",
	"shock": "⚡",
}

const STATUS_DESCRIPTIONS = {
	"poison": "Take 1 damage per stack at the start of your turn. Stacks decay by 1 each turn.",
	"burn": "Take damage equal to stacks at the start of your turn. All stacks consumed.",
	"weak": "Outgoing attack damage reduced 25% per stack. Decays 1 per turn.",
	"vulnerable": "Incoming attack damage increased 50% per stack. Decays 1 per turn.",
	"strength_up": "Outgoing attack damage increased by stack count. Persistent.",
	"double_damage": "Next N attacks deal double damage. Consumed on use.",
	"shock": "Enemy skips its next turn for each stack (enemy-only).",
}


func add_status(status_name: String, stacks: int, entity: Node) -> void:
	if stacks <= 0:
		return
	status_name = _canonicalize_status_name(status_name)
	_statuses[status_name] = _statuses.get(status_name, 0) + stacks
	_on_statuses_changed(entity)


func remove_status(status_name: String, entity: Node) -> void:
	status_name = _canonicalize_status_name(status_name)
	if not _statuses.has(status_name):
		return
	_statuses.erase(status_name)
	_on_statuses_changed(entity)


func get_stacks(status_name: String) -> int:
	status_name = _canonicalize_status_name(status_name)
	return _statuses.get(status_name, 0)


func has_status(status_name: String) -> bool:
	status_name = _canonicalize_status_name(status_name)
	return _statuses.get(status_name, 0) > 0


func on_turn_start(entity: Node) -> void:
	var changed := false
	if has_status("poison"):
		var dmg: int = _statuses["poison"]
		if entity.has_method("take_damage"):
			# silent=false → CombatFX floating damage number IS the readout
			# now that _notify is deleted.
			entity.take_damage(dmg)
		_statuses["poison"] -= 1
		if _statuses["poison"] <= 0:
			_statuses.erase("poison")
		changed = true

	if has_status("burn"):
		var dmg: int = _statuses["burn"]
		if entity.has_method("take_damage"):
			entity.take_damage(dmg)

	if changed:
		_on_statuses_changed(entity)


func on_turn_end(entity: Node) -> void:
	var changed := false
	for status_name in TURN_END_DECAY:
		if not has_status(status_name):
			continue

		_statuses[status_name] -= 1
		changed = true
		if _statuses[status_name] > 0:
			continue

		_statuses.erase(status_name)
		match status_name:
			"weak":
				_notify(entity, "WEAK FADED", STATUS_COLORS["weak"])
			"vulnerable":
				_notify(entity, "VULNERABLE FADED", STATUS_COLORS["vulnerable"])
			"strength_up":
				_notify(entity, "STRENGTH UP FADED", STATUS_COLORS["strength_up"])

	if changed:
		_on_statuses_changed(entity)


## Consume one stack of shock. Returns true if a stack was consumed
## (caller should treat this as "the action is shocked, skip it").
## Shock is manual-consume: it does NOT decay on its own.
func consume_shock(entity: Node) -> bool:
	if not has_status("shock"):
		return false
	_statuses["shock"] -= 1
	if _statuses["shock"] <= 0:
		_statuses.erase("shock")
	_on_statuses_changed(entity)
	_notify(entity, "SHOCKED", STATUS_COLORS["shock"])
	return true


func get_outgoing_multiplier() -> float:
	if has_status("weak"):
		return 0.5
	return 1.0


func get_incoming_attack_multiplier() -> float:
	if has_status("vulnerable"):
		return 1.5
	return 1.0


func _canonicalize_status_name(status_name: String) -> String:
	return status_name.to_lower()


## Center-screen yellow status text removed per UX feedback — visual
## feedback for DoT now lives in CombatFX floating damage numbers (see
## on_turn_start passing silent=false to take_damage). Kept as a no-op
## so existing call sites don't error.
func _notify(_entity: Node, _text: String, _color: Color) -> void:
	pass


func _on_statuses_changed(entity: Node) -> void:
	_refresh_badges(entity)
	if entity.has_method("notify_status_changed"):
		entity.notify_status_changed()
	elif entity.has_signal("status_changed"):
		entity.status_changed.emit()


const STATUS_BADGE_BG = preload("res://battle_scene/assets/images/ui/status_badge_bg.png")


func _refresh_badges(entity: Node) -> void:
	var container = entity.find_child("StatusBadges", true, false)
	if not container:
		return

	for child in container.get_children():
		child.queue_free()

	for status_name in _statuses:
		var stacks = _statuses[status_name]
		if stacks <= 0:
			continue
		# Each badge is a 24x24 NinePatch (status_badge_bg.png) with the status
		# letter + stack count Label centered inside it.
		var bg = NinePatchRect.new()
		bg.texture = STATUS_BADGE_BG
		bg.custom_minimum_size = Vector2(24, 24)
		bg.patch_margin_left = 6
		bg.patch_margin_top = 6
		bg.patch_margin_right = 6
		bg.patch_margin_bottom = 6
		bg.mouse_filter = Control.MOUSE_FILTER_PASS
		var lbl = Label.new()
		lbl.text = "%s%d" % [STATUS_LABELS.get(status_name, status_name), stacks]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", STATUS_COLORS.get(status_name, Color.WHITE))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(lbl)
		# Tooltip on hover: full status name + description + current stack count.
		# Guard against the lambda firing after the badge is queue_freed
		# (next _refresh_badges call frees everything; if the cursor is still
		# over an old badge in the deferred-free window, mouse_entered can
		# fire on a dead Object). Also fire hide on tree_exited so the
		# tooltip can't get stuck when the badge is freed mid-hover.
		var human_name: String = str(status_name).replace("_", " ").capitalize()
		var desc: String = str(STATUS_DESCRIPTIONS.get(status_name, ""))
		var tip: String = (
			"[b]%s ×%d[/b]\n%s" % [human_name, stacks, desc]
			if desc != ""
			else "[b]%s ×%d[/b]" % [human_name, stacks]
		)
		var bg_ref: NinePatchRect = bg
		var bg_id: int = bg.get_instance_id()
		bg.mouse_entered.connect(
			func():
				if not is_instance_valid(bg_ref):
					return
				Tooltip.show(tip, bg_ref.global_position + Vector2(bg_ref.size.x * 0.5, 0), bg_id)
		)
		# hide_if_owner so a stale fire (e.g. tree_exited after a sibling
		# already opened a new tooltip) can't clobber the new overlay.
		bg.mouse_exited.connect(Tooltip.hide_if_owner.bind(bg_id))
		bg.tree_exited.connect(Tooltip.hide_if_owner.bind(bg_id))
		container.add_child(bg)
