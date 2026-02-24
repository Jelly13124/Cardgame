extends Node

# --- Signals ---
signal health_changed(current: int, maximum: int)
signal resources_changed(gold: int, core: int)
signal deck_updated()
signal items_updated()
signal run_ended(victory: bool)

# --- Run State ---
var is_run_active: bool = false
var current_hero_id: String = ""

# Base Stats
var max_health: int = 50
var current_health: int = 50

# Resources
var gold: int = 0
var core: int = 0

# Progression
var current_floor: int = 0
var player_deck: Array = [] # Array of Dictionaries (uid, card_id, bonus_attack, bonus_health)
var equipped_items: Array[String] = []
const MAX_ITEMS: int = 5

func _ready() -> void:
	pass

# --- Run Initialization ---

## Called when confirming the starter deck and beginning a new run
func start_new_run(hero_id: String, starter_deck: Array[String]) -> void:
	current_hero_id = hero_id
	
	player_deck.clear()
	for card_id in starter_deck:
		add_card_to_deck(card_id)
	
	# Reset resources and health
	gold = 0
	core = 0
	current_floor = 1
	current_health = max_health
	equipped_items.clear()
	is_run_active = true
	
	_emit_all_state()

# --- Deck Management ---

func add_card_to_deck(card_id: String) -> void:
	var uid = str(Time.get_ticks_usec()) + "_" + str(randi_range(1000, 9999))
	var card_data = {
		"uid": uid,
		"card_id": card_id,
		"bonus_attack": 0,
		"bonus_health": 0
	}
	player_deck.append(card_data)
	emit_signal("deck_updated")

## Returns true if the card was successfully removed
func remove_card_from_deck_by_uid(uid: String) -> bool:
	for i in range(player_deck.size()):
		if player_deck[i]["uid"] == uid:
			player_deck.remove_at(i)
			emit_signal("deck_updated")
			return true
	return false

func add_permanent_stats(uid: String, atk: int, hp: int) -> void:
	for card_data in player_deck:
		if card_data["uid"] == uid:
			card_data["bonus_attack"] += atk
			card_data["bonus_health"] += hp
			emit_signal("deck_updated")
			return

# --- Health & Damage ---

func modify_health(amount: int) -> void:
	current_health += amount
	current_health = clampi(current_health, 0, max_health)
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0 and is_run_active:
		_handle_run_loss()

func set_max_health(amount: int, heal_to_full: bool = false) -> void:
	max_health = amount
	if heal_to_full:
		current_health = max_health
	else:
		current_health = clampi(current_health, 0, max_health)
	emit_signal("health_changed", current_health, max_health)

# --- Resources ---

func add_resources(g: int, c: int) -> void:
	gold = max(0, gold + g)
	core = max(0, core + c)
	emit_signal("resources_changed", gold, core)

# --- Items ---

## Returns true if the item was successfully equipped
func equip_item(item_id: String) -> bool:
	if equipped_items.size() < MAX_ITEMS:
		equipped_items.append(item_id)
		emit_signal("items_updated")
		return true
	return false

# --- Internal Events ---

func _handle_run_loss() -> void:
	is_run_active = false
	emit_signal("run_ended", false)
	# TODO: Trigger base-building retention logic (e.g. keep 30% of Core)
	print("Mothership destroyed! Run ended.")

func _emit_all_state() -> void:
	emit_signal("health_changed", current_health, max_health)
	emit_signal("resources_changed", gold, core)
	emit_signal("deck_updated")
	emit_signal("items_updated")

## Debug tool testing
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build(): return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F9:
				print("--- DEBUG: RUN MANAGER STATE ---")
				print("Deck Size: ", player_deck.size())
				print("Deck Contents: ", player_deck)
				print("Health: ", current_health, "/", max_health)
				print("Resources - Gold: ", gold, " Core: ", core)
				print("Items: ", equipped_items)
			KEY_F10:
				print("DEBUG: +100 Gold")
				add_resources(100, 0)
			KEY_F11:
				print("DEBUG: Take 5 Damage")
				modify_health(-5)
