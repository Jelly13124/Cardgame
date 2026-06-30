extends Control
## Host for the battle scene's top bar. Mounts the shared run_top_bar component;
## the ⚙ gear opens the unified pause panel (settings / how-to / abandon / quit).

const PAUSE_PANEL = preload("res://run_system/ui/pause_panel.gd")
const RUN_TOP_BAR = preload("res://run_system/ui/run_top_bar.gd")

var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	call_deferred("_setup")


func _setup() -> void:
	main = get_tree().current_scene

	var bar = RUN_TOP_BAR.new()
	bar.hp_from_player = true
	bar.player_source = main.player if (main and "player" in main) else null
	bar.show_character_button = false
	bar.show_settings_button = true
	bar.show_tools = true
	bar.deck_pressed.connect(_on_deck_pressed)
	bar.settings_pressed.connect(_show_settings)
	bar.tool_used.connect(
		func(i: int) -> void:
			if main and main.has_method("use_tool"):
				main.use_tool(i)
	)
	add_child(bar)


func _on_deck_pressed() -> void:
	if main and main.ui_manager:
		main.ui_manager.show_run_deck_viewer()


func _show_settings() -> void:
	# Open the unified pause panel (settings / how-to / abandon / quit) on the battle
	# scene — the same panel ESC, the map gear, and the base gear all use.
	PAUSE_PANEL.open(main, RunManager.is_run_active)
