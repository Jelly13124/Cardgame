extends Card
class_name PlayCard

# Preloaded so we don't depend on Godot's class_name registry being warm at parse time.
const STATUS_SYS = preload("res://battle_scene/status_effect_system.gd")

@onready var cost_label = $FrontFace/CostCircle/CostLabel
@onready var cost_badge = $FrontFace/CostCircle
@onready var name_label = $FrontFace/NameLabel
@onready var desc_label = $FrontFace/DescriptionBox/DescriptionLabel
@onready var type_label = $FrontFace/RaceBox/RaceLabel
@onready var card_bg_texture = $FrontFace/TextureRect
@onready var desc_box_texture = $FrontFace/DescriptionBox
@onready var type_badge_texture = $FrontFace/RaceBox
@onready var playable_glow = $FrontFace/PlayableGlow
@onready var art_frame_texture = $FrontFace/ArtFrameTexture
@onready var art_bg = $FrontFace/ArtBackground
@onready var art_texture = $FrontFace/ArtContainer/ArtTexture

const UI_ASSET_PATH = "res://battle_scene/assets/images/cards/ui/"
const COST_BADGE_PATH = UI_ASSET_PATH + "card_cost_badge.png"
const DESC_BOX_PATH = UI_ASSET_PATH + "card_description_box.png"
const TYPE_BADGE_PATH = UI_ASSET_PATH + "card_type_badge.png"

var _hover_tween: Tween
var _glow_tween: Tween

var _rarity_frames: Dictionary = {}


func _ready() -> void:
	super._ready()
	# Load the card background art (front)
	var bg = load(UI_ASSET_PATH + "card_bg.png")
	if bg and is_instance_valid(card_bg_texture):
		card_bg_texture.texture = bg
		card_bg_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		card_bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_bg_texture.stretch_mode = TextureRect.STRETCH_SCALE

	var desc_tex = _load_texture_fallback(DESC_BOX_PATH)
	if desc_tex and is_instance_valid(desc_box_texture):
		desc_box_texture.texture = desc_tex
		desc_box_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		desc_box_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		desc_box_texture.stretch_mode = TextureRect.STRETCH_SCALE

	var type_tex = _load_texture_fallback(TYPE_BADGE_PATH)
	if type_tex and is_instance_valid(type_badge_texture):
		type_badge_texture.texture = type_tex
		type_badge_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		type_badge_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		type_badge_texture.stretch_mode = TextureRect.STRETCH_SCALE

	var cost_tex = _load_texture_fallback(COST_BADGE_PATH)
	if cost_tex and is_instance_valid(cost_badge):
		cost_badge.texture = cost_tex
		cost_badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		cost_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cost_badge.stretch_mode = TextureRect.STRETCH_SCALE
	_style_cost_label()
	# Load card back art — shown when card is face-down (draw/discard piles)
	var back_tex = load(UI_ASSET_PATH + "card_back.png")
	var back_rect = get_node_or_null("BackFace/TextureRect")
	if back_tex and is_instance_valid(back_rect):
		back_rect.texture = back_tex
		back_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back_rect.stretch_mode = TextureRect.STRETCH_SCALE
		back_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Pre-cache rarity frame textures
	for r in ["common", "uncommon", "rare"]:
		var tex = load(UI_ASSET_PATH + "art_frame_%s.png" % r)
		if tex:
			_rarity_frames[r] = tex
	if not card_info.is_empty():
		set_card_data(card_info)

	# Connect hover signals for scaling
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	pivot_offset = size / 2.0  # Ensure we scale from center


func _style_cost_label() -> void:
	if not is_instance_valid(cost_label):
		return
	cost_label.position = Vector2.ZERO
	cost_label.size = cost_badge.size
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 1.0))
	cost_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	cost_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	cost_label.add_theme_constant_override("outline_size", 2)
	cost_label.add_theme_constant_override("shadow_offset_x", 0)
	cost_label.add_theme_constant_override("shadow_offset_y", 0)
	cost_label.add_theme_font_size_override("font_size", 19)


func set_faces(front: Texture2D, back: Texture2D) -> void:
	art_texture.texture = front
	$BackFace/TextureRect.texture = back


func _load_texture_fallback(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			return ImageTexture.create_from_image(image)
	return null


## Called when the player PRESSES the left mouse button on this card.
func _handle_mouse_pressed() -> void:
	var main = get_tree().current_scene
	var c_type = card_info.get("type", "skill").to_lower()

	if c_type == "attack" and not _attack_should_drag(main):
		# Start targeting mode — arrow follows mouse while button is held.
		# Do NOT call super so the card does not enter HOLDING/drag state.
		if main and main.has_method("start_spell_targeting"):
			main.start_spell_targeting(self)
	else:
		# Skill / Ability — OR attack with only one valid enemy — uses the
		# drag-up-into-CardPlayZone flow. card_play_zone.move_cards picks the
		# sole enemy automatically when the dropped card is an attack.
		super._handle_mouse_pressed()


## Called when the player RELEASES the left mouse button.
## For attack cards in targeting mode, release confirms/cancels the attack.
func _handle_mouse_released() -> void:
	var main = get_tree().current_scene
	var c_type = card_info.get("type", "skill").to_lower()

	if (
		c_type == "attack"
		and not _attack_should_drag(main)
		and main
		and main.has_method("confirm_spell_targeting")
	):
		main.confirm_spell_targeting(self)
		return  # Do NOT call super — card stays in hand until attack fires
	# Fall through to super so the drag path (skills, or attacks-with-sole-enemy)
	# resolves its drop normally.
	super._handle_mouse_released()


## Attack uses drag-into-play-zone (rather than aim-arrow) when there's only
## one valid enemy — no choice to make, so the play-zone gesture matches the
## skill flow and saves the arrow ceremony.
func _attack_should_drag(main) -> bool:
	if not main or not main.has_method("sole_alive_enemy"):
		return false
	return main.sole_alive_enemy() != null

	super._handle_mouse_released()


func set_card_data(data: Dictionary) -> void:
	if not is_instance_valid(self):
		return

	card_info = data
	card_name = data.get("name", "Unknown")

	# ── Cost: always integer ──────────────────────────────────────────────────
	cost_label.text = str(int(data.get("cost", 0)))
	_style_cost_label()

	# ── Name (CONTENT) ───────────────────────────────────────────────────────
	# Title comes from card data — route through Settings.t with the card's
	# deterministic content key (CARD_<id>_TITLE), English fallback.
	var card_id: String = str(data.get("name", card_name))
	name_label.text = (
		Settings.t("CARD_%s_TITLE" % card_id, str(data.get("title", card_name))).to_upper()
	)

	# ── Description: build from effects[] showing real calculated numbers ────
	var desc = _build_description(data)
	desc_label.parse_bbcode("[center][font_size=13]" + desc + "[/font_size][/center]")

	# ── Rarity: swap the art FRAME texture ───────────────────────────────────
	var rarity = data.get("rarity", "common").to_lower()
	if rarity in _rarity_frames:
		art_frame_texture.texture = _rarity_frames[rarity]
	else:
		art_frame_texture.texture = _rarity_frames.get("common")
	art_frame_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# ── Type label ────────────────────────────────────────────────────────────
	# Card art is uniformly square now; the old attack-card V-shape mask was removed.
	var c_type = data.get("type", "skill").to_lower()
	var is_atk = c_type == "attack"

	if is_atk:
		type_label.text = tr("UI_BATTLE_CARD_TYPE_ATTACK")
		type_label.modulate = Color(1, 0.4, 0.4)
	elif c_type == "skill":
		type_label.text = tr("UI_BATTLE_CARD_TYPE_SKILL")
		type_label.modulate = Color(0.4, 0.8, 1.0)
	elif c_type == "ability":
		type_label.text = tr("UI_BATTLE_CARD_TYPE_ABILITY")
		type_label.modulate = Color(0.8, 0.4, 1.0)
	else:
		type_label.text = c_type.to_upper()


## Build a plain-text description from the effects[] array.
## Shows calculated totals e.g. "Deal 6 (3+Strength) dmg" when player has 3 STR.
## Falls back to the raw "description" field if no effects array exists.
func _build_description(data: Dictionary) -> String:
	var card_id: String = str(data.get("name", ""))
	var effects: Array = data.get("effects", [])
	if effects.is_empty():
		# Raw description is CONTENT — route through Settings.t (CARD_<id>_DESC)
		# with the English source as fallback, THEN strip BBCode for plain display.
		var raw: String = Settings.t("CARD_%s_DESC" % card_id, str(data.get("description", "")))
		return (
			raw
			. replace("[b]", "")
			. replace("[/b]", "")
			. replace("[i]", "")
			. replace("[/i]", "")
			. replace("[center]", "")
			. replace("[/center]", "")
		)

	# Get current player stats for display (live values if battle is running)
	var stats = _get_player_stats()

	var lines: PackedStringArray = []
	for effect in effects:
		var etype: String = effect.get("type", "")
		var base: int = int(effect.get("amount", 0))
		var scaling: String = effect.get("scaling", "")  # legacy; effectively always "" now
		var mult: float = float(effect.get("multiplier", 1))
		var stacks: int = int(effect.get("stacks", 1))

		# Global attributes mirror combat_engine._apply_effect: the multiplier hits
		# the BASE first, THEN STR auto-adds to attack damage / CON to block. The old
		# per-card `scaling` field is gone, so the breakdown is driven purely by etype.
		var base_after_mult: int = int(base * mult) if mult != 1 else base
		var stat_val: int = 0
		if etype == "deal_damage" or etype == "deal_damage_all":
			stat_val = int(stats.get("strength", 0))
		elif etype == "gain_block":
			stat_val = int(stats.get("constitution", 0))

		var total: int = base_after_mult + stat_val

		# Apply status effect multipliers for display
		var final_damage: int = total
		var final_block: int = total

		if etype.contains("damage"):
			final_damage = int(final_damage * stats.get("outgoing_mult", 1.0))
			if stats.get("double_damage", 0) > 0:
				final_damage *= 2

		match etype:
			"deal_damage":
				var label_val = _color_num(final_damage, total)
				if stat_val > 0:
					lines.append(
						tr("UI_BATTLE_DESC_DEAL_SCALING").format(
							{"val": label_val, "base": base_after_mult, "stat": stat_val}
						)
					)
				else:
					lines.append(tr("UI_BATTLE_DESC_DEAL").format({"val": label_val}))

			"deal_damage_all":
				var label_val = _color_num(final_damage, total)
				if stat_val > 0:
					lines.append(
						tr("UI_BATTLE_DESC_DEAL_ALL_SCALING").format(
							{"val": label_val, "base": base_after_mult, "stat": stat_val}
						)
					)
				else:
					lines.append(tr("UI_BATTLE_DESC_DEAL_ALL").format({"val": label_val}))

			"gain_block":
				var label_val = _color_num(final_block, total)
				if stat_val > 0:
					lines.append(
						tr("UI_BATTLE_DESC_BLOCK_SCALING").format(
							{"val": label_val, "base": base_after_mult, "stat": stat_val}
						)
					)
				else:
					lines.append(tr("UI_BATTLE_DESC_BLOCK").format({"val": label_val}))

			"gain_strength":
				if mult != 1:
					lines.append(
						tr("UI_BATTLE_DESC_STRENGTH_MULT").format(
							{"n": total, "mult": int(mult), "stat": scaling.capitalize()}
						)
					)
				elif scaling != "" and stat_val > 0:
					lines.append(
						tr("UI_BATTLE_DESC_STRENGTH_SCALING").format(
							{"n": total, "base": base, "stat": stat_val}
						)
					)
				else:
					lines.append(tr("UI_BATTLE_DESC_STRENGTH").format({"n": total}))

			"gain_constitution", "gain_intelligence", "gain_luck", "gain_charm", "gain_energy":
				# Localize the attribute term itself (glossary), then frame it.
				var attr_key := "UI_BATTLE_ATTR_" + etype.trim_prefix("gain_").to_upper()
				lines.append(
					tr("UI_BATTLE_DESC_GAIN_ATTR").format({"n": total, "attr": tr(attr_key)})
				)

			"draw_cards":
				lines.append(tr("UI_BATTLE_DESC_DRAW").format({"n": base}))

			"apply_status":
				lines.append(
					tr("UI_BATTLE_DESC_APPLY_STATUS").format(
						{"status": STATUS_SYS.format_name(effect.get("status", "")), "n": stacks}
					)
				)

			"apply_status_all":
				lines.append(
					tr("UI_BATTLE_DESC_APPLY_STATUS_ALL").format(
						{"status": STATUS_SYS.format_name(effect.get("status", "")), "n": stacks}
					)
				)

			"apply_status_self":
				lines.append(
					tr("UI_BATTLE_DESC_APPLY_STATUS_SELF").format(
						{"status": STATUS_SYS.format_name(effect.get("status", "")), "n": stacks}
					)
				)

			"deal_damage_str_mult":
				lines.append(
					tr("UI_BATTLE_DESC_DAMAGE_STR_MULT").format(
						{"mult": int(effect.get("mult", 1))}
					)
				)

			"apply_stun":
				lines.append(tr("UI_BATTLE_DESC_APPLY_STUN").format({"n": stacks}))

			"apply_stun_all":
				lines.append(tr("UI_BATTLE_DESC_APPLY_STUN_ALL").format({"n": stacks}))

			"scale_damage_by_attacks":
				var s_base: int = int(effect.get("base", 0))
				var s_per: int = int(effect.get("per", 0))
				lines.append(
					tr("UI_BATTLE_DESC_SCALE_BY_ATTACKS").format({"base": s_base, "per": s_per})
				)

			"exhaust_self":
				# Rendered separately as a keyword tag below
				pass

			_:
				lines.append(etype.replace("_", " ").capitalize())

	# Keyword tags (Retain / Exhaust) appear on their own line, dimmer than effects.
	var keywords: PackedStringArray = []
	if bool(data.get("retain", false)):
		keywords.append(tr("UI_BATTLE_KEYWORD_RETAIN"))
	for e in effects:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "exhaust_self":
			keywords.append(tr("UI_BATTLE_KEYWORD_EXHAUST"))
			break
	if keywords.size() > 0:
		lines.append("[i]%s[/i]" % " · ".join(keywords))

	return "\n".join(lines)


## Refreshes the card UI with current live data
func update_display() -> void:
	if not is_node_ready():
		return
	if not card_info.is_empty():
		set_card_data(card_info)

	# Handle playable glow update if we can find the player
	var scene = get_tree().current_scene
	if scene and "player" in scene and is_instance_valid(scene.player):
		update_playable(scene.player.energy)


func _color_num(val: int, base_plus_stat: int) -> String:
	if val > base_plus_stat:
		return "[color=#00ff00]%d[/color]" % val  # Bright Green
	elif val < base_plus_stat:
		return "[color=#ff4444]%d[/color]" % val  # Red

	return str(val)


## Returns current player attribute values for description calculation.
## Uses live player if battle is running, otherwise defaults.
func _get_player_stats() -> Dictionary:
	var defaults = {"strength": 0, "constitution": 0, "intelligence": 0, "luck": 0, "charm": 0}
	var scene = get_tree().current_scene if get_tree() else null
	if scene and "player" in scene and is_instance_valid(scene.player):
		var p = scene.player
		return {
			"strength": int(p.get("strength") if "strength" in p else 0),
			"constitution": int(p.get("constitution") if "constitution" in p else 0),
			"intelligence": int(p.get("intelligence") if "intelligence" in p else 0),
			"luck": int(p.get("luck") if "luck" in p else 0),
			"charm": int(p.get("charm") if "charm" in p else 0),
			"double_damage":
			p.get_status_stacks("double_damage") if p.has_method("get_status_stacks") else 0,
			"outgoing_mult":
			p.status_system.get_outgoing_multiplier() if "status_system" in p else 1.0,
		}
	return defaults


# ─── UX Polish (Juice) ────────────────────────────────────────────────────────


func _on_mouse_entered() -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.15)
	z_index = 10  # bring to front

	# Keyword glossary tooltip: explain any statuses / attributes this card uses.
	var glossary := _build_keyword_glossary()
	if glossary != "":
		Tooltip.show(glossary, global_position + Vector2(size.x * 0.5, 0), get_instance_id())


func _on_mouse_exited() -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	z_index = 1
	Tooltip.hide_if_owner(get_instance_id())


## Builds a "[b]Keyword[/b]: definition" glossary for the statuses and global
## attributes this card's effects touch, sourced from the localized status rows
## (falling back to StatusEffectSystem.STATUS_DESCRIPTIONS). Empty if none apply.
func _build_keyword_glossary() -> String:
	var effects: Array = card_info.get("effects", [])
	if effects.is_empty():
		return ""
	var seen: Dictionary = {}
	var lines: PackedStringArray = []

	# Global attributes first (Strength on attacks, Constitution on block).
	var uses_str := false
	var uses_con := false
	for effect in effects:
		var etype := str(effect.get("type", ""))
		if etype in ["deal_damage", "deal_damage_all", "deal_damage_str_mult"]:
			uses_str = true
		elif etype == "gain_block":
			uses_con = true
	if uses_str:
		lines.append(
			"[b]%s[/b]: %s" % [tr("UI_COMBAT_ATTR_STRENGTH"), tr("UI_BATTLE_KEYWORD_STRENGTH_DESC")]
		)
	if uses_con:
		lines.append(
			(
				"[b]%s[/b]: %s"
				% [tr("UI_COMBAT_ATTR_CONSTITUTION"), tr("UI_BATTLE_KEYWORD_CONSTITUTION_DESC")]
			)
		)

	# Then any statuses the card applies.
	for effect in effects:
		var status := str(effect.get("status", ""))
		if status == "" or seen.has(status):
			continue
		seen[status] = true
		var up := status.to_upper()
		var kw_name := tr("UI_COMBAT_STATUS_%s" % up)
		if kw_name == "UI_COMBAT_STATUS_%s" % up:
			kw_name = STATUS_SYS.format_name(status)
		var desc := tr("UI_COMBAT_STATUS_%s_DESC" % up)
		if desc == "UI_COMBAT_STATUS_%s_DESC" % up:
			desc = str(STATUS_SYS.STATUS_DESCRIPTIONS.get(status, ""))
		if desc != "":
			lines.append("[b]%s[/b]: %s" % [kw_name, desc])

	return "\n".join(lines)


## Toggles the "can afford" glow and pulse animation.
func update_playable(current_energy: int) -> void:
	if not is_instance_valid(playable_glow):
		return

	var cost = int(card_info.get("cost", 0))
	var can_afford = current_energy >= cost

	playable_glow.visible = can_afford
	if is_instance_valid(cost_badge):
		cost_badge.modulate = Color(1, 1, 1, 1) if can_afford else Color(0.62, 0.52, 0.45, 0.86)

	if can_afford:
		if not _glow_tween or not _glow_tween.is_running():
			_start_glow_pulse()
	else:
		if _glow_tween:
			_glow_tween.kill()
		playable_glow.modulate.a = 1.0


func _start_glow_pulse() -> void:
	if _glow_tween:
		_glow_tween.kill()
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(playable_glow, "modulate:a", 0.3, 0.8).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(playable_glow, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
