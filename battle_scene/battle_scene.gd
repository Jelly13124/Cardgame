extends Node

# --- Node References ---
@onready var card_manager = $CardManager
@onready var card_factory = $CardManager/MyCardFactory
@onready var hand = $CardManager/Hand
@onready var deck = $CardManager/Deck
@onready var discard_pile = $CardManager/DiscardPile
@onready var player = $Player
@onready var enemy_container = $EnemyContainer

const PAUSE_PANEL = preload("res://run_system/ui/pause_panel.gd")
@onready var turn_manager = $TurnManager
@onready var combat_engine = $CombatEngine
@onready var enemy_ai = $EnemyAI
@onready var ui_manager = $BattleUIManager
@onready var end_round_button = $EndRoundButton

var deck_manager: Node  # DeckManager (deck_manager.gd) instance
var relic_effect_system: RefCounted  # RelicEffectSystem (relic_effect_system.gd) instance
var equipment_set_system: RefCounted  # EquipmentSetSystem (equipment_set_system.gd) instance
var current_resolving_card: Node = null  # Set by play_spell during _apply_effect; combat_engine reads it.
# Typed via the preloaded CARD_ANIMATOR_SCRIPT below — kept as Node so this
# file parses even before Godot has scanned the class_name registry.
var card_animator: Node  # CardAnimator (card_animator.gd) instance

# --- Game State ---
var is_game_over: bool = false
var is_targeting: bool = false
var targeting_card: Control = null
var targeting_arrow: Node2D = null
var hovered_unit: Node = null
var _dmg_preview: Label = null
var _polarity_badge: Label = null  # H5: lazily-created HUD badge for yin/yang hero polarity
var _ending_turn: bool = false  # guards end_turn across the discard animation await
## Attack-allowance (double-fire clip): cap on attack cards per turn. 0 = unarmed
## (no limit — normal play). When armed, _attacks_left_this_turn is consumed by
## playing attacks and topped up by Reload cards; at 0, attacks are unplayable.
var _attack_limit_per_turn: int = 0
var _attacks_left_this_turn: int = 0

const TARGETING_ARROW_SCRIPT = preload("res://battle_scene/targeting_arrow.gd")
const RELIC_EFFECT_SYSTEM = preload("res://battle_scene/relic_effect_system.gd")
const EQUIPMENT_SET_SYSTEM = preload("res://battle_scene/equipment_set_system.gd")
const CARD_ANIMATOR_SCRIPT = preload("res://battle_scene/card_animator.gd")
const DECK_MANAGER_SCRIPT = preload("res://battle_scene/deck_manager.gd")
const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
# NOTE: map_scene + home_base_scene are loaded lazily at the call site
# (not preloaded) because doing so would create a cyclic dep
# (map → battle → map) and the editor's static analysis chokes.
const HOME_BASE_PATH := "res://run_system/ui/home_base_scene.tscn"
const MAP_SCENE_PATH := "res://run_system/ui/map_scene.tscn"
const LOOT_REWARD_SCENE = preload("res://run_system/ui/loot_reward.tscn")
const EXTRACT_CHOICE_MODAL_SCRIPT = preload("res://run_system/ui/extract_choice_modal.gd")
const RESULT_SCREEN_SCRIPT = preload("res://run_system/ui/result_screen.gd")
const TUTORIAL_TIPS_SCRIPT = preload("res://battle_scene/ui/tutorial_tips.gd")
const MAIN_MENU_PATH := "res://run_system/ui/main_menu.tscn"

const BOSS_VICTORY_CORE := 130
## Extract reward per act (keyed by RunManager.current_act). The final act has
## NO entry — clearing its boss wins the run outright (no extract choice). Any
## non-final act missing here falls back to a formula so adding a future act
## can't silently route to the "game complete" branch.
const EXTRACT_REWARDS := {
	1: {"continue": 26, "extract": 40},
	2: {"continue": 52, "extract": 85},
}


## Returns the {continue, extract} reward dict for the given act's boss, or
## {} if `act` is the final act (no extract choice — full victory).
func _extract_rewards_for_act(act: int) -> Dictionary:
	# Demo-aware: on the final act (Act 2 in the demo) there is no extract-vs-push
	# choice — the boss kill wins outright. acts_total() is 2 in the demo.
	if act >= RunManager.acts_total():
		return {}
	if EXTRACT_REWARDS.has(act):
		return EXTRACT_REWARDS[act]
	return {
		"continue": max(16, act * 16),
		"extract": max(33, act * 29),
	}


func _exit_tree() -> void:
	# Restore normal speed when leaving combat so the map / menus run at 1x
	# regardless of the battle-speed setting (Engine.time_scale is global).
	Engine.time_scale = 1.0


func _ready():
	print("BATTLE STARTING (STS Layout)")
	AudioManager.play_music("boss" if RunManager.last_battle_node_type == "boss" else "battle")
	card_manager.debug_mode = false
	Engine.time_scale = Settings.game_speed

	# Instantiate DeckManager
	deck_manager = DECK_MANAGER_SCRIPT.new()
	deck_manager.battle_scene = self
	deck_manager.deck = deck
	deck_manager.discard_pile = discard_pile
	deck_manager.hand = hand
	deck_manager.card_factory = card_factory
	add_child(deck_manager)

	# Instantiate CardAnimator — owns play / discard / exhaust tweens
	card_animator = CARD_ANIMATOR_SCRIPT.new()
	card_animator.setup(self)
	add_child(card_animator)

	# Apply textured wasteland button skin to the End Round button.
	if end_round_button:
		T.apply_button_theme(end_round_button)

	# Connect TurnManager
	turn_manager.round_changed.connect(_on_round_changed)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)

	# Connect Player Signals
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.energy_changed.connect(_on_player_energy_changed)
		player.block_changed.connect(_on_player_block_changed)
		player.stats_changed.connect(_update_ui_labels)
		player.status_changed.connect(_update_ui_labels)
		player.died.connect(_game_over)

	# Combat Engine Signals
	combat_engine.victory_declared.connect(_victory)

	_start_new_game()

	set_process(true)

	# First-battle tutorial tips — shown once ever, gated on MetaProgress.
	_maybe_show_tutorial()


## Show the first-battle tip sequence the very first time the player enters a
## battle, then mark it seen so it never reappears.
func _maybe_show_tutorial() -> void:
	if MetaProgress.tutorial_seen:
		return
	MetaProgress.mark_tutorial_seen()
	var canvas := CanvasLayer.new()
	canvas.layer = 240
	add_child(canvas)
	canvas.add_child(TUTORIAL_TIPS_SCRIPT.new())


# ─── Input ────────────────────────────────────────────────────────────────────


## _input fires before any Control node.
## ONLY intercepts right-click during targeting — never keyboard events,
## so Q/E pile-viewer shortcuts can still reach BattleUIManager.
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

	# Debug-only: right-click any enemy (outside targeting) → instant-kill.
	# Routes through the normal take_damage path so the died signal fires and
	# combat_engine declares victory once the last enemy is gone. Guarded on
	# OS.is_debug_build() so it's stripped from exported builds.
	if (
		OS.is_debug_build()
		and not is_targeting
		and event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_RIGHT
	):
		var mouse_pos = get_viewport().get_mouse_position()
		var enemy = _get_unit_at_position(mouse_pos)
		if enemy and is_instance_valid(enemy) and enemy.has_method("take_damage"):
			show_notification("DEBUG: killed %s" % enemy.name, Color(1, 0.4, 1))
			enemy.take_damage(99999)
			get_viewport().set_input_as_handled()
			return

	if not is_targeting:
		return
	# Only handle mouse buttons, never keyboard
	if not (event is InputEventMouseButton):
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_spell_targeting()
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if targeting_card and is_instance_valid(targeting_card):
			confirm_spell_targeting(targeting_card)
		else:
			_cancel_spell_targeting()
		get_viewport().set_input_as_handled()


# ─── Process ──────────────────────────────────────────────────────────────────


func _process(_delta: float) -> void:
	if not is_targeting:
		if hovered_unit:
			_set_hover_effect(hovered_unit, false)
			hovered_unit = null
		_hide_damage_preview()
		return

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
		var dmg := _card_preview_damage(targeting_card, preview_target)
		if dmg >= 0:
			_show_damage_preview(preview_target, dmg)
		else:
			_hide_damage_preview()
	else:
		_hide_damage_preview()


## Predicted post-mitigation damage `card` would deal to `target` (incl. global
## STR, weak/vulnerable, relics via calculate_attack_damage). -1 if not a damage card.
func _card_preview_damage(card: Control, target: Node) -> int:
	if not (card and is_instance_valid(card) and "card_info" in card):
		return -1
	var effects: Array = card.card_info.get("effects", [])
	var str_val := int(player.get("strength")) if player else 0
	var base_total := 0
	var has_damage := false
	for effect in effects:
		var etype := str(effect.get("type", ""))
		match etype:
			"deal_damage", "deal_damage_all":
				var amt := int(effect.get("amount", 0))
				var mult := float(effect.get("multiplier", 1))
				if mult != 1:
					amt = int(amt * mult)
				base_total += amt + str_val
				has_damage = true
			"deal_damage_str_mult":
				base_total += int(str_val * float(effect.get("mult", 1)))
				has_damage = true
			"scale_damage_by_attacks":
				var count := int(turn_manager.attacks_played_this_turn) if turn_manager else 0
				base_total += int(effect.get("base", 0)) + int(effect.get("per", 0)) * count
				has_damage = true
	if not has_damage:
		return -1
	# Double Damage status doubles the hit (combat_engine applies card_mult=2).
	if (
		player
		and player.has_method("get_status_stacks")
		and player.get_status_stacks("double_damage") > 0
	):
		base_total *= 2
	# preview=true: predicted number only — must not consume Deadeye's guaranteed
	# crit or fire crit side effects (this runs every frame while aiming).
	return combat_engine.calculate_attack_damage(base_total, player, target, true)


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
## flip / harmony by combat_engine + relic_effect_system (guarded by has_method),
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


func _set_hover_effect(unit: Node, active: bool) -> void:
	if not is_instance_valid(unit):
		return
	var scale_target = Vector2(1.2, 1.2) if active else Vector2(1.0, 1.0)
	var modulate_target = Color(1.5, 1.2, 1.2) if active else Color.WHITE
	var tween = create_tween().set_parallel(true)
	tween.tween_property(unit, "scale", scale_target, 0.1)
	tween.tween_property(unit, "modulate", modulate_target, 0.1)


## Returns the enemy node under a screen position (viewport coords).
## EnemyEntity reports its rendered body rect so targeting matches current sprite scale.
func _get_unit_at_position(pos: Vector2) -> Node:
	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy):
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


func show_notification(text: String, color: Color = Color.WHITE):
	ui_manager.show_notification(text, color)


## Use a top-bar tool (StS2-style one-time consumable). Self/none tools resolve
## immediately; enemy tools hit the first alive enemy (multi-enemy pick is a later
## refinement). Effect amounts scale with Intelligence; consumed after resolving.
func use_tool(index: int) -> void:
	if index < 0 or index >= RunManager.tool_inventory.size():
		return
	var tdata: Dictionary = RunManager.get_tool_data(str(RunManager.tool_inventory[index]))
	if tdata.is_empty():
		return
	var target: Node = null
	if str(tdata.get("target", "none")) == "enemy":
		for c in enemy_container.get_children():
			if (
				is_instance_valid(c)
				and not c.is_queued_for_deletion()
				and c.has_method("take_damage")
			):
				target = c
				break
		if target == null:
			AudioManager.play_sfx("error")
			return
	await _resolve_tool(index, tdata, target)


func _resolve_tool(index: int, tdata: Dictionary, target: Node) -> void:
	AudioManager.play_sfx("ui_click")
	var int_mult: float = 1.0 + 0.08 * float(RunManager._attr("intelligence"))
	for eff in tdata.get("effects", []):
		if typeof(eff) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = (eff as Dictionary).duplicate(true)
		if e.has("amount"):
			e["amount"] = int(round(float(e["amount"]) * int_mult))
		await combat_engine._apply_effect(
			e, target if is_instance_valid(target) else null, player, 1.0
		)
	RunManager.consume_tool(index)


# ─── Turn Events ──────────────────────────────────────────────────────────────


func _on_turn_started(side: String) -> void:
	if is_game_over:
		return
	if side == "enemy":
		enemy_ai.execute_enemy_turn()
		return

	# Player turn start: reset block + energy via player.start_turn()
	AudioManager.play_sfx("turn_start")
	player.start_turn()
	if is_game_over:
		return
	# Reset the per-turn guaranteed-first-attack Crit (Deadeye Crit Clip).
	combat_engine.reset_turn_crit()
	# Reset the attack allowance for the new turn (double-fire clip arms this).
	_attack_limit_per_turn = (
		relic_effect_system.attack_limit_per_turn() if relic_effect_system else 0
	)
	# Burst-Fire Clip: +1 allowance on the first turn only (2 attacks on turn 1).
	if _attack_limit_per_turn > 0 and relic_effect_system and turn_manager.current_round == 1:
		_attack_limit_per_turn += relic_effect_system.first_turn_bonus_allowance()
	_attacks_left_this_turn = _attack_limit_per_turn
	_update_attack_allowance_ui()
	# Ascension A3+: first turn of each combat starts with -1 energy.
	if RunManager.ascension >= 3 and turn_manager.current_round == 1:
		player.pay_energy(1)
	if relic_effect_system:
		relic_effect_system.on_player_turn_started(player, turn_manager.current_round)
	if equipment_set_system:
		equipment_set_system.on_player_turn_started(player, turn_manager.current_round)
	_update_ui_labels()
	update_polarity_hud()  # H5: reflect opening polarity state on the HUD badge
	enemy_ai.spawn_enemy_units()

	_ending_turn = false  # re-arm the end-turn guard
	if turn_manager.current_round == 1:
		deck_manager.first_round_draw()
	else:
		deck_manager.draw_cards(3)


## STS rule: at END of player turn, reset block/energy. Hand discard is handled
## upstream in `_on_end_round_button_pressed` so the animation fully completes
## before turn_manager switches sides.
func _on_turn_ended(side: String) -> void:
	if side == "player":
		player.end_turn()
		_update_ui_labels()


## End-of-turn discard cascade: each remaining hand card flies to the discard
## pile with a small stagger. Without this, dropping them straight into the
## discard pile (hide_cards=true) would make them vanish on the same frame
## they're added, with no visual cue that they were discarded.
func _animate_hand_discard(cards: Array) -> void:
	const STAGGER := 0.07
	const FLIGHT_DURATION := 0.36  # matches fly_to_discard tween length + buffer
	for i in range(cards.size()):
		var card = cards[i]
		if not is_instance_valid(card):
			continue
		# Detach from hand first so the surviving cards re-fan around the gap.
		if card.card_container and card.card_container.has_card(card):
			card.card_container.remove_card(card)
		# Fire-and-forget: each fly_to_discard runs in parallel via its own tween.
		card_animator.fly_to_discard(card)
		if i < cards.size() - 1:
			await _wait(STAGGER)
	# Wait for the LAST card's flight before parking everything in discard.
	await _wait(FLIGHT_DURATION)
	for card in cards:
		if is_instance_valid(card):
			discard_pile.add_card(card)
			card.modulate.a = 1.0  # restore alpha after fly_to_discard faded it


func _on_round_changed(_round: int) -> void:
	_update_ui_labels()


func _on_player_health_changed(_hp: int) -> void:
	_update_ui_labels()


func _on_player_energy_changed(_energy: int) -> void:
	_update_ui_labels()


func _on_player_block_changed(_block: int) -> void:
	_update_ui_labels()


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
		if card.has_method("update_display"):
			card.update_display()
	_refresh_pile_counts()


## Draw-pile / discard-pile card counts, drawn on each pile's back. Refreshed on
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
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 30
		lbl.add_theme_font_size_override("font_size", 30)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
		lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		lbl.add_theme_constant_override("outline_size", 6)
		pile.add_child(lbl)
	lbl.text = str(n)


# ── Exhaust pile (hidden): exhausted cards collect here instead of vanishing.
# Open it with the X key or the on-screen indicator that appears once non-empty.
var _exhausted_card_names: PackedStringArray = []


func view_exhaust_pile() -> void:
	ui_manager.show_pile_viewer_from_names(
		tr("UI_BATTLE_EXHAUST_PILE"), _exhausted_card_names, "exhaust"
	)


func _refresh_exhaust_indicator() -> void:
	var n: int = _exhausted_card_names.size()
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


## Initialise a new battle from RunManager state (or defaults if no run is active).
func _start_new_game():
	is_game_over = false
	_gold_effect_triggers = 0

	relic_effect_system = RELIC_EFFECT_SYSTEM.new()
	relic_effect_system.setup(self)
	equipment_set_system = EQUIPMENT_SET_SYSTEM.new()
	equipment_set_system.setup(self)

	# ── Player HP & Attributes ──────────────────────────────────────────────
	if RunManager.is_run_active:
		player.max_health = RunManager.max_health
		player.health = RunManager.current_health
		var attrs = RunManager.player_attributes
		player.strength = int(attrs.get("strength", 3))
		player.constitution = int(attrs.get("constitution", 3))
		player.intelligence = int(attrs.get("intelligence", 3))
		player.luck = int(attrs.get("luck", 3))
		player.charm = int(attrs.get("charm", 3))
		# Enemy roster comes from the map encounter data stored in RunManager
		if RunManager.current_encounter.size() > 0:
			enemy_ai.enemy_roster = RunManager.current_encounter

	# Passive relic stat grants at battle start (war_horn +STR, bulk_actuator).
	# Runs after player attributes are seeded above so it stacks on the base.
	if relic_effect_system:
		relic_effect_system.on_battle_started(player)

	# Snapshot active equipment set tiers (and apply start_battle_block)
	if equipment_set_system:
		equipment_set_system.on_battle_started(player)

	# ── Deck & Turn ──────────────────────────────────────────────────────────
	deck_manager.reset_deck()
	turn_manager.start_new_game()


func _on_end_round_button_pressed():
	# Guard against double-fire across the discard-animation await (auto-end +
	# manual click, or two fast clicks). Reset at the next player turn start.
	if _ending_turn or not turn_manager.is_player_turn:
		return
	_ending_turn = true
	if turn_manager.is_player_turn:
		# Discard hand BEFORE switching turns. turn_manager.end_turn() emits
		# turn_ended synchronously and immediately switches sides; awaiting an
		# animation inside the signal handler doesn't block that switch, so the
		# next player draw would race against the in-flight discard and see an
		# empty discard pile (breaking reshuffle when deck < draw count).
		var remaining = hand.get_cards().duplicate()
		var to_discard: Array = []
		for c in remaining:
			if is_instance_valid(c) and bool(c.card_info.get("retain", false)):
				continue
			to_discard.append(c)
		if to_discard.size() > 0:
			await _animate_hand_discard(to_discard)
		turn_manager.end_turn()


func _victory():
	if is_game_over:
		return
	is_game_over = true
	AudioManager.play_sfx("victory")
	# Combat is over — neutralise any in-flight card drag NOW, before the 3s gap +
	# loot modal (MOUSE_FILTER_STOP) can swallow the mouse-release and leave a card
	# stuck in HOLDING, which permanently locks all future drags. (Bug fix.)
	_reset_hand_drag_state()
	if relic_effect_system:
		relic_effect_system.on_combat_victory(player)
	# Victory path: persist HP without firing the death gate, even if the
	# player ended the fight at 0 HP (chip damage / mutual kill). Otherwise
	# modify_health(negative) would trigger _handle_run_loss → run_ended(false),
	# and the subsequent end_run_victory() at the boss branch would no-op.
	_write_hp_to_run_manager(false)
	# VICTORY! banner removed per UX feedback — the loot modal / extract
	# choice / home-base transition is sufficient signal that the fight is won.
	await get_tree().create_timer(3.0).timeout

	# Caps award (Phase E2): accrue run-scoped caps sized by fight type. Like
	# Core, caps stay at death-risk until banked by _settle_backpack on
	# extract/victory. award_caps_for_combat dispatches boss/elite/normal so a
	# boss fight grants ONLY the boss award (no boss + normal double-count).
	RunManager.award_caps_for_combat(RunManager.last_battle_node_type)
	# In-run XP: queue a card draft per level gained (consumed by the loot screen).
	RunManager.gain_xp(RunManager.last_battle_node_type)

	# Boss victory routing:
	#   - non-final act boss → extract choice modal (rewards by current_act)
	#   - final boss   → grant BOSS_VICTORY_CORE and return to home base
	#   - non-boss     → normal loot modal
	if RunManager.last_battle_node_type == "boss":
		# Boss reward: grant 1 random gem (relic comes via the extract-choice rewards).
		var boss_gems: Array = RunManager.gem_pool()
		if not boss_gems.is_empty():
			var bgem := str(boss_gems[randi() % boss_gems.size()])
			if not RunManager.add_gem_to_backpack(bgem):
				# Bag full — warn rather than silently dropping the boss gem.
				show_notification(tr("UI_LOOT_BACKPACK_FULL"), Color(1.0, 0.45, 0.4))
		# Boss also drops equipment — now the ONLY equipment source in the run.
		var boss_eq := RunManager.roll_equipment_drop("rare")
		if boss_eq != "":
			var eq_inst := RunManager.make_equip_instance(boss_eq, "rare")
			if not RunManager.add_equip_to_backpack(eq_inst):
				show_notification(tr("UI_LOOT_BACKPACK_FULL"), Color(1.0, 0.45, 0.4))
		var act: int = RunManager.current_act
		var rewards: Dictionary = _extract_rewards_for_act(act)
		if not rewards.is_empty():
			_show_extract_choice(act, rewards)
			return
		# Final boss path: Core drops into the backpack; _settle_backpack
		# banks it during _teardown_run, so end_run_victory's banked-core arg
		# is 0 to avoid double-counting.
		RunManager.add_core_to_backpack(BOSS_VICTORY_CORE)
		RunManager.end_run_victory(0, "victory")
		# Demo: the final-act (Act 2) boss kill ends the demo — show the
		# demo-complete / wishlist screen instead of silently returning to base.
		_show_result_screen("demo_complete")
		return
	# Elite kills drop a small amount of Core into the backpack (still at
	# death risk until extraction); the normal loot flow handles the rest.
	if RunManager.last_battle_node_type == "elite":
		RunManager.add_core_to_backpack(randi_range(8, 16))
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
	canvas.layer = 200
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
	if extract:
		# Extract: Core is already in the backpack from the boss kill, and
		# _settle_backpack banks it during _teardown_run, so pass 0 here.
		var earned: int = int(rewards.get("extract", 0))
		RunManager.add_core_to_backpack(earned)
		RunManager.end_run_victory(0, "extracted")
		SceneTransition.change_to(HOME_BASE_PATH)
	else:
		# Push on: push-on Core drops into the backpack (still at death risk),
		# advance to the next act (regenerates its fresh map), then drop into the
		# normal loot flow so the player still gets gold + a card pick out of the
		# boss kill. Loot closes → MAP_SCENE shows the new act's map.
		RunManager.add_core_to_backpack(int(rewards.get("continue", 0)))
		RunManager.advance_act()
		_show_loot_modal()


func _show_loot_modal() -> void:
	# Wrap in a CanvasLayer with high `layer` so the modal renders above
	# battle_scene's TopBar/Inspect/PileViewer CanvasLayers (layers 30/100/101)
	# AND eats mouse events so cards in hand don't react to hover.
	var canvas := CanvasLayer.new()
	canvas.layer = 200
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
	if is_game_over:
		return
	is_game_over = true
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


func modify_player_attack_damage(amount: int, attacker: Node, defender: Node) -> int:
	if relic_effect_system:
		return relic_effect_system.modify_player_attack_damage(amount, attacker, defender)
	return amount


func modify_enemy_attack_damage(amount: int, attacker: Node, defender: Node) -> int:
	var result := amount
	if relic_effect_system:
		result = relic_effect_system.modify_enemy_attack_damage(result, attacker, defender)
	# Per-act enemy damage scaling (bosses exempt). Applied after relic
	# modifiers so relic flat-reductions read against the pre-act number.
	if attacker and "enemy_id" in attacker:
		result = RunManager.scale_enemy_damage(result, str(attacker.enemy_id))
	return result


# ─── Energy ───────────────────────────────────────────────────────────────────


func can_afford(cards: Array) -> bool:
	if is_game_over or not player:
		return false
	var total_cost = 0
	for card in cards:
		total_cost += int(card.card_info.get("cost", 0))
	return player.energy >= total_cost


func spend_energy(cards: Array) -> void:
	var total_cost = 0
	for card in cards:
		total_cost += int(card.card_info.get("cost", 0))
	player.pay_energy(total_cost)


# ─── Attack allowance (double-fire clip) ──────────────────────────────────────


## Grant +n attacks this turn. No-op when the limit isn't armed.
func add_attack_allowance(n: int) -> void:
	if _attack_limit_per_turn <= 0:
		return
	_attacks_left_this_turn += n
	_update_attack_allowance_ui()


## Refresh the attack allowance back up to the per-turn cap (Reload card). Does
## NOT stack past the cap — so you can fire again, but can't bank extra attacks.
## Also fires the Covering Reload power (Block on every Reload).
func restore_attack_allowance() -> void:
	AudioManager.play_sfx("reload")
	# Covering Reload power: gain 3 Block whenever a Reload is played (independent
	# of whether the attack cap is armed).
	if (
		player
		and player.has_method("get_status_stacks")
		and player.get_status_stacks("covering_reload") > 0
		and player.has_method("add_block")
	):
		player.add_block(3)
		if player.has_method("play_block_pulse"):
			player.play_block_pulse()
	if _attack_limit_per_turn <= 0:
		return
	_attacks_left_this_turn = max(_attacks_left_this_turn, _attack_limit_per_turn)
	_update_attack_allowance_ui()


## Mirror the attack allowance onto the player's "bullet" status (shown in the
## status bar). The clip arms it: 1 bullet at turn start, max 1; spent by
## attacking, restored by Reload. Cleared/absent when the allowance isn't armed.
func _update_attack_allowance_ui() -> void:
	if not (player and player.status_system):
		return
	player.status_system.remove_status("bullet", player)
	if _attack_limit_per_turn > 0 and _attacks_left_this_turn > 0:
		player.status_system.add_status("bullet", _attacks_left_this_turn, player)


# ─── Card Play ────────────────────────────────────────────────────────────────


## Play a card. target_node is the enemy to hit (null for skill/ability).
## Multiple cards can be in flight simultaneously — animations overlap. A
## per-card `_in_play` meta lock prevents the same card from being resolved
## twice (e.g. double-click, double drop).
func play_spell(card: Control, target_node: Node):
	if is_game_over:
		return
	if not is_instance_valid(card):
		return

	# Per-card lock — different cards can play in parallel, but the SAME
	# card can't be played twice before its first resolution finishes.
	if card.has_meta("_in_play"):
		return
	card.set_meta("_in_play", true)

	var type = card.card_info.get("type", "skill").to_lower()

	if type == "attack":
		if not target_node or not is_instance_valid(target_node):
			AudioManager.play_sfx("error")
			show_notification(tr("UI_BATTLE_MUST_TARGET_ENEMY"), Color(0.8, 0.4, 0.4))
			hand.add_card(card)
			card.remove_meta("_in_play")
			return
		# Attack-allowance gate (double-fire clip): no attacks left this turn → the
		# attack is unplayable. Return it to hand and explain via a notification.
		if _attack_limit_per_turn > 0 and _attacks_left_this_turn <= 0:
			AudioManager.play_sfx("error")
			show_notification(tr("UI_BATTLE_NO_ATTACKS_LEFT"), Color(0.85, 0.55, 0.3))
			hand.add_card(card)
			card.remove_meta("_in_play")
			return
		if _attack_limit_per_turn > 0:
			_attacks_left_this_turn -= 1
			_update_attack_allowance_ui()

	# Deduct cost; remove from current container if still tracked there. Per-type play
	# sound (attack swipe / skill whoosh / power charge); other types (status, curse…)
	# fall back to the generic card_play.
	var play_sfx_name: String = "card_play"
	if type in ["attack", "skill", "power"]:
		play_sfx_name = "card_play_" + type
	AudioManager.play_sfx(play_sfx_name)
	spend_energy([card])
	if card.card_container and card.card_container.has_card(card):
		card.card_container.remove_card(card)

	card_animator.prepare_for_play(card)
	await card_animator.fly_to_play_area(card, target_node)

	# Resolve combat effects (may await animations). current_resolving_card
	# lets combat_engine + equipment_set_system identify the card behind each
	# effect (needed to know whether a gain_block came from a "skill" card etc.).
	current_resolving_card = card
	# target_node can be freed DURING the fly_to_play_area await above — the
	# targeted enemy may have died from a parallel in-flight card or a DOT tick.
	# A previously-freed Object fails resolve_card_effect's typed `target: Node`
	# parameter check BEFORE its body's is_instance_valid guards can run, so
	# sanitise to null here. The resolver already treats a null target as
	# "no target" (skill/ability cards pass null routinely).
	var safe_target: Node = target_node if is_instance_valid(target_node) else null
	await combat_engine.resolve_card_effect(card, safe_target, player)
	current_resolving_card = null

	# Release the per-card play lock NOW. The play is logically complete —
	# what's left below is pure animation/routing. If we don't release here,
	# the meta survives the trip through discard → reshuffle → deck → hand,
	# and the card silently refuses to play on its next draw.
	if is_instance_valid(card):
		card.remove_meta("_in_play")

	# Route to discard, OR remove from circulation if exhaust_self is among
	# the card's effects.
	var should_exhaust := _card_has_exhaust(card)
	if is_instance_valid(card):
		if card.card_container and card.card_container.has_card(card):
			card.card_container.remove_card(card)
		if should_exhaust:
			_trigger_exhaust_powers()
			# Keep the card's identity for the (hidden) Exhaust pile before it's freed.
			var ex_name: String = (
				str(card.card_info.get("name", "")) if is_instance_valid(card) else ""
			)
			await card_animator.fly_to_exhaust(card)
			if ex_name != "":
				_exhausted_card_names.append(ex_name)
			if is_instance_valid(card):
				card.queue_free()
		else:
			await card_animator.fly_to_discard(card)
			if is_instance_valid(card):
				discard_pile.add_card(card)
				card.modulate.a = 1.0  # restore alpha after discard

	_update_ui_labels()
	refresh_hand_ui()


## Gold from a card/gem `gain_gold` effect (the wealthy gem). When `cap > 0` the
## grant is limited to `cap` triggers per combat (wealthy = 3); cap 0 = uncapped.
var _gold_effect_triggers: int = 0


func try_gain_gold(amount: int, cap: int) -> void:
	if cap > 0 and _gold_effect_triggers >= cap:
		return
	if cap > 0:
		_gold_effect_triggers += 1
	RunManager.add_resources(amount, 0)
	show_notification(tr("UI_COMBAT_WEALTHY").format({"n": amount}), Color(1.0, 0.82, 0.29))


## Fire the player's on-exhaust power triggers when a card routes to Exhaust:
## feel_no_pain → gain Block, dark_embrace → draw. Called once per exhausted card.
func _trigger_exhaust_powers() -> void:
	if not is_instance_valid(player) or not player.status_system:
		return
	var fnp: int = player.status_system.get_stacks("feel_no_pain")
	if fnp > 0:
		player.add_block(fnp)
		if player.has_method("play_block_pulse"):
			player.play_block_pulse()
	var de: int = player.status_system.get_stacks("dark_embrace")
	if de > 0 and deck_manager:
		deck_manager.draw_cards(de)


## Returns true if the card has an `exhaust_self` effect entry.
func _card_has_exhaust(card: Control) -> bool:
	if not is_instance_valid(card):
		return false
	var effects: Array = card.card_info.get("effects", [])
	for e in effects:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "exhaust_self":
			return true
	return false


# ─── Targeting ────────────────────────────────────────────────────────────────


func start_spell_targeting(card: Control) -> void:
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
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			alive.append(enemy)
			if alive.size() > 1:
				return null  # short-circuit, more than one
	if alive.size() == 1:
		return alive[0]
	return null


func _cancel_spell_targeting() -> void:
	if hovered_unit:
		_set_hover_effect(hovered_unit, false)
		hovered_unit = null
	is_targeting = false
	targeting_card = null
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
