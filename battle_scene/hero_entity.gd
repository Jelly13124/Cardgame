extends Control
class_name HeroEntity

signal hp_changed(current: int, max_hp: int)
signal atk_changed(current: int)
signal ability_used()

@export var hero_name: String = "Hero"
@export var max_hp: int = 30:
	set(value):
		max_hp = value
		hp = clampi(hp, 0, max_hp)
		emit_signal("hp_changed", hp, max_hp)
		_update_ui()

var hp: int = 30:
	set(value):
		hp = clampi(value, 0, max_hp)
		emit_signal("hp_changed", hp, max_hp)
		_update_ui()

var atk: int = 5:
	set(value):
		atk = value
		emit_signal("atk_changed", atk)
		_update_ui()

var side: String = "player": # "player" or "enemy"
	set(value):
		side = value
		_update_ui()
		
var can_use_ability: bool = true:
	set(value):
		can_use_ability = value
		_update_ui()

@onready var avatar = $SquareContainer/Avatar
@onready var ability_button = $AbilityButton
@onready var hp_label = $SquareContainer/HPIcon/HPLabel
@onready var atk_label = $SquareContainer/AtkIcon/AtkLabel

func _ready():
	_update_ui()
	if ability_button:
		ability_button.pressed.connect(_on_ability_pressed)
	
	# Connect mouse signals for targeting
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	var main = get_tree().current_scene
	if main and main.has_method("_on_unit_hover_entered"):
		main._on_unit_hover_entered(self )

func _on_mouse_exited():
	var main = get_tree().current_scene
	if main and main.has_method("_on_unit_hover_exited"):
		main._on_unit_hover_exited(self )

func setup(data: Dictionary):
	hero_name = data.get("name", "Hero")
	max_hp = data.get("health", 30)
	hp = data.get("health", 30)
	atk = data.get("attack", 5)
	side = data.get("side", "player")
	
	if data.has("texture"):
		avatar.texture = data.get("texture")
	
	_update_ui()

func take_damage(amount: int):
	hp -= amount
	# Flash red effect
	var tween = create_tween()
	tween.tween_property(self , "modulate", Color.RED, 0.1)
	tween.tween_property(self , "modulate", Color.WHITE, 0.2)
	
	if hp <= 0:
		_die()

func heal(amount: int):
	hp += amount

func _die():
	var main = get_tree().current_scene
	if main and main.has_method("on_hero_died"):
		main.on_hero_died(self )

func _on_ability_pressed():
	if not can_use_ability: return
	
	emit_signal("ability_used")
	var main = get_tree().current_scene
	if main and main.has_method("on_hero_ability_triggered"):
		main.on_hero_ability_triggered(self )

func _update_ui():
	if hp_label:
		hp_label.text = str(hp)
	if atk_label:
		atk_label.text = str(atk)
		
	if ability_button:
		ability_button.visible = (side == "player")
		ability_button.disabled = not can_use_ability
		ability_button.text = "SNIPE (%d)" % atk
