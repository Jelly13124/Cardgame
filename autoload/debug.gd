extends Node

## Debug keys (STS2 DevConsole, debug builds only): F9 prints the run state,
## F10 adds 100 gold, F11 deals 5 damage, F12 grants an unowned relic.


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_F9:
			print("--- DEBUG: RUN MANAGER STATE ---")
			print("Deck Size: ", RunManager.player_deck.size())
			print("Deck Contents: ", RunManager.player_deck)
			print("Health: ", RunManager.current_health, "/", RunManager.max_health)
			print("Resources - Gold: ", RunManager.gold, " Scrap(bank): ", RunManager.total_run_scrap())
			print("Items: ", RunManager.equipped_items, " Inventory: ", RunManager.inventory_items)
			print("Relics: ", RunManager.relics)
		KEY_F10:
			print("DEBUG: +100 Gold")
			RunManager.add_resources(100, 0)
		KEY_F11:
			print("DEBUG: Take 5 Damage")
			RunManager.modify_health(-5)
		KEY_F12:
			var unowned: Array = RunManager.get_unowned_relic_ids()
			if not unowned.is_empty():
				print("DEBUG: +", unowned[0])
				RunManager.add_relic(str(unowned[0]))
