extends Node

## The title menu's four entries are plate buttons (owner, 2026-11-25): New Game
## is the rust primary plate, Continue / Settings / Quit are cream secondary
## plates, all the same size, in the order New Game, Continue, Settings, Quit.

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var menu = load("uid://dnjlmt1repvjw").instantiate()
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
	for i in found.size():
		var b: Button = found[i]
		var visuals := b.get_node_or_null("ActionVisuals")
		var want_role := "primary" if i == 0 else "secondary"
		_expect(visuals != null and visuals.get("role") == want_role, "%s uses the %s plate" % [b.text, want_role])
		_expect(b.size == found[0].size, "%s matches the other plates' size" % b.text)
		_expect(b.get_theme_color("font_hover_color") != b.get_theme_color("font_color"), "%s changes colour on hover" % b.text)
	menu.queue_free()
	if failures.is_empty():
		print("[OK] main menu plate buttons passed")
		get_tree().quit(0)
		return
	push_error("main menu plate buttons failed: %s" % "; ".join(failures))
	get_tree().quit(1)
