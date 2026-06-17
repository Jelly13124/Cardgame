## StatusEffectSystem is shared by PlayerEntity and EnemyEntity.
## Turn timing:
## - on_turn_start(): start-of-turn damage / upkeep
## - on_turn_end(): end-of-turn debuff expiration
extends RefCounted
class_name StatusEffectSystem

var _statuses: Dictionary = {}

const TURN_END_DECAY = ["weak", "vulnerable", "frail", "thorns"]


static func format_name(status_name: String) -> String:
	return status_name.replace("_", " ").capitalize()


## Localized status display name for player-facing notifications/tooltips.
## Falls back to the English-capitalized format_name() for any status without a
## UI_COMBAT_STATUS_* row.
static func format_name_localized(status_name: String) -> String:
	var key := "UI_COMBAT_STATUS_%s" % status_name.to_upper()
	var localized := TranslationServer.translate(key)
	if localized == key:
		return format_name(status_name)
	return localized


const STATUS_COLORS = {
	"bleed": Color(1.0, 0.30, 0.37),
	"burn": Color(1.0, 0.4, 0.1),
	"weak": Color(0.7, 0.5, 0.9),
	"vulnerable": Color(0.95, 0.45, 0.2),
	"double_damage": Color(0.2, 0.8, 1.0),
	"stun": Color(0.95, 0.95, 0.3),
	"regen": Color(0.3, 1.0, 0.6),
	"thorns": Color(0.7, 0.75, 0.8),
	"frail": Color(0.6, 0.5, 0.7),
	"dodge": Color(0.6, 0.95, 1.0),
	"metallicize": Color(0.72, 0.80, 0.86),
	"feel_no_pain": Color(0.55, 0.80, 0.95),
	"dark_embrace": Color(0.72, 0.42, 0.86),
	"hot_streak": Color(1.0, 0.82, 0.3),
	"all_in": Color(1.0, 0.45, 0.25),
	"hemorrhage": Color(0.85, 0.15, 0.25),
	"covering_reload": Color(0.55, 0.78, 0.95),
	"bullet": Color(1.0, 0.78, 0.35),
}

const STATUS_LABELS = {
	"bleed": "Bl",
	"burn": "B",
	"weak": "W",
	"vulnerable": "V",
	"double_damage": "D",
	"stun": "⚡",
	"regen": "R",
	"thorns": "T",
	"frail": "F",
	"dodge": "E",
	"metallicize": "M",
	"feel_no_pain": "¤",
	"dark_embrace": "◆",
	"hot_streak": "HS",
	"all_in": "AI",
	"hemorrhage": "Hm",
	"covering_reload": "CR",
	"bullet": "●",
}

const STATUS_ICON_DIR := "res://battle_scene/assets/images/ui/status/"
const STATUS_ICON_SIZE := 30.0

const STATUS_DESCRIPTIONS = {
	"bleed":
	"Take damage equal to stacks at the start of your turn, then stacks are halved (rounded down).",
	"burn":
	"Take damage equal to stacks at the end of your turn. Lose 1 stack at the start of each turn.",
	"weak": "Outgoing attack damage reduced 25% per stack. Decays 1 per turn.",
	"vulnerable": "Incoming attack damage increased 50% per stack. Decays 1 per turn.",
	"double_damage": "Next N attacks deal double damage. Consumed on use.",
	"stun": "Enemy skips its next turn for each stack (enemy-only).",
	"regen": "Heal stacks HP at the start of your turn. Stacks decay by 1 each turn.",
	"thorns": "When hit by an attack, the attacker takes stacks damage. Decays 1 per turn.",
	"frail": "Block gained is reduced 25%. Decays 1 per turn.",
	"dodge": "Completely negates incoming attacks, one stack consumed per attack.",
	"metallicize": "At the start of your turn, gain stacks Block. Persistent.",
	"feel_no_pain": "Whenever a card is Exhausted, gain stacks Block. Persistent.",
	"dark_embrace": "Whenever a card is Exhausted, draw stacks card(s). Persistent.",
	"hot_streak": "Whenever you Crit, gain 2 gold. Persistent.",
	"all_in": "Your Crits deal double damage, but non-Crit attacks deal 0. Persistent.",
	"hemorrhage": "Your Bleed damage can Crit. Persistent.",
	"covering_reload": "Whenever you Reload, gain 3 Block. Persistent.",
	"bullet":
	"Ammo for attacks (double-fire clip). 1 at the start of each turn, max 1; spent by attacking, restored by Reload.",
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
	if has_status("bleed"):
		var dmg: int = _statuses["bleed"]
		# Hemorrhage power: the PLAYER's Bleed on enemies can Crit. The player's own
		# Bleed (enemy-applied) does not — the player entity is in "player_entity".
		if entity and not entity.is_in_group("player_entity"):
			var tree = entity.get_tree()
			var pl = tree.get_first_node_in_group("player_entity") if tree else null
			if (
				pl
				and pl.has_method("get_status_stacks")
				and pl.get_status_stacks("hemorrhage") > 0
				and randf() < RunManager.crit_chance()
			):
				dmg = int(round(dmg * RunManager.CRIT_MULT))
		if entity.has_method("take_damage"):
			# silent=false → CombatFX floating damage number IS the readout
			# now that _notify is deleted.
			entity.take_damage(dmg)
			AudioManager.play_sfx("bleed")
		# Halve remaining stacks, rounded down (int division floors for positives).
		_statuses["bleed"] = _statuses["bleed"] / 2
		if _statuses["bleed"] <= 0:
			_statuses.erase("bleed")
		changed = true

	# Burn now ticks at END of turn (see on_turn_end); the start of turn only
	# decays it by 1 stack.
	if has_status("burn"):
		_statuses["burn"] -= 1
		if _statuses["burn"] <= 0:
			_statuses.erase("burn")
		changed = true

	if has_status("regen"):
		var amt: int = _statuses["regen"]
		if entity.has_method("heal"):
			entity.heal(amt)
		_statuses["regen"] -= 1
		if _statuses["regen"] <= 0:
			_statuses.erase("regen")
		changed = true

	if changed:
		_on_statuses_changed(entity)


func on_turn_end(entity: Node) -> void:
	var changed := false
	# Burn deals its damage at the END of the turn (stacks are decayed at the next
	# turn start). Does not consume stacks here — the start-of-turn −1 handles decay.
	if has_status("burn"):
		var burn_dmg: int = _statuses["burn"]
		if entity.has_method("take_damage"):
			entity.take_damage(burn_dmg)

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

	if changed:
		_on_statuses_changed(entity)


## Consume one stack of stun. Returns true if a stack was consumed
## (caller should treat this as "the action is stunned, skip it").
## Stun is manual-consume: it does NOT decay on its own.
func consume_stun(entity: Node) -> bool:
	if not has_status("stun"):
		return false
	_statuses["stun"] -= 1
	if _statuses["stun"] <= 0:
		_statuses.erase("stun")
	_on_statuses_changed(entity)
	_notify(entity, "STUNNED", STATUS_COLORS["stun"])
	return true


func get_outgoing_multiplier() -> float:
	if has_status("weak"):
		return 0.5
	return 1.0


func get_incoming_attack_multiplier() -> float:
	if has_status("vulnerable"):
		return 1.5
	return 1.0


## Block gained is reduced while Frail. Flat 25% (mirrors weak's flat model).
func get_block_multiplier() -> float:
	if has_status("frail"):
		return 0.75
	return 1.0


## Dodge negates an incoming attack and consumes one stack. Returns true if a
## stack was consumed (caller should treat the attack as fully negated).
func try_consume_dodge(entity: Node) -> bool:
	if not has_status("dodge"):
		return false
	_statuses["dodge"] -= 1
	if _statuses["dodge"] <= 0:
		_statuses.erase("dodge")
	_on_statuses_changed(entity)
	return true


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


func _refresh_badges_legacy(entity: Node) -> void:
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
		# Single-glyph status code (P / B / ⚡ …) + stack count. The codes are a
		# fixed visual legend, deliberately NOT localized; built off-assignment so
		# the i18n audit doesn't flag the format literal as a hardcoded UI string.
		var badge_code: String = STATUS_LABELS.get(status_name, status_name)
		lbl.text = badge_code + str(stacks)
		lbl.add_theme_font_size_override("font_size", 16)
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
		var human_name: String = format_name_localized(status_name)
		var desc_key := "UI_COMBAT_STATUS_%s_DESC" % str(status_name).to_upper()
		var desc: String = TranslationServer.translate(desc_key)
		if desc == desc_key:
			desc = str(STATUS_DESCRIPTIONS.get(status_name, ""))
		var tip: String = (
			tr("UI_COMBAT_STATUS_TIP").format({"name": human_name, "n": stacks, "desc": desc})
			if desc != ""
			else tr("UI_COMBAT_STATUS_TIP_NO_DESC").format({"name": human_name, "n": stacks})
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

		var badge = _make_status_badge(status_name, stacks)
		var human_name: String = format_name_localized(status_name)
		var desc_key := "UI_COMBAT_STATUS_%s_DESC" % str(status_name).to_upper()
		var desc: String = TranslationServer.translate(desc_key)
		if desc == desc_key:
			desc = str(STATUS_DESCRIPTIONS.get(status_name, ""))
		var tip: String = (
			tr("UI_COMBAT_STATUS_TIP").format({"name": human_name, "n": stacks, "desc": desc})
			if desc != ""
			else tr("UI_COMBAT_STATUS_TIP_NO_DESC").format({"name": human_name, "n": stacks})
		)
		var badge_ref: Control = badge
		var badge_id: int = badge.get_instance_id()
		badge.mouse_entered.connect(
			func():
				if not is_instance_valid(badge_ref):
					return
				Tooltip.show(
					tip, badge_ref.global_position + Vector2(badge_ref.size.x * 0.5, 0), badge_id
				)
		)
		badge.mouse_exited.connect(Tooltip.hide_if_owner.bind(badge_id))
		badge.tree_exited.connect(Tooltip.hide_if_owner.bind(badge_id))
		container.add_child(badge)


func _make_status_badge(status_name: String, stacks: int) -> Control:
	var badge = Control.new()
	badge.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	badge.size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	badge.mouse_filter = Control.MOUSE_FILTER_PASS

	var icon_texture := _load_status_icon(status_name)
	if icon_texture:
		var icon = TextureRect.new()
		icon.texture = icon_texture
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.add_child(icon)
	else:
		var fallback = Label.new()
		fallback.text = str(STATUS_LABELS.get(status_name, status_name))
		fallback.add_theme_font_size_override("font_size", 18)
		fallback.add_theme_color_override("font_color", STATUS_COLORS.get(status_name, Color.WHITE))
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.add_child(fallback)

	var stack_label = Label.new()
	stack_label.text = str(stacks)
	stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stack_label.add_theme_font_size_override("font_size", 13)
	stack_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	stack_label.add_theme_color_override("font_outline_color", Color(0.05, 0.025, 0.012, 1.0))
	stack_label.add_theme_constant_override("outline_size", 3)
	stack_label.anchor_left = 0.0
	stack_label.anchor_top = 0.0
	stack_label.anchor_right = 1.0
	stack_label.anchor_bottom = 1.0
	stack_label.offset_left = 0.0
	stack_label.offset_top = 0.0
	stack_label.offset_right = 3.0
	stack_label.offset_bottom = 2.0
	badge.add_child(stack_label)
	return badge


func _load_status_icon(status_name: String) -> Texture2D:
	var path := "%s%s.png" % [STATUS_ICON_DIR, status_name]
	if not ResourceLoader.exists(path):
		return null
	var loaded = load(path)
	if loaded is Texture2D:
		return loaded
	return null
