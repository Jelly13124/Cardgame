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
var race_label: Label
var art_texture: TextureRect
var dupe_badge: ColorRect
var dupe_label: Label

# --- UI Element references (Token) ---
var token_attack_label: Label
var token_health_label: Label
var token_art_texture: TextureRect
var token_oval_border: Panel
var token_shield_aura: Panel

# View mode: "card" or "token"
var current_view_mode: String = "card"

# Combat state
var health: int = -1
var attack: int = -1
var can_attack: bool = false
var keyword_instances: Array = []
var custom_script_instance: Node = null


func _ready() -> void:
	# Get UI element references for full card
	cost_label = $FrontFace/CostCircle/CostLabel if has_node("FrontFace/CostCircle/CostLabel") else null
	name_label = $FrontFace/NameBanner/NameLabel if has_node("FrontFace/NameBanner/NameLabel") else null
	attack_label = $FrontFace/AttackCircle/AttackLabel if has_node("FrontFace/AttackCircle/AttackLabel") else null
	health_label = $FrontFace/HealthCircle/HealthLabel if has_node("FrontFace/HealthCircle/HealthLabel") else null
	description_label = $FrontFace/DescriptionBox/DescriptionLabel if has_node("FrontFace/DescriptionBox/DescriptionLabel") else null
	race_label = $FrontFace/RaceBox/RaceLabel if has_node("FrontFace/RaceBox/RaceLabel") else null
	art_texture = $FrontFace/ArtContainer/ArtTexture if has_node("FrontFace/ArtContainer/ArtTexture") else null
	dupe_badge = $FrontFace/DupeBadge if has_node("FrontFace/DupeBadge") else null
	dupe_label = $FrontFace/DupeBadge/DupeLabel if has_node("FrontFace/DupeBadge/DupeLabel") else null
	
	# Get UI element references for token
	token_attack_label = $TokenFace/AttackCircle/AttackLabel if has_node("TokenFace/AttackCircle/AttackLabel") else null
	token_health_label = $TokenFace/HealthCircle/HealthLabel if has_node("TokenFace/HealthCircle/HealthLabel") else null
	token_art_texture = $TokenFace/ArtContainer/ArtTexture if has_node("TokenFace/ArtContainer/ArtTexture") else null
	token_oval_border = $TokenFace/OvalBorder if has_node("TokenFace/OvalBorder") else null
	token_shield_aura = $TokenFace/ShieldAura if has_node("TokenFace/ShieldAura") else null
	
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
			attack = int(card_info.get("attack", 0))
		if card_info.has("health"):
			health = int(card_info.get("health", 0))
		_stats_initialized = true
		
	var base_atk = int(card_info.get("attack", 0))
	var base_hp = int(card_info.get("health", 0))
	
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
			attack_label.text = str(attack)
			if attack > base_atk:
				attack_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
			else:
				attack_label.remove_theme_color_override("font_color")
			if has_node("FrontFace/AttackCircle"):
				$FrontFace/AttackCircle.visible = true # Changed from attack_val > 0 to allow 0-attack units
	
	if health_label:
		if is_spell:
			if has_node("FrontFace/HealthCircle"):
				$FrontFace/HealthCircle.visible = false
		elif card_info.has("health"):
			health_label.text = str(health)
			if health > base_hp:
				health_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
			else:
				health_label.remove_theme_color_override("font_color")
			if has_node("FrontFace/HealthCircle"):
				$FrontFace/HealthCircle.visible = true
	
	if description_label and card_info.has("description"):
		description_label.text = card_info.get("description", "")
		
	if race_label:
		if is_spell:
			if has_node("FrontFace/RaceBox"):
				$FrontFace/RaceBox.visible = false
		else:
			if has_node("FrontFace/RaceBox"):
				$FrontFace/RaceBox.visible = true
			var race = card_info.get("race", "robot") # Default robot for units
			race_label.text = str(race).to_upper()
	
	# Art background colors logic
	var type = card_info.get("type", "unit")
	if has_node("FrontFace/ArtBackground"):
		match type:
			"hero": $FrontFace/ArtBackground.color = Color(0.8, 0.6, 0.1) # Bright Gold!
			"spell": $FrontFace/ArtBackground.color = Color(0.2, 0.3, 0.6)
			"building": $FrontFace/ArtBackground.color = Color(0.4, 0.3, 0.2)
			_: $FrontFace/ArtBackground.color = Color(0.4, 0.45, 0.5)
			
	# Hero specific massive bling-bling on the front card
	if has_node("FrontFace/CardBorder"):
		if type == "hero":
			$FrontFace/CardBorder.color = Color(0.9, 0.75, 0.1) # Gold Border
			if has_node("FrontFace/NameBanner"):
				$FrontFace/NameBanner.color = Color(0.7, 0.5, 0.1) # Bright Banner
		else:
			$FrontFace/CardBorder.color = Color(0.55, 0.45, 0.3)
			if has_node("FrontFace/NameBanner"):
				$FrontFace/NameBanner.color = Color(0.3, 0.25, 0.18)

	# 2. Sync Token UI
	if is_spell:
		if has_node("TokenFace/AttackCircle"):
			$TokenFace/AttackCircle.visible = false
		if has_node("TokenFace/HealthCircle"):
			$TokenFace/HealthCircle.visible = false
	else:
		if token_attack_label and card_info.has("attack"):
			token_attack_label.text = str(attack)
			if attack > base_atk:
				token_attack_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
			elif attack < base_atk:
				token_attack_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			else:
				token_attack_label.remove_theme_color_override("font_color")
			if has_node("TokenFace/AttackCircle"):
				$TokenFace/AttackCircle.visible = true
		
		if token_health_label and card_info.has("health"):
			token_health_label.text = str(health)
			if health > base_hp:
				token_health_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
			elif health < base_hp:
				token_health_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			else:
				token_health_label.remove_theme_color_override("font_color")
			if has_node("TokenFace/HealthCircle"):
				$TokenFace/HealthCircle.visible = true
		
	# 3. Update Faction Visuals and Keywords (Oval Color, Taunt Frame, Shield Aura)
	if token_oval_border:
		var faction_color = Color(0.2, 0.4, 1.0) # Player Blue
		if not is_player:
			faction_color = Color(1.0, 0.2, 0.2) # Enemy Red
			
		var is_hero = card_info.get("type", "unit") == "hero"
		
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
	var target_color = Color.WHITE
	var is_player = card_info.get("side", "player") == "player"
	if is_player and get("can_attack") != null and get("can_attack") == false:
		target_color = Color(0.5, 0.5, 0.5)
	tween.tween_property(self , "modulate", target_color, 0.3)
	
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
	var script_path = card_info.get("script_path", "")
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
