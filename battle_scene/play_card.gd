extends Card
class_name PlayCard

@onready var cost_label = $FrontFace/CostCircle/CostLabel
@onready var name_label = $FrontFace/NameLabel
@onready var desc_label = $FrontFace/DescriptionBox/DescriptionLabel
@onready var type_label = $FrontFace/RaceBox/RaceLabel
@onready var card_bg_texture   = $FrontFace/TextureRect
@onready var playable_glow     = $FrontFace/PlayableGlow
@onready var art_frame_texture = $FrontFace/ArtFrameTexture
@onready var art_bg            = $FrontFace/ArtBackground
@onready var art_texture       = $FrontFace/ArtContainer/ArtTexture

const MASK_SHADER = preload("res://battle_scene/card_art_mask.gdshader")
const UI_ASSET_PATH = "res://battle_scene/assets/images/cards/ui/"

var _hover_tween: Tween
var _glow_tween: Tween

const RARITY_COLORS = {
	"common":   { "border": Color("#c8a258"), "inner": Color("#2a2e31") },
	"uncommon": { "border": Color("#4d9eff"), "inner": Color("#1b324d") },
	"rare":     { "border": Color("#ffd700"), "inner": Color("#4d4200") }
}

var _mask_material: ShaderMaterial = null
var _rarity_frames: Dictionary = {}

func _ready() -> void:
	super._ready()
	# Load the pixel art card background (front)
	var bg = load(UI_ASSET_PATH + "card_bg.png")
	if bg and is_instance_valid(card_bg_texture):
		card_bg_texture.texture = bg
	# Load pixel art card back — shown when card is face-down (draw/discard piles)
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
	
	pivot_offset = size / 2.0 # Ensure we scale from center

func set_faces(front: Texture2D, back: Texture2D) -> void:
	art_texture.texture = front
	$BackFace/TextureRect.texture = back

## Called when the player PRESSES the left mouse button on this card.
func _handle_mouse_pressed() -> void:
	var main = get_tree().current_scene
	var c_type = card_info.get("type", "skill").to_lower()

	if c_type == "attack":
		# Start targeting mode — arrow follows mouse while button is held.
		# Do NOT call super so the card does not enter HOLDING/drag state.
		if main and main.has_method("start_spell_targeting"):
			main.start_spell_targeting(self)
	else:
		# Skill/Ability cards are dragged up into the CardPlayZone normally.
		super._handle_mouse_pressed()

## Called when the player RELEASES the left mouse button.
## For attack cards in targeting mode, release confirms/cancels the attack.
func _handle_mouse_released() -> void:
	var main = get_tree().current_scene
	var c_type = card_info.get("type", "skill").to_lower()

	if c_type == "attack" and main and main.has_method("confirm_spell_targeting"):
		main.confirm_spell_targeting(self)
		return  # Do NOT call super — card stays in hand until attack fires

	super._handle_mouse_released()

func set_card_data(data: Dictionary) -> void:
	if not is_instance_valid(self): return

	card_info = data
	card_name = data.get("name", "Unknown")

	# ── Cost: always integer ──────────────────────────────────────────────────
	cost_label.text = str(int(data.get("cost", 0)))

	# ── Name ─────────────────────────────────────────────────────────────────
	name_label.text = data.get("title", card_name).to_upper()

	# ── Description: build from effects[] showing real calculated numbers ────
	var desc = _build_description(data)
	desc_label.parse_bbcode("[center]" + desc + "[/center]")

	# ── Rarity: swap the art FRAME texture ───────────────────────────────────
	var rarity = data.get("rarity", "common").to_lower()
	if rarity in _rarity_frames:
		art_frame_texture.texture = _rarity_frames[rarity]
	else:
		art_frame_texture.texture = _rarity_frames.get("common")

	# ── Type & Shape ──────────────────────────────────────────────────────────
	var c_type = data.get("type", "skill").to_lower()
	var is_atk = (c_type == "attack")

	# Apply/Update Shader Mask to ArtTexture only
	if _mask_material == null:
		_mask_material = ShaderMaterial.new()
		_mask_material.shader = MASK_SHADER
		art_texture.material = _mask_material
	
	_mask_material.set_shader_parameter("is_attack", is_atk)

	if is_atk:
		type_label.text = "ATTACK"
		type_label.modulate = Color(1, 0.4, 0.4)
	elif c_type == "skill":
		type_label.text = "SKILL"
		type_label.modulate = Color(0.4, 0.8, 1.0)
	elif c_type == "ability":
		type_label.text = "ABILITY"
		type_label.modulate = Color(0.8, 0.4, 1.0)
	else:
		type_label.text = c_type.to_upper()

## Build a plain-text description from the effects[] array.
## Shows calculated totals e.g. "Deal 6 (3+Strength) dmg" when player has 3 STR.
## Falls back to the raw "description" field if no effects array exists.
func _build_description(data: Dictionary) -> String:
	var effects: Array = data.get("effects", [])
	if effects.is_empty():
		# Strip BBCode tags from the raw description
		var raw: String = data.get("description", "")
		return raw.replace("[b]", "").replace("[/b]", "").replace("[i]", "").replace("[/i]", "").replace("[center]", "").replace("[/center]", "")

	# Get current player stats for display (live values if battle is running)
	var stats = _get_player_stats()

	var lines: PackedStringArray = []
	for effect in effects:
		var etype: String  = effect.get("type", "")
		var base: int      = int(effect.get("amount", 0))
		var scaling: String = effect.get("scaling", "")
		var mult: float    = float(effect.get("multiplier", 1))
		var stacks: int    = int(effect.get("stacks", 1))

		var stat_val: int = 0
		if scaling != "":
			stat_val = int(stats.get(scaling, 0))

		var total: int = base + stat_val
		if mult != 1:
			total = int(total * mult)
			
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
				if scaling != "" and stat_val > 0:
					lines.append("Deal %s ([i]%d+[color=#8b0000]%d[/color][/i]) dmg" % [label_val, base, stat_val])
				else:
					lines.append("Deal %s dmg" % label_val)

			"deal_damage_all":
				var label_val = _color_num(final_damage, total)
				if scaling != "" and stat_val > 0:
					lines.append("Deal %s ([i]%d+[color=#8b0000]%d[/color][/i]) to ALL enemies" % [label_val, base, stat_val])
				else:
					lines.append("Deal %s dmg to all enemies" % label_val)

			"gain_block":
				var label_val = _color_num(final_block, total)
				if scaling != "" and stat_val > 0:
					lines.append("Gain %s ([i]%d+[color=#4444ff]%d[/color][/i]) block" % [label_val, base, stat_val])
				else:
					lines.append("Gain %s block" % label_val)

			"gain_strength":
				if mult != 1:
					lines.append("Gain %d (%d×%s) Strength" % [total, int(mult), scaling.capitalize()])
				elif scaling != "" and stat_val > 0:
					lines.append("Gain %d (%d+[color=#8b0000]%d[/color]) Strength" % [total, base, stat_val])
				else:
					lines.append("Gain %d Strength" % total)

			"gain_constitution":
				lines.append("Gain %d Constitution" % total)

			"gain_intelligence":
				lines.append("Gain %d Intelligence" % total)

			"gain_luck":
				lines.append("Gain %d Luck" % total)

			"gain_energy":
				lines.append("Gain %d Energy" % total)

			"draw_cards":
				lines.append("Draw %d card%s" % [base, "s" if base != 1 else ""])

			"apply_status":
				lines.append("Apply %s ×%d" % [effect.get("status", "").capitalize(), stacks])

			"apply_status_all":
				lines.append("Apply %s ×%d to all enemies" % [effect.get("status", "").capitalize(), stacks])

			"apply_status_self":
				lines.append("Apply %s ×%d to self" % [effect.get("status", "").capitalize(), stacks])

			_:
				lines.append(etype.replace("_", " ").capitalize())

	return "[font_size=11]" + "\n".join(lines) + "[/font_size]"

## Refreshes the card UI with current live data
## Refreshes the card UI with current live data
func update_display() -> void:
	if not is_node_ready(): return
	if not card_info.is_empty():
		set_card_data(card_info)
	
	# Handle playable glow update if we can find the player
	var scene = get_tree().current_scene
	if scene and "player" in scene and is_instance_valid(scene.player):
		update_playable(scene.player.energy)

func _color_num(val: int, base_plus_stat: int) -> String:
	if val > base_plus_stat:
		return "[color=#00ff00]%d[/color]" % val # Bright Green
	elif val < base_plus_stat:
		return "[color=#ff4444]%d[/color]" % val # Red
	
	return str(val)

## Returns current player attribute values for description calculation.
## Uses live player if battle is running, otherwise defaults.
func _get_player_stats() -> Dictionary:
	var defaults = { "strength": 0, "constitution": 0, "intelligence": 0, "luck": 0, "charm": 0 }
	var scene = get_tree().current_scene if get_tree() else null
	if scene and "player" in scene and is_instance_valid(scene.player):
		var p = scene.player
		return {
			"strength":      int(p.get("strength") if "strength" in p else 0),
			"constitution":  int(p.get("constitution") if "constitution" in p else 0),
			"intelligence":  int(p.get("intelligence") if "intelligence" in p else 0),
			"luck":          int(p.get("luck") if "luck" in p else 0),
			"charm":         int(p.get("charm") if "charm" in p else 0),
			"double_damage": p.get_status_stacks("double_damage") if p.has_method("get_status_stacks") else 0,
			"outgoing_mult": p.status_system.get_outgoing_multiplier() if "status_system" in p else 1.0,
		}
	return defaults

# ─── UX Polish (Juice) ────────────────────────────────────────────────────────

func _on_mouse_entered() -> void:
	if _hover_tween: _hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.15)
	z_index = 10 # bring to front

func _on_mouse_exited() -> void:
	if _hover_tween: _hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	z_index = 1

## Toggles the "can afford" glow and pulse animation.
func update_playable(current_energy: int) -> void:
	if not is_instance_valid(playable_glow): return
	
	var cost = int(card_info.get("cost", 0))
	var can_afford = current_energy >= cost
	
	playable_glow.visible = can_afford
	
	if can_afford:
		if not _glow_tween or not _glow_tween.is_running():
			_start_glow_pulse()
	else:
		if _glow_tween:
			_glow_tween.kill()
		playable_glow.modulate.a = 1.0

func _start_glow_pulse() -> void:
	if _glow_tween: _glow_tween.kill()
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(playable_glow, "modulate:a", 0.3, 0.8).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(playable_glow, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
