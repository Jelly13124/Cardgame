## Unit Card UI - Hearthstone-style card extending the base Card class.
## Displays: Mana cost (top-left), Art, Name banner, Description, Attack/Health circles
## Supports "Token" view mode for the battlefield.
class_name UnitCard
extends Card

# --- UI Element references (Full Card) ---
var cost_label: Label
var name_label: Label
var attack_label: Label
var health_label: Label
var description_label: RichTextLabel
var art_texture: TextureRect

# --- UI Element references (Token) ---
var token_attack_label: Label
var token_health_label: Label
var token_art_texture: TextureRect
var token_oval_border: Panel

# View mode: "card" or "token"
var current_view_mode: String = "card"

# Combat state
var health: int = 0
var attack: int = 0
var keyword_instances: Array = []


func _ready() -> void:
	# Get UI element references for full card
	cost_label = $FrontFace/CostCircle/CostLabel if has_node("FrontFace/CostCircle/CostLabel") else null
	name_label = $FrontFace/NameBanner/NameLabel if has_node("FrontFace/NameBanner/NameLabel") else null
	attack_label = $FrontFace/AttackCircle/AttackLabel if has_node("FrontFace/AttackCircle/AttackLabel") else null
	health_label = $FrontFace/HealthCircle/HealthLabel if has_node("FrontFace/HealthCircle/HealthLabel") else null
	description_label = $FrontFace/DescriptionBox/DescriptionLabel if has_node("FrontFace/DescriptionBox/DescriptionLabel") else null
	art_texture = $FrontFace/ArtContainer/ArtTexture if has_node("FrontFace/ArtContainer/ArtTexture") else null
	
	# Get UI element references for token
	token_attack_label = $TokenFace/AttackCircle/AttackLabel if has_node("TokenFace/AttackCircle/AttackLabel") else null
	token_health_label = $TokenFace/HealthCircle/HealthLabel if has_node("TokenFace/HealthCircle/HealthLabel") else null
	token_art_texture = $TokenFace/ArtContainer/ArtTexture if has_node("TokenFace/ArtContainer/ArtTexture") else null
	token_oval_border = $TokenFace/OvalBorder if has_node("TokenFace/OvalBorder") else null
	
	# Call parent _ready which handles basic texture setup
	super._ready()
	
	# Connect to input signal for debug killing (don't override _gui_input which breaks inheritance)
	connect("gui_input", _on_unit_gui_input)
	
	# Populate UI from card_info if available
	_update_card_ui()
	_load_keywords()
	set_view_mode("card") # Default to card view


## Sets whether the card displays as a full card or a unit token
func set_view_mode(mode: String) -> void:
	current_view_mode = mode
	if has_node("FrontFace"):
		$FrontFace.visible = (mode == "card")
	if has_node("TokenFace"):
		$TokenFace.visible = (mode == "token")
	
	# If we are in token mode, we usually don't want the backing to show if flipping
	if mode == "token":
		show_front = true


## Updates all UI elements from card_info dictionary
func _update_card_ui() -> void:
	if card_info.is_empty():
		return
	
	# 1. Sync Full Card UI
	var is_player = card_info.get("side", "player") == "player"
	
	if cost_label:
		if card_info.has("cost") and is_player:
			cost_label.text = str(int(card_info.get("cost", 0)))
			if has_node("FrontFace/CostCircle"):
				$FrontFace/CostCircle.visible = true
		else:
			if has_node("FrontFace/CostCircle"):
				$FrontFace/CostCircle.visible = false
	
	if name_label:
		var display_name = card_info.get("display_name", card_info.get("name", "UNIT"))
		name_label.text = display_name.to_upper()
	
	var is_spell = card_info.get("type", "unit") == "spell"
	
	if attack_label:
		if is_spell:
			if has_node("FrontFace/AttackCircle"):
				$FrontFace/AttackCircle.visible = false
		elif card_info.has("attack"):
			var attack_val = int(card_info.get("attack", 0))
			attack_label.text = str(attack_val)
			if has_node("FrontFace/AttackCircle"):
				$FrontFace/AttackCircle.visible = true # Changed from attack_val > 0 to allow 0-attack units
	
	if health_label:
		if is_spell:
			if has_node("FrontFace/HealthCircle"):
				$FrontFace/HealthCircle.visible = false
		elif card_info.has("health"):
			var health_val = int(card_info.get("health", 0))
			health_label.text = str(health_val)
			if has_node("FrontFace/HealthCircle"):
				$FrontFace/HealthCircle.visible = true
	
	if description_label and card_info.has("description"):
		description_label.text = card_info.get("description", "")
	
	# Art background colors logic
	if has_node("FrontFace/ArtBackground"):
		var type = card_info.get("type", "unit")
		match type:
			"hero": $FrontFace/ArtBackground.color = Color(0.6, 0.4, 0.1)
			"spell": $FrontFace/ArtBackground.color = Color(0.2, 0.3, 0.6)
			"building": $FrontFace/ArtBackground.color = Color(0.4, 0.3, 0.2)
			_: $FrontFace/ArtBackground.color = Color(0.4, 0.45, 0.5)

	# 2. Sync Token UI
	if is_spell:
		if has_node("TokenFace/AttackCircle"):
			$TokenFace/AttackCircle.visible = false
		if has_node("TokenFace/HealthCircle"):
			$TokenFace/HealthCircle.visible = false
	else:
		if token_attack_label and card_info.has("attack"):
			attack = int(card_info.get("attack", 0))
			token_attack_label.text = str(attack)
			if has_node("TokenFace/AttackCircle"):
				$TokenFace/AttackCircle.visible = true
		
		if token_health_label and card_info.has("health"):
			health = int(card_info.get("health", 0))
			token_health_label.text = str(health)
			if has_node("TokenFace/HealthCircle"):
				$TokenFace/HealthCircle.visible = true
		
	# 3. Update Faction Visuals (Oval Color)
	if token_oval_border:
		var faction_color = Color(0.2, 0.4, 1.0) # Player Blue
		if not is_player:
			faction_color = Color(1.0, 0.2, 0.2) # Enemy Red
			
		# We must duplicate the stylebox so we don't change it for all cards
		var style = token_oval_border.get_theme_stylebox("panel").duplicate()
		if style is StyleBoxFlat:
			style.border_color = faction_color
			# Make it a real blue/red oval
			style.bg_color = faction_color
			style.bg_color.a = 0.4
			token_oval_border.add_theme_stylebox_override("panel", style)

func take_damage(amount: int) -> void:
	# Filter damage through keywords (e.g., Shield)
	var final_damage = amount
	for keyword in keyword_instances:
		final_damage = keyword.on_damage_taken(final_damage)
	
	health -= final_damage
	# Update card_info so it's persistent if moved
	card_info["health"] = float(health)
	_update_card_ui()
	
	# Visual Feedback: Flash Red
	modulate = Color(1, 0.2, 0.2)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	
	if health <= 0:
		var main = get_tree().current_scene
		if main and main.has_method("kill_unit"):
			main.kill_unit(self)


## Sets textures for the card faces and the UI art containers
func set_faces(front_face: Texture2D, back_face: Texture2D) -> void:
	# Standard background for face-down pile view
	if back_face_texture:
		back_face_texture.texture = back_face
	
	# We hide the default front texture node as we use custom UI nodes
	if front_face_texture:
		front_face_texture.visible = false
	
	# Set art for both Card and Token views
	if art_texture:
		art_texture.texture = front_face
	if token_art_texture:
		token_art_texture.texture = front_face

func _load_keywords() -> void:
	keyword_instances.clear()
	var kw_list = card_info.get("keywords", [])
	for kw_name in kw_list:
		var script_path = "res://battle_scene/units/keywords/%s.gd" % kw_name.to_lower()
		if FileAccess.file_exists(script_path):
			var kw_script = load(script_path)
			if kw_script:
				var kw_instance = kw_script.new()
				kw_instance.setup(self)
				keyword_instances.append(kw_instance)
		else:
			push_warning("Keyword script not found: %s" % script_path)

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	var main = get_tree().current_scene
	if main and main.has_method("show_notification"):
		main.show_notification(text, color)


## Refreshes UI after external data changes
func refresh_ui() -> void:
	_update_card_ui()


func _handle_mouse_pressed() -> void:
	# Disable dragging if the unit is already on the battlefield (in a BattleRow)
	if card_container.is_in_group("battle_row"):
		return
	
	# --- SPELL TARGETING OVERRIDE ---
	# Spell cards should NOT be dragged. They use click-to-cast or arrow targeting.
	# We support both Click-Click and Hold-Drag (via BattleScene logic)
	if card_info.get("type", "") == "spell" and card_container.name == "Hand":
		var main = get_tree().current_scene
		if main == null:
			return
		
		# Check energy first
		if main.has_method("can_afford") and not main.can_afford([self]):
			if main.has_method("show_notification"):
				main.show_notification("NOT ENOUGH ENERGY", Color(0.2, 0.6, 1))
			return
		
		# Check if the spell REQUIRES targeting (Arrow System)
		var needs_target = card_info.get("needs_target", false)
		
		if needs_target:
			# Targeted spells: Override drag and use Arrow System
			if main.has_method("start_spell_targeting"):
				main.start_spell_targeting(self)
			return
		else:
			# Untargeted spells (Global): Allow normal drag-and-drop
			# Do nothing here, let super() handle the drag
			pass
	
	# Proceed with normal card dragging (from hand/deck/field)
	super._handle_mouse_pressed()

func is_player_unit() -> bool:
	return card_info.get("side", "player") == "player"

func _on_unit_gui_input(event: InputEvent) -> void:
	# Right-click a unit on the field to "kill" it (Debug)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var main = get_tree().current_scene
		if main and main.has_method("kill_unit") and card_container.is_in_group("battle_row"):
			main.kill_unit(self)
