## Unit Card UI - Hearthstone-style card extending the base Card class.
## Displays: Mana cost (top-left), Art, Name banner, Description, Attack/Health circles
## Supports "Token" view mode for the battlefield.
class_name UnitCard
extends Card

# --- UI Element references (Full Card) ---
@export_group("Full Card UI Nodes")
@export var cost_label: Label
@export var name_label: Label
@export var attack_label: Label
@export var health_label: Label
@export var description_label: RichTextLabel
@export var race_label: Label
@export var art_texture: TextureRect
@export var dupe_badge: ColorRect
@export var dupe_label: Label
@export var front_cost_circle: Control
@export var front_attack_circle: Control
@export var front_health_circle: Control
@export var front_race_box: Control
@export var front_art_background: ColorRect
@export var front_card_border: ColorRect
@export var front_name_banner: ColorRect

# --- UI Element references (Token) ---
@export_group("Token UI Nodes")
@export var token_attack_label: Label
@export var token_health_label: Label
@export var token_art_texture: TextureRect
@export var token_oval_border: Panel
@export var token_shield_aura: Panel
@export var token_attack_circle: Control
@export var token_health_circle: Control

# View mode: "card" or "token"
var current_view_mode: String = "card"

enum CardType { UNIT, SPELL, HERO }

# Combat state
var base_health: int = -1
var base_attack: int = -1
var health: int = -1
var attack: int = -1
var can_attack: bool = false
var keyword_instances: Array = []
var custom_script_instance: Node = null


func _get_card_type() -> CardType:
	var t = str(card_info.get("type", "unit")).to_lower()
	match t:
		"spell": return CardType.SPELL
		"hero": return CardType.HERO
		_: return CardType.UNIT

func _ready() -> void:
	# Fallback to string paths if not exported in inspector
	if not cost_label: cost_label = get_node_or_null("FrontFace/CostCircle/CostLabel")
	if not name_label: name_label = get_node_or_null("FrontFace/NameBanner/NameLabel")
	if not attack_label: attack_label = get_node_or_null("FrontFace/AttackCircle/AttackLabel")
	if not health_label: health_label = get_node_or_null("FrontFace/HealthCircle/HealthLabel")
	if not description_label: description_label = get_node_or_null("FrontFace/DescriptionBox/DescriptionLabel")
	if not race_label: race_label = get_node_or_null("FrontFace/RaceBox/RaceLabel")
	if not art_texture: art_texture = get_node_or_null("FrontFace/ArtContainer/ArtTexture")
	if not dupe_badge: dupe_badge = get_node_or_null("FrontFace/DupeBadge")
	if not dupe_label: dupe_label = get_node_or_null("FrontFace/DupeBadge/DupeLabel")
	
	if not front_cost_circle: front_cost_circle = get_node_or_null("FrontFace/CostCircle")
	if not front_attack_circle: front_attack_circle = get_node_or_null("FrontFace/AttackCircle")
	if not front_health_circle: front_health_circle = get_node_or_null("FrontFace/HealthCircle")
	if not front_race_box: front_race_box = get_node_or_null("FrontFace/RaceBox")
	if not front_art_background: front_art_background = get_node_or_null("FrontFace/ArtBackground")
	if not front_card_border: front_card_border = get_node_or_null("FrontFace/CardBorder")
	if not front_name_banner: front_name_banner = get_node_or_null("FrontFace/NameBanner")
	
	# Get UI element references for token
	if not token_attack_label: token_attack_label = get_node_or_null("TokenFace/AttackCircle/AttackLabel")
	if not token_health_label: token_health_label = get_node_or_null("TokenFace/HealthCircle/HealthLabel")
	if not token_art_texture: token_art_texture = get_node_or_null("TokenFace/ArtContainer/ArtTexture")
	if not token_oval_border: token_oval_border = get_node_or_null("TokenFace/OvalBorder")
	if not token_shield_aura: token_shield_aura = get_node_or_null("TokenFace/ShieldAura")
	
	if not token_attack_circle: token_attack_circle = get_node_or_null("TokenFace/AttackCircle")
	if not token_health_circle: token_health_circle = get_node_or_null("TokenFace/HealthCircle")
	
	# Call parent _ready which handles basic texture setup
	super._ready()
	
	# Populate UI from card_info if available
	_update_card_ui()
	_load_keywords()
	_load_custom_script()
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
func _on_gui_input(event: InputEvent) -> void:
	if current_view_mode == "token":
		var main = get_tree().current_scene
		
		# If currently attacking or enemy turn, block interactions
		if main and main.get("is_manual_attacking"):
			get_viewport().set_input_as_handled()
			return
			
		# If user clicks an active player unit, trigger attack arrow
		if can_attack and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var is_player = card_info.get("side", "player") == "player"
			if event.pressed and is_player:
				if main and main.has_method("start_manual_attack"):
					main.start_manual_attack(self )
					get_viewport().set_input_as_handled()
					return
					
		# Detect Right-Click for inspection
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				if main and main.has_method("inspect_card"):
					main.inspect_card(self )
			get_viewport().set_input_as_handled()
			return
			
		# Absorb mouse motion while in token mode to prevent DraggableObject hover states
		if event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
			return
			
	super._on_gui_input(event)

var _stats_initialized: bool = false

func _update_card_ui() -> void:
	if card_info.is_empty():
		return
		
	# Initialize internal combat stats from card_info exactly once
	if not _stats_initialized:
		if card_info.has("attack"):
			base_attack = int(card_info.get("attack", 0))
			attack = base_attack
		if card_info.has("health"):
			base_health = int(card_info.get("health", 0))
			health = base_health
		_stats_initialized = true
		
	# 1. Sync Full Card UI
	var is_player = card_info.get("side", "player") == "player"
	
	if cost_label:
		if card_info.has("cost") and is_player:
			cost_label.text = str(int(card_info.get("cost", 0)))
			if front_cost_circle:
				front_cost_circle.visible = true
		else:
			if front_cost_circle:
				front_cost_circle.visible = false
	
	if name_label:
		var display_name = card_info.get("display_name", card_info.get("name", "UNIT"))
		name_label.text = display_name.to_upper()
	
	var card_type = _get_card_type()
	var is_spell = card_type == CardType.SPELL
	
	if attack_label:
		if is_spell:
			if front_attack_circle:
				front_attack_circle.visible = false
		elif card_info.has("attack"):
			attack_label.text = str(attack)
			if attack > base_attack:
				attack_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
			elif attack < base_attack:
				attack_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			else:
				attack_label.remove_theme_color_override("font_color")
			if front_attack_circle:
				front_attack_circle.visible = true # Changed from attack_val > 0 to allow 0-attack units
	
	if health_label:
		if is_spell:
			if front_health_circle:
				front_health_circle.visible = false
		elif card_info.has("health"):
			health_label.text = str(health)
			if health > base_health:
				health_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
			elif health < base_health:
				health_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			else:
				health_label.remove_theme_color_override("font_color")
			if front_health_circle:
				front_health_circle.visible = true
	
	if description_label and card_info.has("description"):
		description_label.text = "[center]" + str(card_info.get("description", "")) + "[/center]"
		
	if race_label:
		if is_spell:
			if front_race_box:
				front_race_box.visible = false
		else:
			if front_race_box:
				front_race_box.visible = true
			var race = card_info.get("race", "robot") # Default robot for units
			race_label.text = str(race).to_upper()
	
	# Art background colors logic
	if front_art_background:
		match card_type:
			CardType.HERO: front_art_background.color = Color(0.8, 0.6, 0.1) # Bright Gold!
			CardType.SPELL: front_art_background.color = Color(0.2, 0.3, 0.6)
			_: front_art_background.color = Color(0.4, 0.45, 0.5)
			
	# Hero specific massive bling-bling on the front card
	if front_card_border:
		if card_type == CardType.HERO:
			front_card_border.color = Color(0.9, 0.75, 0.1) # Gold Border
			if front_name_banner:
				front_name_banner.color = Color(0.7, 0.5, 0.1) # Bright Banner
		else:
			front_card_border.color = Color(0.55, 0.45, 0.3)
			if front_name_banner:
				front_name_banner.color = Color(0.3, 0.25, 0.18)

	# 2. Sync Token UI
	if is_spell:
		if token_attack_circle:
			token_attack_circle.visible = false
		if token_health_circle:
			token_health_circle.visible = false
	else:
		if token_attack_label and card_info.has("attack"):
			token_attack_label.text = str(attack)
			if attack > base_attack:
				token_attack_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
			elif attack < base_attack:
				token_attack_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			else:
				token_attack_label.remove_theme_color_override("font_color")
			if token_attack_circle:
				token_attack_circle.visible = true
		
		if token_health_label and card_info.has("health"):
			token_health_label.text = str(health)
			if health > base_health:
				token_health_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
			elif health < base_health:
				token_health_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			else:
				token_health_label.remove_theme_color_override("font_color")
			if token_health_circle:
				token_health_circle.visible = true
		
	# 3. Update Faction Visuals and Keywords (Oval Color, Taunt Frame, Shield Aura)
	if token_oval_border:
		var faction_color = Color(0.2, 0.4, 1.0) # Player Blue
		if not is_player:
			faction_color = Color(1.0, 0.2, 0.2) # Enemy Red
			
		var is_hero = card_type == CardType.HERO
		
		# Figure out what keywords we have
		var has_taunt = false
		var has_shield = false
		for kw in card_info.get("keywords", []):
			if typeof(kw) == TYPE_STRING:
				if kw.to_lower() == "taunt": has_taunt = true
				if kw.to_lower() == "shield": has_shield = true
		for k in keyword_instances:
			if k.name.to_lower() == "taunt": has_taunt = true
			if k.name.to_lower() == "shield": has_shield = true
			
		# Toggle Shield Aura
		if token_shield_aura:
			token_shield_aura.visible = has_shield
			
		# We must duplicate the stylebox so we don't change it for all cards
		var style = token_oval_border.get_theme_stylebox("panel").duplicate()
		var mask_style = null
		if has_node("TokenFace/ArtContainer"):
			mask_style = $TokenFace/ArtContainer.get_theme_stylebox("panel").duplicate()
			
		if style is StyleBoxFlat:
			if is_hero:
				style.border_color = Color(0.95, 0.85, 0.2)
				style.border_width_left = 10
				style.border_width_top = 10
				style.border_width_right = 10
				style.border_width_bottom = 10
			else:
				style.border_color = faction_color
				style.border_width_left = 6
				style.border_width_top = 6
				style.border_width_right = 6
				style.border_width_bottom = 6
				
			# Check Taunt (Kiteshield Shape vs Oval)
			if has_taunt:
				# Kite Shield: flat rigid top, rounded bottom
				style.corner_radius_top_left = 20
				style.corner_radius_top_right = 20
				style.corner_radius_bottom_right = 90
				style.corner_radius_bottom_left = 90
				if mask_style:
					mask_style.corner_radius_top_left = 20
					mask_style.corner_radius_top_right = 20
					mask_style.corner_radius_bottom_right = 90
					mask_style.corner_radius_bottom_left = 90
			else:
				# Pure Oval
				style.corner_radius_top_left = 80
				style.corner_radius_top_right = 80
				style.corner_radius_bottom_right = 80
				style.corner_radius_bottom_left = 80
				if mask_style:
					mask_style.corner_radius_top_left = 80
					mask_style.corner_radius_top_right = 80
					mask_style.corner_radius_bottom_right = 80
					mask_style.corner_radius_bottom_left = 80
				
			# Setting bg_color.a to 0 ensures the border is only a border and doesn't tint the image
			style.bg_color = faction_color
			style.bg_color.a = 0.0
			token_oval_border.add_theme_stylebox_override("panel", style)
			if mask_style:
				$TokenFace/ArtContainer.add_theme_stylebox_override("panel", mask_style)

func reset_to_base_state() -> void:
	# Wipe combat tracking so it re-reads from card_info
	_stats_initialized = false
	
	# Clear temporary filters/tints
	modulate = Color(1.0, 1.0, 1.0)
	can_attack = true
	
	# Clear keyword instances (buffs, shields, auras, taunts)
	keyword_instances.clear()
	
	# Refresh UI to base values
	_update_card_ui()

func refresh_visual_state(custom_tween: Tween = null, duration: float = 0.3) -> void:
	var target_color = Color.WHITE
	var is_player = card_info.get("side", "player") == "player"
	
	if is_player and not can_attack:
		target_color = Color(0.5, 0.5, 0.5)
		
	if custom_tween:
		custom_tween.tween_property(self , "modulate", target_color, duration)
	else:
		modulate = target_color

func take_damage(amount: int) -> void:
	# Filter damage through keywords (e.g., Shield)
	var final_damage = amount
	for keyword in keyword_instances:
		final_damage = keyword.on_damage_taken(final_damage)
	
	health -= final_damage
	_update_card_ui()
	
	# Visual Feedback: Flash Red
	modulate = Color(1, 0.2, 0.2)
	var tween = create_tween()
	refresh_visual_state(tween, 0.3)
	
	if health <= 0:
		var main = get_tree().current_scene
		if main and main.has_method("kill_unit"):
			main.kill_unit(self )

func add_temporary_stats(atk: int, hp: int, do_emit_signal: bool = true) -> void:
	attack += atk
	health += hp
	_update_card_ui()
	if do_emit_signal:
		var main = get_tree().current_scene
		if main and main.has_signal("unit_stats_changed"):
			main.emit_signal("unit_stats_changed", self , atk, hp, false)

func add_permanent_stats(atk: int, hp: int) -> void:
	base_attack += atk
	base_health += hp
	attack += atk
	health += hp
	card_info["attack"] = float(int(card_info.get("attack", 0)) + atk)
	card_info["health"] = float(int(card_info.get("health", 0)) + hp)
	_update_card_ui()
	
	var uid = get_meta("uid", "")
	if uid != "":
		var run_manager = get_node_or_null("/root/RunManager")
		if run_manager and run_manager.has_method("add_permanent_stats"):
			run_manager.add_permanent_stats(uid, atk, hp)
	var main = get_tree().current_scene
	if main and main.has_signal("unit_stats_changed"):
		main.emit_signal("unit_stats_changed", self , atk, hp, true)


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
				kw_instance.setup(self )
				keyword_instances.append(kw_instance)
		else:
			push_warning("Keyword script not found: %s" % script_path)

func _load_custom_script() -> void:
	var script_path = card_info.get("passive_script_path", "")
	if script_path != "" and FileAccess.file_exists(script_path):
		var CustomScript = load(script_path)
		if CustomScript:
			custom_script_instance = CustomScript.new()
			add_child(custom_script_instance)
			if custom_script_instance.has_method("setup"):
				custom_script_instance.setup(self )

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	var main = get_tree().current_scene
	if main and main.has_method("show_notification"):
		main.show_notification(text, color)


## Refreshes UI after external data changes
func refresh_ui() -> void:
	_update_card_ui()

func set_duplicate_count(count: int) -> void:
	if dupe_badge and dupe_label:
		if count > 1:
			dupe_badge.visible = true
			dupe_label.text = "x %d" % count
		else:
			dupe_badge.visible = false

func set_availability(count: int) -> void:
	if dupe_badge and dupe_label:
		dupe_badge.visible = true
		dupe_label.text = "x %d" % count


func _handle_mouse_pressed() -> void:
	if card_container == null:
		return
		
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
		if main.has_method("can_afford") and not main.can_afford([ self ]):
			if main.has_method("show_notification"):
				main.show_notification("NOT ENOUGH ENERGY", Color(0.2, 0.6, 1))
			return
		
		# Check if the spell REQUIRES targeting (Arrow System)
		var needs_target = card_info.get("needs_target", false)
		
		if needs_target:
			# Targeted spells: Override drag and use Arrow System
			if main.has_method("start_spell_targeting"):
				main.start_spell_targeting(self )
			return
		else:
			# Untargeted spells (Global): Allow normal drag-and-drop
			# Do nothing here, let super() handle the drag
			pass
	
	# Proceed with normal card dragging (from hand/deck/field)
	super._handle_mouse_pressed()

func is_player_unit() -> bool:
	return card_info.get("side", "player") == "player"

func set_inspect_scale(multiplier: float) -> void:
	# Scale the entire card uniformly as normal. 
	# Godot 4 MSDF fonts will ensure this renders crisply without manual label scaling bounds hacks.
	self.scale = Vector2(multiplier, multiplier)
