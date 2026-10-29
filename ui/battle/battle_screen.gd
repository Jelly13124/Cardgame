extends Node

# --- Node References ---
@onready var card_manager = $CardManager
@onready var card_factory = $CardManager/MyCardFactory
@onready var hand = $CardManager/Hand
@onready var deck = $CardManager/Deck
@onready var discard_pile = $CardManager/DiscardPile
@onready var player = $Player
@onready var enemy_container = $EnemyContainer

const PAUSE_PANEL = preload("uid://dggg8eoy0notq")  # res://run_system/ui/pause_panel.gd
@onready var ui_manager = $BattleUIManager
@onready var end_round_button = $EndRoundButton

## The combat this screen shows (core/combat/combat_manager.gd): all rules and
## state. This scene is its room (STS2 NCombatRoom): views, input, targeting,
## HUD and what happens after the fight.
var combat: RefCounted = null
var presenter: RefCounted = null  # ui/battle/battle_presenter.gd
var hand_view: Node  # ui/battle/hand_view.gd
## Enemy creature -> its view (EnemyEntity).
var _views: Dictionary = {}

var combat_hooks: RefCounted:
	get:
		return combat.combat_hooks if combat else null
var combat_commands: RefCounted:
	get:
		return combat.combat_commands if combat else null
# Typed via the preloaded CARD_ANIMATOR_SCRIPT below — kept as Node so this
# file parses even before Godot has scanned the class_name registry.
var card_animator: Node  # CardAnimator (card_animator.gd) instance

# --- Game State ---
var is_game_over: bool:
	get:
		return combat != null and combat.is_game_over
var is_targeting: bool = false
var targeting_card: Control = null
var targeting_arrow: Node2D = null
var hovered_unit: Node = null
var _dmg_preview: Label = null
var _polarity_badge: Label = null  # H5: lazily-created HUD badge for yin/yang hero polarity
var _tool_confirm: Control = null
var _tool_resolving := false
var _pending_tool_index := -1
var _pending_tool_id := ""
var _pending_tool_data: Dictionary = {}

const TARGETING_ARROW_SCRIPT = preload("uid://dq6nkaqdhlsp4")  # res://ui/battle/targeting_arrow.gd
const COMBAT_FX = preload("uid://dx2h4lk8uoasg")  # res://ui/battle/combat_fx.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const COMBAT_MANAGER = preload("uid://dumevejih8ygv")  # res://core/combat/combat_manager.gd
const BATTLE_PRESENTER = preload("uid://du6lk20qqijeu")  # res://ui/battle/battle_presenter.gd
const HAND_VIEW = preload("uid://dselhm1i0ycf")  # res://ui/battle/hand_view.gd
const ENEMY_ENTITY = preload("uid://qtp7jvjqfbou")  # res://ui/battle/enemy_view.gd
const CARD_ANIMATOR_SCRIPT = preload("uid://co0n3ou8saknv")  # res://ui/battle/card_animator.gd
const DISCOVER_MODAL = preload("uid://keeeggdto42o")  # res://ui/battle/discover_modal.gd
const TOOL_USE_CONFIRM = preload("uid://dihe3sjaxh16")  # res://ui/battle/tool_use_confirm.gd
const T = preload("uid://dfcqloc58bvde")  # res://run_system/ui/theme/wasteland_theme.gd
# NOTE: map_scene + home_base_scene are loaded lazily at the call site
# (not preloaded) because doing so would create a cyclic dep
# (map → battle → map) and the editor's static analysis chokes.
const HOME_BASE_PATH := "uid://c6bvuu6kbx0pq"  # res://ui/base/home_base_scene.tscn
const MAP_SCENE_PATH := "uid://d3x5b8wvg2q"  # res://ui/map/map_scene.tscn
const LOOT_REWARD_SCENE = preload("uid://csl8exl41do23")  # res://ui/rewards/loot_reward.tscn
const EXTRACT_CHOICE_MODAL_SCRIPT = preload("uid://dl8ofvd880xht")  # res://ui/rewards/extract_choice_modal.gd
const RESULT_SCREEN_SCRIPT = preload("uid://bxh1x1hy6fylv")  # res://ui/rewards/result_screen.gd
const TUTORIAL_TIPS_SCRIPT = preload("uid://cc37k40gsd5x")  # res://ui/battle/tutorial_tips.gd
const MAIN_MENU_PATH := "uid://dnjlmt1repvjw"  # res://run_system/ui/main_menu.tscn

const COMBAT_REWARDS = preload("uid://sn83hwnx1w3b")  # res://core/run/combat_rewards.gd


func _exit_tree() -> void:
	# Restore normal speed when leaving combat so the map / menus run at 1x
	# regardless of the battle-speed setting (Engine.time_scale is global).
	Engine.time_scale = 1.0


func _ready():
	print("BATTLE STARTING (STS Layout)")
	AudioManager.play_music("boss" if RunManager.last_battle_node_type == "boss" else "battle")
	card_manager.debug_mode = false
	Engine.time_scale = Settings.game_speed

	# The hand view keeps card nodes in step with the combat piles.
	hand_view = HAND_VIEW.new()
	hand_view.screen = self
	hand_view.deck = deck
	hand_view.discard_pile = discard_pile
	hand_view.hand = hand
	hand_view.card_factory = card_factory
	add_child(hand_view)

	# Instantiate CardAnimator — owns play / discard / exhaust tweens
	card_animator = CARD_ANIMATOR_SCRIPT.new()
	card_animator.setup(self)
	add_child(card_animator)

	# Apply textured wasteland button skin to the End Round button.
	if end_round_button:
		T.apply_button_theme(end_round_button)
		_style_end_round_button()

	# The shared deck-book glyph replaces the old card-fan/card-back art on both
	# piles. Mirroring gives the draw and discard sides opposite directions while
	# keeping one visual language with the top-bar deck icon.
	_setup_pile_icon(deck, "iconb_deck_stack", true)
	_setup_pile_icon(discard_pile, "iconb_deck_stack", false)

	_start_new_game()

	set_process(true)

	# First-battle tutorial tips — shown once ever, gated on MetaProgress.
	_maybe_show_tutorial()


## Compact comic placard. One generated plate supplies every interaction state;
## Godot keeps the localized label and applies only a restrained value shift.
func _style_end_round_button() -> void:
	var plate_tex := T.lightline_tex("hud_end_turn_orange")
	if plate_tex == null:
		return
	for state in ["normal", "hover", "pressed", "disabled"]:
		# Scale the compact plate as a whole. It is already authored at the same
		# aspect family as the runtime button, so a 9-slice would over-extend its
		# clipped ends into decorative horizontal rails.
		var tb := StyleBoxTexture.new()
		tb.texture = plate_tex
		match state:
			"hover":
				tb.modulate_color = Color(1.08, 1.08, 1.08)
			"pressed":
				tb.modulate_color = Color(0.88, 0.88, 0.88)
			"disabled":
				tb.modulate_color = Color(0.58, 0.58, 0.58)
		tb.content_margin_left = 28
		tb.content_margin_right = 28
		tb.content_margin_top = 8
		tb.content_margin_bottom = 8
		end_round_button.add_theme_stylebox_override(state, tb)
	var cream := Color(0.96, 0.90, 0.74, 1.0)
	end_round_button.add_theme_color_override("font_color", cream)
	end_round_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82, 1.0))
	end_round_button.add_theme_color_override("font_pressed_color", cream)
	end_round_button.add_theme_color_override("font_disabled_color", Color(0.62, 0.59, 0.52, 0.9))
	end_round_button.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.025, 0.95))
	end_round_button.add_theme_constant_override("outline_size", 3)


## Show the first-battle tip sequence until the player actually finishes it.
## Closing the game mid-tutorial no longer burns the one-time onboarding flag.
func _maybe_show_tutorial() -> void:
	if MetaProgress.tutorial_seen:
		return
	var canvas := CanvasLayer.new()
	canvas.layer = 240
	add_child(canvas)
	var tips: Control = TUTORIAL_TIPS_SCRIPT.new()
	tips.completed.connect(
		func() -> void:
			MetaProgress.mark_tutorial_seen()
			if is_instance_valid(canvas):
				canvas.queue_free()
	)
	canvas.add_child(tips)


# ─── Input ────────────────────────────────────────────────────────────────────


## _input fires before any Control node. It owns target confirm/cancel input;
## unrelated keyboard events still pass through to BattleUIManager.
func _input(event: InputEvent) -> void:
	# ESC → unified pause panel (settings / how-to / abandon / quit). Suppressed while
	# targeting so ESC there stays free to cancel the targeting arrow.
	if (
		event.is_action_pressed("ui_cancel")
		and not is_targeting
		and not get_node_or_null("PauseLayer")
	):
		PAUSE_PANEL.open(self, RunManager.is_run_active)
		get_viewport().set_input_as_handled()
		return

	# Debug-only: right-click any enemy (outside targeting) → instant-kill. A
	# lethal hit through the combat, so its death and the victory follow the
	# normal rules. Guarded on OS.is_debug_build() so it's stripped from exported
	# builds.
	if (
		OS.is_debug_build()
		and not is_targeting
		and event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_RIGHT
	):
		var mouse_pos = get_viewport().get_mouse_position()
		var enemy = _get_unit_at_position(mouse_pos)
		if enemy and is_instance_valid(enemy) and combat.combat_commands.is_alive(enemy.creature):
			show_notification("DEBUG: killed %s" % enemy.name, Color(1, 0.4, 1))
			combat.debug_kill(enemy.creature)
			get_viewport().set_input_as_handled()
			return

	if not is_targeting:
		return
	# Escape and right-click both cancel the active card/tool targeting gesture.
	# Keeping this at the battle root prevents a pending tool from surviving after
	# its confirmation overlay has already closed.
	if event.is_action_pressed("ui_cancel"):
		_cancel_active_targeting()
		get_viewport().set_input_as_handled()
		return
	# Other keyboard input remains available to BattleUIManager.
	if not (event is InputEventMouseButton):
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_active_targeting()
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_tool_targeting():
			_confirm_tool_targeting(_get_unit_at_position(get_viewport().get_mouse_position()))
		elif targeting_card and is_instance_valid(targeting_card):
			confirm_spell_targeting(targeting_card)
		else:
			_cancel_active_targeting()
		get_viewport().set_input_as_handled()


# ─── Process ──────────────────────────────────────────────────────────────────


func _process(_delta: float) -> void:
	if not is_targeting:
		if hovered_unit:
			_set_hover_effect(hovered_unit, false)
			hovered_unit = null
		_hide_damage_preview()
		return

	# A target that died while hovered is dropped before anything touches it.
	if hovered_unit != null and (
		not is_instance_valid(hovered_unit) or hovered_unit.is_queued_for_deletion()
	):
		hovered_unit = null
	var mouse_pos = get_viewport().get_mouse_position()
	var unit_under_mouse = _get_unit_at_position(mouse_pos)

	if unit_under_mouse != hovered_unit:
		if hovered_unit:
			_set_hover_effect(hovered_unit, false)
		hovered_unit = unit_under_mouse
		if hovered_unit:
			_set_hover_effect(hovered_unit, true)

	if targeting_arrow and targeting_arrow.has_method("set_target_valid"):
		targeting_arrow.set_target_valid(hovered_unit != null)

	# Damage preview: show the number this attack would actually deal. Prefer the
	# hovered enemy; if exactly one enemy is on the field, show it for that enemy
	# even before the player hovers it.
	var preview_target: Node = hovered_unit
	if preview_target == null:
		preview_target = _sole_alive_enemy()
	if preview_target and is_instance_valid(preview_target):
		var dmg := preview_card_damage(targeting_card, preview_target)
		if dmg >= 0:
			_show_damage_preview(preview_target, dmg)
		else:
			_hide_damage_preview()
	else:
		_hide_damage_preview()


## Damage `card` would deal to `target` in one resolution pass, computed by the
## shared pipeline in preview mode (no state changes). -1 if not a damage card.
func preview_card_damage(card: Control, target: Node) -> int:
	if combat == null or not is_instance_valid(card) or not is_instance_valid(target):
		return -1
	return combat.preview_card_damage(card.instance if card.get("instance") else card, target.creature)


func _show_damage_preview(target: Node, dmg: int) -> void:
	if not _dmg_preview:
		_dmg_preview = Label.new()
		_dmg_preview.add_theme_font_size_override("font_size", 38)
		_dmg_preview.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
		_dmg_preview.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		_dmg_preview.add_theme_constant_override("shadow_offset_x", 2)
		_dmg_preview.add_theme_constant_override("shadow_offset_y", 2)
		_dmg_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dmg_preview.z_index = 200
		_dmg_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_dmg_preview)
	_dmg_preview.visible = true
	_dmg_preview.text = str(dmg)
	_dmg_preview.reset_size()
	_dmg_preview.global_position = (
		target.global_position + Vector2(-_dmg_preview.size.x * 0.5, -290)
	)


func _hide_damage_preview() -> void:
	if _dmg_preview:
		_dmg_preview.visible = false


## H5: Battle HUD badge for the Yin/Yang hero polarity. Called on turn-start /
## flip / harmony through the combat presenter,
## and once at battle start. Non-polarity heroes (current_polarity == "") show
## nothing. Owner fine-tunes the on-screen position visually.
func update_polarity_hud() -> void:
	if not is_instance_valid(player):
		return
	if not _polarity_badge:
		_polarity_badge = Label.new()
		_polarity_badge.add_theme_font_size_override("font_size", 28)
		_polarity_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		_polarity_badge.add_theme_constant_override("shadow_offset_x", 2)
		_polarity_badge.add_theme_constant_override("shadow_offset_y", 2)
		_polarity_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_polarity_badge.z_index = 200
		_polarity_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Top-left, near the player HP/energy HUD. Owner will fine-tune.
		_polarity_badge.position = Vector2(40, 40)
		add_child(_polarity_badge)

	var polarity: String = str(player.current_polarity)
	if polarity == "":
		_polarity_badge.visible = false
		return

	var harmony: bool = bool(player.harmony_active)
	if harmony:
		_polarity_badge.text = tr("UI_BATTLE_POLARITY_HARMONY")
		_polarity_badge.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	elif polarity == "yin":
		_polarity_badge.text = tr("UI_BATTLE_POLARITY_YIN")
		_polarity_badge.add_theme_color_override("font_color", Color(0.45, 0.7, 1.0))
	elif polarity == "yang":
		_polarity_badge.text = tr("UI_BATTLE_POLARITY_YANG")
		_polarity_badge.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
	else:
		_polarity_badge.visible = false
		return

	_polarity_badge.reset_size()
	_polarity_badge.visible = true


# ─── Helpers ──────────────────────────────────────────────────────────────────


## Target feedback while aiming (STS2): the hovered enemy shows its reticle;
## the enemy itself is never scaled or tinted.
func _set_hover_effect(unit: Node, active: bool) -> void:
	if not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return
	if active and unit.has_method("show_reticle"):
		unit.show_reticle()
	elif not active and unit.has_method("hide_reticle"):
		unit.hide_reticle()


## Returns the living enemy view under a screen position (viewport coords).
## EnemyEntity reports its rendered body rect so targeting matches current sprite scale.
func _get_unit_at_position(pos: Vector2) -> Node:
	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy) or not enemy.creature.is_alive():
			continue
		var ep = enemy.global_position
		var body_rect := Rect2(ep.x - 128, ep.y - 256, 256, 256)
		if enemy.has_method("get_targeting_rect"):
			var reported_rect: Variant = enemy.call("get_targeting_rect")
			if typeof(reported_rect) == TYPE_RECT2:
				body_rect = reported_rect
		if body_rect.has_point(pos):
			return enemy
		# Fallback: catch clicks near the HUD/center area
		if ep.distance_to(pos) < 164.0:
			return enemy
	return null


## Equipment-set trigger callout above the player (the set listener's feedback).
func show_set_callout(set_id: String, color: Color) -> void:
	if player == null or not is_instance_valid(player) or not player is Node2D:
		return
	var name_key := "SET_%s_NAME" % MODEL_ID.key_entry(set_id).to_upper()
	var set_name := tr(name_key)
	if set_name == name_key:
		set_name = MODEL_ID.entry_of(set_id).replace("_", " ").capitalize()
	var message := tr("UI_EQUIP_SET_TRIGGER").format({"set": set_name})
	COMBAT_FX.spawn_feedback_text(self, (player as Node2D).global_position + Vector2(0, -138), message, color)
	AudioManager.play_sfx("reward", -8.0, 1.08, 0.02)


func show_notification(text: String, color: Color = Color.WHITE):
	ui_manager.show_notification(text, color)


## Open a compact confirmation before resolving a top-bar tool. Enemy-targeted
## tools enter the same arrow + click-target interaction as attack cards only
## after confirmation; self/no-target tools still resolve immediately.
func use_tool(index: int) -> void:
	if is_instance_valid(_tool_confirm) or _tool_resolving or is_targeting or is_game_over:
		return
	if not _accepts_player_input():
		AudioManager.play_sfx("error")
		return
	if index < 0 or index >= RunManager.tool_inventory.size():
		return
	var tool_id := str(RunManager.tool_inventory[index])
	var tdata: Dictionary = RunManager.get_tool_data(tool_id)
	if tdata.is_empty():
		return
	if str(tdata.get("target", "none")) == "enemy" and _find_tool_target(tdata) == null:
		AudioManager.play_sfx("error")
		return
	var overlay := TOOL_USE_CONFIRM.new()
	overlay.setup(index, tool_id, tdata)
	overlay.confirmed.connect(_on_tool_use_confirmed)
	overlay.cancelled.connect(_on_tool_use_cancelled)
	overlay.tree_exited.connect(_on_tool_confirm_exited.bind(overlay))
	_tool_confirm = overlay
	add_child(overlay)


func _on_tool_use_confirmed(index: int, expected_tool_id: String) -> void:
	_tool_confirm = null
	if not _accepts_player_input():
		return
	if index < 0 or index >= RunManager.tool_inventory.size():
		return
	if str(RunManager.tool_inventory[index]) != expected_tool_id:
		return
	var tdata: Dictionary = RunManager.get_tool_data(expected_tool_id)
	if tdata.is_empty():
		return
	if str(tdata.get("target", "none")) == "enemy":
		if _find_tool_target(tdata) == null:
			AudioManager.play_sfx("error")
			return
		_begin_tool_targeting(index, expected_tool_id, tdata)
		return
	_enqueue_tool(index, tdata, null)


func _on_tool_use_cancelled() -> void:
	_tool_confirm = null


func _on_tool_confirm_exited(overlay: Control) -> void:
	if _tool_confirm == overlay:
		_tool_confirm = null


func _find_tool_target(tdata: Dictionary) -> Node:
	if str(tdata.get("target", "none")) != "enemy":
		return null
	for candidate in enemy_container.get_children():
		if _is_valid_tool_target(candidate):
			return candidate
	return null


func _is_valid_tool_target(candidate: Node) -> bool:
	return (
		is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and candidate.get("creature") != null
		and candidate.creature.is_alive()
		and not candidate.creature.is_player()
	)


func _is_tool_targeting() -> bool:
	return _pending_tool_index >= 0 and not _pending_tool_id.is_empty()


func _begin_tool_targeting(index: int, tool_id: String, tdata: Dictionary) -> void:
	if is_targeting or _tool_resolving or _is_tool_targeting():
		return
	_pending_tool_index = index
	_pending_tool_id = tool_id
	_pending_tool_data = tdata.duplicate(true)
	is_targeting = true
	targeting_card = null

	if not targeting_arrow:
		targeting_arrow = TARGETING_ARROW_SCRIPT.new()
		add_child(targeting_arrow)
	targeting_arrow.start(_tool_targeting_origin(index))


func _tool_targeting_origin(index: int) -> Vector2:
	var top_bar := get_node_or_null("TopBarLayer/TopBar")
	if top_bar:
		var shelf := top_bar.find_child("ToolShelf", true, false) as Control
		if shelf and shelf.get_child_count() > 0:
			# The shared HUD currently exposes one active slot. Clamp keeps this
			# correct if it later displays the whole inventory again.
			var slot_index := clampi(index, 0, shelf.get_child_count() - 1)
			var slot := shelf.get_child(slot_index) as Control
			if slot:
				return slot.get_global_rect().get_center()
	var viewport_size := get_viewport().get_visible_rect().size
	return Vector2(minf(260.0, viewport_size.x * 0.2), 80.0)


## Resolve the pending enemy tool against an explicit clicked target. An invalid
## click deliberately keeps targeting active so the player can try again or
## cancel; inventory is not touched until _resolve_tool completes.
func _confirm_tool_targeting(target: Node) -> void:
	if not is_targeting or not _is_tool_targeting() or _tool_resolving:
		return
	if not _accepts_player_input():
		_cancel_tool_targeting()
		return
	if not _is_valid_tool_target(target):
		show_notification(tr("UI_BATTLE_NO_TARGET"), Color(1, 0.6, 0.2))
		return

	var index := _pending_tool_index
	var expected_tool_id := _pending_tool_id
	var tdata := _pending_tool_data.duplicate(true)
	if (
		index < 0
		or index >= RunManager.tool_inventory.size()
		or str(RunManager.tool_inventory[index]) != expected_tool_id
	):
		_cancel_tool_targeting()
		AudioManager.play_sfx("error")
		return

	_cancel_tool_targeting()
	_enqueue_tool(index, tdata, target)


## Whether `card` can be played right now (drives the playable outline).
func can_play_card(card: Control) -> bool:
	if combat == null or card == null or not is_instance_valid(card) or not hand.has_card(card):
		return false
	return card.get("instance") != null and combat.can_play_card(card.instance)


## A play dropped when the combat ended: the card sinks, fades and is parked in
## the discard pile.
func park_dropped_card(card: Control) -> void:
	await card_animator.drop_card(card)
	if is_instance_valid(card):
		discard_pile.add_card(card)


## Cards and tools are used on the player's own turn only, and not after End
## Turn was pressed (the end-turn action is already queued).
func _accepts_player_input() -> bool:
	return combat != null and combat.accepts_player_input()


## Tool use joins the action queue behind any card still resolving; the
## inventory loses the tool only when it was used.
func _enqueue_tool(index: int, tdata: Dictionary, target: Node) -> void:
	_tool_resolving = true
	var int_mult: float = 1.0 + 0.08 * float(RunManager._attr("intelligence"))
	var effects: Array = []
	for eff in tdata.get("effects", []):
		if typeof(eff) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = (eff as Dictionary).duplicate(true)
		if e.has("amount"):
			e["amount"] = int(round(float(e["amount"]) * int_mult))
		effects.append(e)
	var needs_target := str(tdata.get("target", "none")) == "enemy"
	var target_creature = target.creature if needs_target and _is_valid_tool_target(target) else null
	combat.use_tool(
		str(tdata.get("id", "")), effects, target_creature, needs_target,
		func(used: bool) -> void:
			if used:
				RunManager.consume_tool(index)
			_tool_resolving = false
	)


func _cancel_tool_targeting() -> void:
	_clear_targeting_visuals()
	_pending_tool_index = -1
	_pending_tool_id = ""
	_pending_tool_data.clear()


func _cancel_active_targeting() -> void:
	if _is_tool_targeting():
		_cancel_tool_targeting()
	else:
		_cancel_spell_targeting()


# ─── Turn Events ──────────────────────────────────────────────────────────────


func _update_ui_labels():
	if player:
		ui_manager.update_labels(player.energy, player.max_energy)
		refresh_hand_ui()
	# Player status (vulnerable etc.) affects every enemy's intent display.
	_refresh_all_enemy_intents()


## Tells every alive enemy to recompute its intent badge. Cheap; called on
## any UI refresh so weak/vulnerable changes show immediately.
func _refresh_all_enemy_intents() -> void:
	if not enemy_container:
		return
	for enemy in enemy_container.get_children():
		if is_instance_valid(enemy) and enemy.has_method("update_intent_display"):
			enemy.update_intent_display()


func refresh_hand_ui():
	for card in hand.get_cards():
		# Cards resting in a pile are hidden (the pile glyph stands in for them);
		# anything that reaches the hand must be visible again.
		if card is CanvasItem:
			card.visible = true
		if card.has_method("update_display"):
			card.update_display()
	_refresh_pile_counts()


## One bare iconb glyph per pile (no frame, no card-back stack): the icon IS the
## pile's whole visual, with the count label on top of it. Uses the framework's
## own Pile.hide_cards switch, which re-applies on every stack update (a manual
## per-card hide gets overwritten by _update_target_positions).
func _setup_pile_icon(pile: Node, icon_name: String, mirrored: bool) -> void:
	if pile == null or pile.get_node_or_null("PileIcon") != null:
		return
	# The pile owns no visible card surface in battle. This is intentional: the
	# old CardBackVisual nodes were static scene art and hide_cards cannot control
	# them. Keep this true even if the replacement icon is unavailable.
	pile.hide_cards = true
	for legacy_name in ["CardBackVisual", "Placeholder"]:
		var legacy := pile.get_node_or_null(legacy_name)
		if legacy != null:
			legacy.queue_free()
	var tex := T.lightline_tex(icon_name)
	if tex == null:
		return
	var icon := TextureRect.new()
	icon.name = "PileIcon"
	icon.texture = tex
	icon.flip_h = mirrored
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# This is a pile glyph, not a rendered stack of full-size cards. Keep it
	# compact inside the existing 160x220 pile interaction area. Bias the draw
	# glyph toward the left edge and the discard glyph toward the right so the
	# fanned hand cannot cover either one.
	icon.offset_left = 10.0 if mirrored else 70.0
	icon.offset_top = -104.0
	icon.offset_right = icon.offset_left + 80.0
	icon.offset_bottom = -20.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 25
	pile.add_child(icon)


## Draw-pile / discard-pile card counts, drawn on each pile's glyph. Refreshed on
## every hand change so the numbers track draws / discards / reshuffles.
func _refresh_pile_counts() -> void:
	if is_instance_valid(deck):
		_set_pile_count(deck, deck.get_cards().size())
	if is_instance_valid(discard_pile):
		_set_pile_count(discard_pile, discard_pile.get_cards().size())
	_refresh_exhaust_indicator()


func _set_pile_count(pile: Node, n: int) -> void:
	var lbl: Label = pile.get_node_or_null("CountLabel")
	if lbl == null:
		lbl = Label.new()
		lbl.name = "CountLabel"
		# Attach the count to the compact glyph instead of leaving a large floating
		# numeral where the old full-size card stack used to be.
		var pile_icon := pile.get_node_or_null("PileIcon") as Control
		var icon_left := pile_icon.offset_left if pile_icon else 40.0
		var icon_right := pile_icon.offset_right if pile_icon else 120.0
		lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		lbl.offset_left = icon_left
		lbl.offset_top = -138.0
		lbl.offset_right = icon_right
		lbl.offset_bottom = -102.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 30
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
		lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		lbl.add_theme_constant_override("outline_size", 4)
		pile.add_child(lbl)
	lbl.text = str(n)


# ── Exhaust pile (hidden): exhausted cards collect here instead of vanishing.
# Open it with the X key or the on-screen indicator that appears once non-empty.


func view_exhaust_pile() -> void:
	ui_manager.show_pile_viewer_from_names(
		tr("UI_BATTLE_EXHAUST_PILE"), combat.state.exhausted_ids if combat else PackedStringArray(), "exhaust"
	)


func _refresh_exhaust_indicator() -> void:
	var n: int = combat.state.exhausted_ids.size() if combat else 0
	var btn: Button = get_node_or_null("ExhaustIndicator")
	if btn == null:
		btn = Button.new()
		btn.name = "ExhaustIndicator"
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.anchor_left = 1.0
		btn.anchor_right = 1.0
		btn.anchor_top = 1.0
		btn.anchor_bottom = 1.0
		btn.offset_left = -250.0
		btn.offset_top = -152.0
		btn.offset_right = -116.0
		btn.offset_bottom = -114.0
		btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(view_exhaust_pile)
		add_child(btn)
	btn.visible = n > 0
	btn.text = tr("UI_BATTLE_EXHAUST_SHORT").format({"n": n})


## Build the combat from RunManager state (or defaults if no run is active) and
## start it.
func _start_new_game():
	var pc = player.creature
	var deck_list: Array = []
	var encounter: Array = ["base:trash_robot"]
	if RunManager.is_run_active:
		pc.max_health = RunManager.max_health
		pc.health = RunManager.current_health
		var attrs = RunManager.player_attributes
		for attr in ["strength", "constitution", "intelligence", "luck", "charm"]:
			pc.set(attr, int(attrs.get(attr, 3)))
		deck_list = RunManager.player_deck.duplicate()
		if RunManager.current_encounter.size() > 0:
			encounter = RunManager.current_encounter
	else:
		deck_list = _practice_deck()
	player._refresh_hud()
	combat = COMBAT_MANAGER.new()
	presenter = BATTLE_PRESENTER.new(self)
	combat.presenter = presenter
	combat.setup({"player": pc, "deck": deck_list, "encounter": encounter})
	combat.combat_ended.connect(_on_combat_ended)
	combat.card_played.connect(_on_card_played)
	combat.enemy_died.connect(_on_enemy_died)
	for sig in ["health_changed", "energy_changed", "block_changed"]:
		pc.connect(sig, _update_ui_labels.unbind(1))
	pc.stats_changed.connect(_update_ui_labels)
	pc.status_changed.connect(_update_ui_labels)
	combat.prepare()
	hand_view.build(combat.state.piles)
	combat.begin()


## Practice deck for a battle opened without a run (editor, tests).
func _practice_deck() -> Array:
	var list = [
		"base:strike",
		"base:strike",
		"base:strike",
		"base:strike",
		"base:weak_strike",
		"base:defend",
		"base:defend",
		"base:defend",
		"base:defend",
		"base:siphon"
	]
	RunManager.rng("shuffle").shuffle(list)
	return list


## The view of `creature` (the player node or an enemy view), or null once freed.
func view_of(creature: Object) -> Node:
	if creature == null:
		return null
	if combat != null and creature == combat.player:
		return player
	var view = _views.get(creature)
	return view if view != null and is_instance_valid(view) and not view.is_queued_for_deletion() else null


## An enemy joined the fight: its view takes the next field slot.
func spawn_enemy_view(creature: Object) -> Node:
	var view = ENEMY_ENTITY.for_creature(creature)
	view.combat = combat
	var idx = enemy_container.get_child_count()
	view.position = Vector2(idx * 260, 0)
	enemy_container.add_child(view)
	_views[creature] = view
	return view


## Run bookkeeping for a committed play: bounty and card codex.
func _on_card_played(card: RefCounted) -> void:
	RunManager.card_played(card.card_info)
	MetaProgress.mark_card_seen(str(card.card_info.get("id", "")))


## Per-kill gold, scaled by toughness (elites pay double), and the bounty event.
func _on_enemy_died(enemy: RefCounted) -> void:
	var kill_gold := clampi(2 + enemy.max_health / 30, 1, 9)
	if enemy.is_elite:
		kill_gold *= 2
	RunManager.add_gold(kill_gold)
	RunManager.enemy_killed(enemy)


func _on_combat_ended(outcome: String) -> void:
	_tool_resolving = false  # a tool still queued was dropped with the fight
	if outcome == "victory":
		_victory()
	else:
		_game_over()


func _on_end_round_button_pressed():
	# Double-fire guard (auto-end + click, two fast clicks): the combat accepts
	# one End Turn per turn.
	if is_targeting:
		return
	combat.request_end_turn()
	refresh_hand_ui()  # nothing is playable once End Turn is pressed


func _victory():
	if is_targeting:
		_cancel_active_targeting()
	refresh_hand_ui()  # nothing is playable once combat is over
	AudioManager.play_sfx("victory")
	# Combat is over — neutralise any in-flight card drag NOW, before the 3s gap +
	# loot modal (MOUSE_FILTER_STOP) can swallow the mouse-release and leave a card
	# stuck in HOLDING, which permanently locks all future drags. (Bug fix.)
	_reset_hand_drag_state()
	# Victory path: persist HP without firing the death gate, even if the
	# player ended the fight at 0 HP (chip damage / mutual kill). Otherwise
	# modify_health(negative) would trigger _handle_run_loss → run_ended(false),
	# and the subsequent end_run_victory() at the boss branch would no-op.
	_write_hp_to_run_manager(false)
	# VICTORY! banner removed per UX feedback — the loot modal / extract
	# choice / home-base transition is sufficient signal that the fight is won.
	await get_tree().create_timer(3.0).timeout

	# The run layer grants the rewards and picks where the run goes next.
	var result: Dictionary = COMBAT_REWARDS.settle_victory(RunManager.last_battle_node_type, RunManager.current_act)
	if bool(result.get("backpack_full", false)):
		show_notification(tr("UI_LOOT_BACKPACK_FULL"), Color(1.0, 0.45, 0.4))
	match str(result["route"]):
		"extract_choice":
			_show_extract_choice(int(result["act"]), result["rewards"])
		"demo_complete":
			# The demo's final boss: the demo-complete / wishlist screen.
			_show_result_screen("demo_complete")
		_:
			_show_loot_modal()


## Cancel any in-flight hand-card drag at combat end and lock the hand so no new
## drag can start during the victory gap. The card-framework tracks a GLOBAL
## holding/hovering count (card.gd); if a card is left in HOLDING when the loot
## modal's MOUSE_FILTER_STOP eats the mouse-release, that count stays > 0 forever
## and `_can_start_hovering` blocks every future drag. Forcing each card to IDLE
## (state 0) runs its state-exit, which decrements the count back to zero.
func _reset_hand_drag_state() -> void:
	if not hand:
		return
	for card in hand.get_cards():
		if not is_instance_valid(card):
			continue
		card.change_state(0)  # DraggableState.IDLE — runs state-exit, drops the counter
		card.can_be_interacted_with = false


func _show_extract_choice(act: int, rewards: Dictionary) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 140
	add_child(canvas)
	var modal = EXTRACT_CHOICE_MODAL_SCRIPT.new()
	modal.act_num = act
	modal.reward_continue = int(rewards.get("continue", 0))
	modal.reward_extract = int(rewards.get("extract", 0))
	modal.chosen.connect(_on_extract_chosen.bind(rewards, canvas))
	canvas.add_child(modal)


func _on_extract_chosen(extract: bool, rewards: Dictionary, canvas: CanvasLayer) -> void:
	if is_instance_valid(canvas):
		canvas.queue_free()
	if COMBAT_REWARDS.choose_extract(extract, rewards) == "home":
		SceneTransition.change_to(HOME_BASE_PATH)
	else:
		# Pushed on into the next act: the normal loot, then its fresh map.
		_show_loot_modal()


func _show_loot_modal() -> void:
	# Render above inspect/pile views but below the persistent run top bar. The
	# modal still eats mouse events so cards in hand do not react to hover.
	var canvas := CanvasLayer.new()
	canvas.layer = 140
	add_child(canvas)
	var modal = LOOT_REWARD_SCENE.instantiate()
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.closed.connect(_on_loot_closed.bind(canvas))
	canvas.add_child(modal)


func _on_loot_closed(canvas: CanvasLayer) -> void:
	if is_instance_valid(canvas):
		canvas.queue_free()
	SceneTransition.change_to(MAP_SCENE_PATH)


func _game_over():
	if is_targeting:
		_cancel_active_targeting()
	refresh_hand_ui()  # nothing is playable once combat is over
	AudioManager.play_sfx("defeat")
	# Defeat path: route through the death gate so _handle_run_loss fires
	# and run_ended(false) is emitted.
	_write_hp_to_run_manager(true)
	# DEFEAT... banner removed per UX feedback — the player.health → 0 +
	# HUD bar drop reads as defeat; the result screen then offers Back to Menu.
	await get_tree().create_timer(3.0).timeout
	_show_result_screen("defeat")


## Show the end-of-run result screen ("defeat" | "demo_complete") over the battle
## on a high CanvasLayer. Its Back to Menu button routes to the title screen.
func _show_result_screen(result_mode: String) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 250
	add_child(canvas)
	var screen = RESULT_SCREEN_SCRIPT.new()
	screen.mode = result_mode
	canvas.add_child(screen)


## Writes player.health back to RunManager so it persists between battles.
##   triggering_defeat=true  → defeat path: route through modify_health so the
##                              death gate fires (_handle_run_loss → run_ended(false))
##   triggering_defeat=false → victory / inter-battle path: write + emit signal
##                              directly, NEVER fire the death gate even at 0 HP.
##                              Critical: victory paths must use this so a chip-
##                              kill mutual-death doesn't pre-empt end_run_victory.
func _write_hp_to_run_manager(triggering_defeat: bool = false) -> void:
	if not (RunManager.is_run_active and player and is_instance_valid(player)):
		return
	var target_hp: int = clampi(int(player.health), 0, RunManager.max_health)
	if triggering_defeat:
		var delta: int = target_hp - RunManager.current_health
		RunManager.modify_health(delta)
	else:
		# Direct write + manual emit — bypasses death gate by design.
		RunManager.current_health = target_hp
		RunManager.emit_signal("health_changed", target_hp, RunManager.max_health)


# ─── Energy ───────────────────────────────────────────────────────────────────


## Effective energy cost of a card node right now (a discovered card is free).
func card_cost(card) -> int:
	if card and is_instance_valid(card) and card.get("instance") != null:
		return card.instance.cost()
	return int(card.card_info.get("cost", 0)) if card else 0


func can_afford(cards: Array) -> bool:
	if is_game_over or combat == null:
		return false
	var total_cost = 0
	for card in cards:
		total_cost += card_cost(card)
	return combat.player.energy >= total_cost


## Discover modal: offer `ids`, return the pick (the combat adds the card).
func open_discover_modal(ids: Array, pool: String) -> String:
	var modal = DISCOVER_MODAL.new()
	modal.setup(ids, _discover_title(pool))
	add_child(modal)
	var picked: String = await modal.discovered
	return picked


## Localized Discover title for a pool (e.g. "Discover · Skill"); falls back to bare "Discover".
func _discover_title(pool: String) -> String:
	var key := "UI_DISCOVER_TITLE_%s" % pool.to_upper()
	var localized := tr(key)
	return localized if localized != key else tr("UI_DISCOVER_TITLE")


# ─── Card Play ────────────────────────────────────────────────────────────────


## Play a card node at an enemy view (or null). The combat checks and queues
## it; a refused card goes back to the hand (presenter).
func play_spell(card: Control, target_node: Node):
	if combat == null or not is_instance_valid(card) or card.get("instance") == null:
		return
	var target = target_node.creature if target_node and is_instance_valid(target_node) else null
	combat.play_card(card.instance, target)


# ─── Targeting ────────────────────────────────────────────────────────────────


func start_spell_targeting(card: Control) -> void:
	if is_targeting or is_instance_valid(_tool_confirm) or _tool_resolving:
		return
	if not can_afford([card]):
		show_notification(tr("UI_BATTLE_NOT_ENOUGH_ENERGY"), Color(1, 0.2, 0.2))
		return

	is_targeting = true
	targeting_card = card

	if not targeting_arrow:
		targeting_arrow = TARGETING_ARROW_SCRIPT.new()
		add_child(targeting_arrow)

	var arrow_origin = card.global_position + Vector2(card.size.x * 0.5, card.size.y * 0.25)
	targeting_arrow.start(arrow_origin)


## Returns the single alive enemy node if exactly one exists. Otherwise null
## (zero enemies → no target; multiple enemies → player still chooses).
## PUBLIC — read by play_card to decide arrow-vs-drag flow and by
## card_play_zone to auto-target attacks dropped into the zone.
func sole_alive_enemy() -> Node:
	return _sole_alive_enemy()


func _sole_alive_enemy() -> Node:
	if not enemy_container:
		return null
	var alive: Array = []
	for enemy in enemy_container.get_children():
		if is_instance_valid(enemy) and enemy.creature.is_alive():
			alive.append(enemy)
			if alive.size() > 1:
				return null  # short-circuit, more than one
	if alive.size() == 1:
		return alive[0]
	return null


func _cancel_spell_targeting() -> void:
	_clear_targeting_visuals()


func _clear_targeting_visuals() -> void:
	if hovered_unit:
		_set_hover_effect(hovered_unit, false)
		hovered_unit = null
	is_targeting = false
	targeting_card = null
	_hide_damage_preview()
	if targeting_arrow:
		targeting_arrow.stop()
		targeting_arrow.queue_free()
		targeting_arrow = null


## Called by PlayCard._handle_mouse_released() for attack cards.
## Fires attack at hovered enemy. Always requires hovering over an enemy.
func confirm_spell_targeting(card: Control) -> void:
	if not is_targeting or targeting_card != card:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return

	var unit_at_release = _get_unit_at_position(get_viewport().get_mouse_position())
	if unit_at_release != hovered_unit:
		if hovered_unit:
			_set_hover_effect(hovered_unit, false)
		hovered_unit = unit_at_release
		if hovered_unit:
			_set_hover_effect(hovered_unit, true)

	if hovered_unit and is_instance_valid(hovered_unit):
		var t = hovered_unit
		_cancel_spell_targeting()
		if hand.has_card(card):
			hand.remove_card(card)
		play_spell(card, t)
	else:
		show_notification(tr("UI_BATTLE_NO_TARGET"), Color(1, 0.6, 0.2))
		_cancel_spell_targeting()


# ─── Misc ─────────────────────────────────────────────────────────────────────


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout
