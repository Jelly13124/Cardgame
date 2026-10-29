extends Card
class_name PlayCard


# Preloaded so we don't depend on Godot's class_name registry being warm at parse time.
const STATUS_SYS = preload("uid://cq4eulp4ci8is")  # res://core/combat/status_effects.gd
const COMBAT_EFFECTS = preload("uid://do16of5onpg33")  # res://core/combat/combat_effects.gd
const CARD_INSTANCE = preload("uid://c50mv4hudoncd")  # res://core/combat/card_instance.gd
const CARD_DESCRIPTION = preload("uid://b4fkwjpel7452")  # res://core/content/card_description.gd
const EFFECT_CATALOG = preload("uid://880atc7mnnie")  # res://core/effects/effect_catalog.gd
const HOOK_VALUE = preload("uid://npewr2krgrm6")  # res://core/combat/hook_value.gd
const CARD_HIGHLIGHT = preload("uid://wd07lb83d87x")  # res://ui/battle/card_highlight.gd
const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd

@onready var cost_label = $FrontFace/CostCircle/CostLabel
@onready var cost_badge = $FrontFace/CostCircle
@onready var name_label = $FrontFace/NameLabel
@onready var desc_label = $FrontFace/DescriptionBox/DescriptionLabel
@onready var type_label = $FrontFace/RaceBox/RaceLabel
@onready var card_bg_texture = $FrontFace/TextureRect
@onready var generated_shell = $FrontFace/GeneratedShell
@onready var desc_box_texture = $FrontFace/DescriptionBox
@onready var type_badge_texture = $FrontFace/RaceBox
@onready var art_frame_texture = $FrontFace/ArtFrameTexture
@onready var art_bg = $FrontFace/ArtBackground
@onready var art_container = $FrontFace/ArtContainer
@onready var art_texture = $FrontFace/ArtContainer/ArtTexture

const UI_ASSET_PATH = "res://battle_scene/assets/images/cards/ui/"
const GENERATED_UI_PATH = UI_ASSET_PATH + "generated/"
const COST_BADGE_PATH = UI_ASSET_PATH + "card_cost_badge.png"
const DESC_BOX_PATH = UI_ASSET_PATH + "card_description_box.png"
const TYPE_BADGE_PATH = UI_ASSET_PATH + "card_type_badge.png"
const GENERATED_TYPE_TINT_PATH = GENERATED_UI_PATH + "card_type_tint_fill.png"
const GENERATED_CURSE_SHELL_PATH = GENERATED_UI_PATH + "card_shell_curse_unified.png"
const GENERATED_COST_POSITION := Vector2(5, 3)
const GENERATED_COST_SIZE := Vector2(35, 35)
const GENERATED_COST_FONT_SIZE := 25
const GENERATED_COST_FONT_EMBOLDEN := 0.9
const HAND_HOVER_LIFT := 80.0

## Discover candidates aren't hand cards — suppress the "can I afford it" glow.
var suppress_playable_glow: bool = false
## The combat card this node shows (core/combat/card_instance.gd); null for
## cards outside a combat (rewards, codex, discover offers).
var instance: RefCounted = null
## Playable outline (battle_scene/ui/card_highlight.gd), behind the card face.
var highlight: ColorRect
var _rarity_frames: Dictionary = {}

# Legacy fallback-frame colors. The unified generated battle face intentionally
# omits rarity decoration so profession color and card content remain dominant.
const RARITY_COLORS: Dictionary = {
	"common": Color(0.95, 0.96, 0.98),
	"uncommon": Color(0.31, 0.69, 1.0),
	"rare": Color(1.0, 0.81, 0.27),
	"curse": Color(0.62, 0.36, 0.78),
}
const GENERATED_TYPE_TEXT_COLORS: Dictionary = {
	"attack": Color("#ffd0a1"),
	"skill": Color("#8ff4f2"),
	"ability": Color("#f1e190"),
	"curse": Color("#d7a8e9"),
}
const GENERATED_TYPE_TINT_COLORS: Dictionary = {
	"attack": Color(0.78, 0.23, 0.10, 0.24),
	"skill": Color(0.06, 0.55, 0.58, 0.24),
	"ability": Color(0.58, 0.48, 0.10, 0.24),
	"curse": Color(0.45, 0.24, 0.58, 0.24),
}


func _ready() -> void:
	super._ready()
	highlight = CARD_HIGHLIGHT.new()
	$FrontFace.add_child(highlight)
	$FrontFace.move_child(highlight, 0)
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
		back_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for rarity in ["common", "uncommon", "rare"]:
		var frame_tex = load(UI_ASSET_PATH + "art_frame_%s.png" % rarity)
		if frame_tex:
			_rarity_frames[rarity] = frame_tex
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
	cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cost_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	cost_label.add_theme_constant_override("outline_size", 2)
	cost_label.add_theme_constant_override("shadow_offset_x", 0)
	cost_label.add_theme_constant_override("shadow_offset_y", 0)
	cost_label.remove_theme_font_override("font")
	cost_label.add_theme_font_size_override("font_size", 19)


func _configure_generated_skin(data: Dictionary) -> bool:
	var card_type := str(data.get("type", "skill")).to_lower()
	var is_curse := card_type == "curse"
	var skin_id := _resolve_skin_id(data)
	if skin_id == "" and not is_curse:
		return false
	var shell_path := (
		GENERATED_CURSE_SHELL_PATH
		if is_curse
		else GENERATED_UI_PATH + "card_shell_%s_unified.png" % skin_id
	)
	var shell_tex := _load_texture_fallback(shell_path)
	var type_tint_tex := _load_texture_fallback(GENERATED_TYPE_TINT_PATH)
	if shell_tex == null:
		push_warning("Generated unified card UI skin is missing: %s" % shell_path)
		return false

	generated_shell.texture = shell_tex
	generated_shell.visible = true
	generated_shell.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	generated_shell.position = Vector2.ZERO
	generated_shell.size = size
	generated_shell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	generated_shell.stretch_mode = TextureRect.STRETCH_SCALE
	card_bg_texture.visible = false
	# Cost, title, type landing, and description surface are authored into the
	# single shell. These nodes remain only as layout containers for runtime text.
	cost_badge.texture = null
	cost_badge.visible = not is_curse
	cost_label.visible = not is_curse
	desc_box_texture.texture = null
	type_badge_texture.texture = type_tint_tex
	type_badge_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	type_badge_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	type_badge_texture.stretch_mode = TextureRect.STRETCH_SCALE
	type_badge_texture.self_modulate = GENERATED_TYPE_TINT_COLORS.get(
		card_type, GENERATED_TYPE_TINT_COLORS["skill"]
	)
	art_frame_texture.visible = false
	art_bg.visible = false

	# Pixel layout measured from the unified 832x1144 shell and normalized to the
	# factory's canonical 208x286 card size.
	# Overscan the illustration beneath the opaque rail. The unified shell draws
	# above it and becomes the visual crop, so curved aperture edges never expose
	# an empty strip when 512x320 art is aspect-covered.
	art_container.position = Vector2(15, 38)
	art_container.size = Vector2(180, 123)
	# The display font's CJK fallback sits visually low inside a centered Label.
	# Lift the shared title baseline by two pixels so both profession and curse
	# titles land on the optical center of their authored banner.
	name_label.position = Vector2(15, 8) if is_curse else Vector2(42, 8)
	name_label.size = Vector2(180, 31) if is_curse else Vector2(152, 31)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_box_texture.position = Vector2(16, 166)
	desc_box_texture.size = Vector2(181, 108)
	desc_label.position = Vector2(8, 8)
	desc_label.size = Vector2(165, 92)
	type_badge_texture.position = Vector2(62, 156)
	type_badge_texture.size = Vector2(84, 20)
	cost_badge.position = GENERATED_COST_POSITION
	cost_badge.size = GENERATED_COST_SIZE
	cost_label.position = Vector2.ZERO
	cost_label.size = cost_badge.size

	# Chinese uses the bundled Noto fallback, whose only face is Regular. Apply a
	# small glyph embolden here so card text keeps the intended hierarchy instead
	# of becoming thin and soft after hand rotation.
	var generated_title_font := T.display_font(700)
	generated_title_font.variation_embolden = 0.58
	# Use Noto directly for the compact CJK type tag. Going through the Latin
	# display font's fallback gives the two-character label awkward line metrics.
	var generated_type_font := FontVariation.new()
	generated_type_font.base_font = T.CJK_FALLBACK
	generated_type_font.variation_embolden = 0.72
	var generated_description_font := T.display_font(600)
	generated_description_font.variation_embolden = 0.22
	name_label.add_theme_font_override("font", generated_title_font)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override(
		"font_color", Color("#e9e0ef") if is_curse else Color("#171613")
	)
	name_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	type_label.add_theme_font_override("font", generated_type_font)
	type_label.add_theme_font_size_override("font_size", 13)
	type_label.add_theme_color_override("font_color", Color.WHITE)
	type_label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	type_label.add_theme_constant_override("outline_size", 0)
	type_label.add_theme_constant_override("font_spacing_glyph", -1)
	type_label.modulate = GENERATED_TYPE_TEXT_COLORS.get(
		card_type, GENERATED_TYPE_TEXT_COLORS["skill"]
	)
	desc_label.add_theme_font_override("normal_font", generated_description_font)
	desc_label.add_theme_font_size_override("normal_font_size", 14)
	desc_label.add_theme_color_override(
		"default_color", Color("#d8ccdf") if is_curse else Color("#f0d4a1")
	)
	desc_label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	desc_label.add_theme_constant_override("outline_size", 0)
	desc_label.add_theme_constant_override("line_separation", 1)
	# Keep the compact serif numeral from the approved concept, but embolden the
	# actual glyph so the cost stays dominant after cards shrink into the hand.
	# Kreon's useful weight range tops out below the former 800 request, which
	# made the rendered numeral look thinner than intended.
	var generated_cost_font := T.display_font(700)
	generated_cost_font.variation_embolden = GENERATED_COST_FONT_EMBOLDEN
	cost_label.add_theme_font_override("font", generated_cost_font)
	cost_label.add_theme_font_size_override("font_size", GENERATED_COST_FONT_SIZE)
	cost_label.add_theme_color_override("font_color", Color("#241711"))
	cost_label.add_theme_color_override("font_outline_color", Color("#f7dfaa"))
	cost_label.add_theme_constant_override("outline_size", 1)
	return true


## Card colors belong to the active profession, not the individual card. A card
## may explicitly override the skin for a special case, but shared cards inherit
## the hero's `card_ui_skin`, so future professions can own distinct palettes.
func _resolve_skin_id(data: Dictionary) -> String:
	var override_id := str(data.get("ui_skin", "")).strip_edges()
	if override_id != "":
		return override_id
	if RunManager and typeof(RunManager.current_hero_data) == TYPE_DICTIONARY:
		var current := str(RunManager.current_hero_data.get("card_ui_skin", "")).strip_edges()
		if current != "":
			return current
	var hero_id := str(RunManager.current_hero_id).strip_edges() if RunManager else ""
	if hero_id == "":
		return ""
	return str(MODEL_DB.data("character", hero_id).get("card_ui_skin", "")).strip_edges()


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

	if highlight and highlight.is_shown():
		highlight.anim_flash()
	if requires_enemy_target() and not _targeted_card_should_drag(main):
		# Start targeting mode — arrow follows mouse while button is held.
		# Do NOT call super so the card does not enter HOLDING/drag state.
		if main and main.has_method("start_spell_targeting"):
			main.start_spell_targeting(self)
	else:
		# Untargeted card — OR targeted card with only one valid enemy — uses the
		# drag-up-into-CardPlayZone flow. card_play_zone.move_cards picks the
		# sole enemy automatically when the dropped card needs a target.
		super._handle_mouse_pressed()


## Called when the player RELEASES the left mouse button.
## For targeted cards in targeting mode, release confirms/cancels the play.
func _handle_mouse_released() -> void:
	var main = get_tree().current_scene

	if (
		requires_enemy_target()
		and not _targeted_card_should_drag(main)
		and main
		and main.has_method("confirm_spell_targeting")
	):
		main.confirm_spell_targeting(self)
		return  # Do NOT call super — card stays in hand until attack fires
	# Fall through to super so the drag path (skills, or attacks-with-sole-enemy)
	# resolves its drop normally.
	super._handle_mouse_released()


## A targeted card uses drag-into-play-zone (rather than aim-arrow) when there's only
## one valid enemy — no choice to make, so the play-zone gesture matches the
## skill flow and saves the arrow ceremony.
func _targeted_card_should_drag(main) -> bool:
	if not main or not main.has_method("sole_alive_enemy"):
		return false
	return main.sole_alive_enemy() != null


## Targeting is data-driven rather than coupled to the card's visual type.
## `target` may explicitly override inference for future content.
static func data_requires_enemy_target(data: Dictionary) -> bool:
	return CARD_INSTANCE.data_requires_enemy_target(data)


func requires_enemy_target() -> bool:
	return data_requires_enemy_target(card_info)


func set_card_data(data: Dictionary) -> void:
	if not is_instance_valid(self):
		return

	card_info = data
	card_name = str(data.get("id", "Unknown"))

	# ── Cost: always integer ──────────────────────────────────────────────────
	# cost_override (this-combat discover) wins over the card's base cost.
	var shown_cost: int = int(data.get("cost", 0))
	if instance != null:
		shown_cost = instance.cost()
	cost_label.text = str(shown_cost)
	_style_cost_label()

	# ── Name (CONTENT) ───────────────────────────────────────────────────────
	# Title comes from card data — route through Settings.t with the card's
	# deterministic content key (CARD_<id>_TITLE), English fallback.
	var card_id: String = str(data.get("id", card_name))
	name_label.text = (
		Settings.t("CARD_%s_TITLE" % MODEL_ID.key_entry(card_id), str(data.get("title", card_name))).to_upper()
	)

	# Generated skins are authored PNG components. Legacy cards keep the previous
	# texture stack until their own rarity/profession assets are delivered.
	var uses_generated_skin := _configure_generated_skin(data)
	if highlight:
		var silhouette: Texture2D = (
			generated_shell.texture
			if uses_generated_skin and generated_shell.texture
			else card_bg_texture.texture
		)
		highlight.set_source(silhouette, size)

	# ── Description: build from effects[] showing real calculated numbers ────
	var desc = _build_description(data)
	if uses_generated_skin:
		desc_label.parse_bbcode("[center]" + _colorize_keywords(desc) + "[/center]")
		call_deferred("_fit_and_center_description")
	else:
		desc_label.parse_bbcode(
			"[center][font_size=13]" + _colorize_keywords(desc) + "[/font_size][/center]"
		)

	# Only legacy cards keep the previous rarity frame. The unified generated
	# battle face omits a rarity marker to preserve the single-frame hierarchy.
	if not uses_generated_skin:
		var rarity = data.get("rarity", "common").to_lower()
		if rarity in _rarity_frames:
			art_frame_texture.texture = _rarity_frames[rarity]
		else:
			art_frame_texture.texture = _rarity_frames.get("common")
		art_frame_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		art_frame_texture.modulate = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])

	# ── Type label ────────────────────────────────────────────────────────────
	# Source art stays rectangular, while the generated shell is rendered above it
	# and supplies the authored chamfered aperture and inner border.
	var c_type = data.get("type", "skill").to_lower()
	var is_atk = c_type == "attack"

	if is_atk:
		type_label.text = tr("UI_BATTLE_CARD_TYPE_ATTACK")
		if not uses_generated_skin:
			type_label.modulate = Color(1, 0.4, 0.4)
	elif c_type == "skill":
		type_label.text = tr("UI_BATTLE_CARD_TYPE_SKILL")
		if not uses_generated_skin:
			type_label.modulate = Color(0.4, 0.8, 1.0)
	elif c_type == "ability":
		type_label.text = tr("UI_BATTLE_CARD_TYPE_ABILITY")
		if not uses_generated_skin:
			type_label.modulate = Color(0.8, 0.4, 1.0)
	elif c_type == "curse":
		type_label.text = tr("UI_BATTLE_CARD_TYPE_CURSE")
		if not uses_generated_skin:
			type_label.modulate = Color(0.7, 0.45, 0.85)
	else:
		type_label.text = c_type.to_upper()
	if uses_generated_skin:
		type_label.modulate = GENERATED_TYPE_TEXT_COLORS.get(
			c_type, GENERATED_TYPE_TEXT_COLORS["skill"]
		)
		type_badge_texture.self_modulate = GENERATED_TYPE_TINT_COLORS.get(
			c_type, GENERATED_TYPE_TINT_COLORS["skill"]
		)


## Keep short copy at the approved size; only long cards step down until they
## fit. The tiny integrated type notch occupies the top seam, so center copy in
## the uninterrupted recessed field beneath it.
func _fit_and_center_description() -> void:
	if not is_instance_valid(desc_label) or not is_instance_valid(desc_box_texture):
		return
	var available_width: float = 165.0
	var top_clearance: float = 8.0
	var bottom_clearance: float = 8.0
	var available_height: float = (
		desc_box_texture.size.y - top_clearance - bottom_clearance
	)
	desc_label.position = Vector2(8, top_clearance)
	desc_label.size = Vector2(available_width, available_height)
	for font_size in range(14, 11, -1):
		desc_label.add_theme_font_size_override("normal_font_size", font_size)
		desc_label.size = Vector2(available_width, available_height)
		if desc_label.get_content_height() <= available_height:
			break
	var content_height := clampf(desc_label.get_content_height(), 18.0, available_height)
	desc_label.position.y = top_clearance + (available_height - content_height) * 0.5
	desc_label.size.y = content_height


## Card text from the one description generator (battle_scene/card_description.gd)
## with this card's live view: player stats, battle preview values, relic replays.
func _build_description(data: Dictionary) -> String:
	var view := {"stats": _get_player_stats(), "pipeline": {}, "replay_bonus": 0}
	var scene = get_tree().current_scene if is_inside_tree() else null
	var combat = scene.get("combat") if scene else null
	if combat != null and combat.combat_commands != null:
		var subject = instance if instance != null else self
		view["pipeline"] = COMBAT_EFFECTS.preview_effect_values(combat, subject, data.get("effects", []))
		view["replay_bonus"] = int(combat.combat_hooks.compute("modify_attack_replays", HOOK_VALUE.make(0)))
	return CARD_DESCRIPTION.build(data, view)


## Refreshes the card UI with current live data
func update_display() -> void:
	if not is_node_ready():
		return
	if not card_info.is_empty():
		set_card_data(card_info)

	update_playable()


func _colorize_keywords(text: String) -> String:
	return CARD_DESCRIPTION.colorize(text)


## Returns current player attribute values for description calculation.
## Uses live player if battle is running, otherwise defaults.
func _get_player_stats() -> Dictionary:
	var defaults = {"strength": 0, "constitution": 0, "intelligence": 0, "luck": 0, "charm": 0}
	var scene = get_tree().current_scene if is_inside_tree() else null
	if scene and "player" in scene and is_instance_valid(scene.player):
		var p = scene.player
		return {
			"strength": int(p.get("strength") if "strength" in p else 0),
			"constitution": int(p.get("constitution") if "constitution" in p else 0),
			"intelligence": int(p.get("intelligence") if "intelligence" in p else 0),
			"luck": int(p.get("luck") if "luck" in p else 0),
			"charm": int(p.get("charm") if "charm" in p else 0),
		}
	return defaults


# ─── UX Polish (Juice) ────────────────────────────────────────────────────────


func _on_mouse_entered() -> void:
	# Keyword glossary tooltip: explain any statuses / attributes this card uses.
	var glossary := _build_keyword_glossary()
	if glossary != "":
		var tooltip_lift := HAND_HOVER_LIFT if card_container is Hand else 12.0
		Tooltip.show(
			glossary,
			global_position + Vector2(size.x * 0.5, -tooltip_lift),
			get_instance_id()
		)


func _on_mouse_exited() -> void:
	Tooltip.hide_if_owner(get_instance_id())


## Hand cards remain fully visible at rest; focus adds only a clear StS-style
## lift and straightens the card. Non-hand previews keep a restrained hover so
## deck/reward layouts do not jump.
func _start_hover_animation() -> void:
	var is_hand_card := card_container is Hand
	hover_distance = int(HAND_HOVER_LIFT) if is_hand_card else 12
	hover_scale = 1.12 if is_hand_card else 1.06
	hover_rotation = 0.0
	super._start_hover_animation()


## Builds a "[b]Keyword[/b]: definition" glossary for the statuses and global
## attributes this card's effects touch, sourced from the localized status rows
## (falling back to the status definition's description). Empty if none apply.
func _build_keyword_glossary() -> String:
	return CARD_DESCRIPTION.glossary(card_info)


## Playability cue (STS2): in battle, a hand card that can be played right now
## keeps a shape-hugging outline; the cost disc dims when energy is short.
## Outside battle, and for discover candidates, there is no outline.
func update_playable() -> void:
	var scene = get_tree().current_scene if is_inside_tree() else null
	var in_battle: bool = scene != null and scene.has_method("can_play_card")
	if is_instance_valid(cost_badge):
		var cost := int(cost_label.text) if is_instance_valid(cost_label) else int(card_info.get("cost", 0))
		var energy: int = int(scene.player.energy) if in_battle and is_instance_valid(scene.player) else cost
		cost_badge.modulate = Color.WHITE if energy >= cost else Color(0.58, 0.58, 0.54, 0.82)
	if not highlight:
		return
	if in_battle and not suppress_playable_glow and scene.can_play_card(self):
		highlight.anim_show()
	else:
		highlight.anim_hide()
