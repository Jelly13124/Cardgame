extends Node

## The title menu's four entries are text buttons with no box (STS2
## NMainMenuTextButton): empty styleboxes in every state, a cream label that
## turns gold on hover, in the order New Game, Continue, Settings, Quit.

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var menu = load("res://ui/menus/main_menu.tscn").instantiate()
	add_child(menu)
	for i in 4:
		await get_tree().process_frame
	var want := [tr("MENU_NEW_GAME"), tr("MENU_CONTINUE"), tr("MENU_SETTINGS"), tr("MENU_QUIT")]
	var found: Array = []
	for b in menu.find_children("*", "Button", true, false):
		if b.text in want:
			found.append(b)
	found.sort_custom(func(a, b): return a.position.y < b.position.y)
	_expect(found.map(func(b): return b.text) == want, "the four entries keep their order (%s)" % [found.map(func(b): return b.text)])
	for b in found:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			_expect(b.get_theme_stylebox(state) is StyleBoxEmpty, "%s has no %s box" % [b.text, state])
		_expect(b.get_theme_color("font_hover_color") != b.get_theme_color("font_color"), "%s changes colour on hover" % b.text)
	menu.queue_free()
	if failures.is_empty():
		print("[OK] main menu text buttons passed")
		get_tree().quit(0)
		return
	push_error("main menu text buttons failed: %s" % "; ".join(failures))
	get_tree().quit(1)
