extends Card
class_name PlayCard

@onready var cost_label = $FrontFace/CostCircle/CostLabel
@onready var name_label = $FrontFace/NameBanner/NameLabel
@onready var desc_label = $FrontFace/DescriptionBox/DescriptionLabel
@onready var type_label = $FrontFace/RaceBox/RaceLabel

func _ready() -> void:
	super._ready()
	if not card_info.is_empty():
		set_card_data(card_info)

func set_faces(front: Texture2D, back: Texture2D) -> void:
	$FrontFace/ArtContainer/ArtTexture.texture = front
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

	# ── Type label ───────────────────────────────────────────────────────────
	var c_type = data.get("type", "skill").to_lower()
	if c_type == "attack":
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

		match etype:
			"deal_damage":
				if scaling != "" and stat_val > 0:
					lines.append("Deal %d (%d+%s) dmg" % [total, base, scaling.capitalize()])
				else:
					lines.append("Deal %d dmg" % total)

			"deal_damage_all":
				if scaling != "" and stat_val > 0:
					lines.append("Deal %d (%d+%s) to ALL enemies" % [total, base, scaling.capitalize()])
				else:
					lines.append("Deal %d dmg to all enemies" % total)

			"gain_block":
				if scaling != "" and stat_val > 0:
					lines.append("Gain %d (%d+%s) block" % [total, base, scaling.capitalize()])
				else:
					lines.append("Gain %d block" % total)

			"gain_strength":
				if mult != 1:
					lines.append("Gain %d (%d×%s) Strength" % [total, int(mult), scaling.capitalize()])
				elif scaling != "" and stat_val > 0:
					lines.append("Gain %d (%d+%s) Strength" % [total, base, scaling.capitalize()])
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

	return "\n".join(lines)

## Returns current player attribute values for description calculation.
## Uses live player if battle is running, otherwise defaults.
func _get_player_stats() -> Dictionary:
	var defaults = { "strength": 0, "constitution": 0, "intelligence": 0, "luck": 0, "charm": 0 }
	var scene = get_tree().current_scene if get_tree() else null
	if scene and "player" in scene and is_instance_valid(scene.player):
		var p = scene.player
		return {
			"strength":     int(p.get("strength") if "strength" in p else 0),
			"constitution": int(p.get("constitution") if "constitution" in p else 0),
			"intelligence": int(p.get("intelligence") if "intelligence" in p else 0),
			"luck":         int(p.get("luck") if "luck" in p else 0),
			"charm":        int(p.get("charm") if "charm" in p else 0),
		}
	return defaults

