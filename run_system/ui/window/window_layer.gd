## WindowLayer — hosts all DraggableWindows for a scene. Adds itself above the
## scene UI, brings a clicked window to front, and closes the TOPMOST window on
## ui_cancel (consuming it so the scene's own ESC handler doesn't also fire).
## Usage: `load(".../window_layer.gd").ensure(host_scene).open(window_instance)`
extends CanvasLayer

const LAYER_NAME := "WindowLayer"


static func ensure(host: Node) -> CanvasLayer:
	var existing = host.get_node_or_null(LAYER_NAME)
	if existing:
		return existing
	var wl = load("res://run_system/ui/window/window_layer.gd").new()
	wl.name = LAYER_NAME
	wl.layer = 60  # above scene UI; currency top bar sits higher (layer 70)
	host.add_child(wl)
	return wl


## Add a window and center it (cascade-offset when others are already open).
func open(win: Control) -> void:
	add_child(win)
	var vp := get_viewport().get_visible_rect().size
	var offset := 30.0 * float(maxi(get_child_count() - 1, 0))
	win.position = (vp - win.size) * 0.5 + Vector2(offset, offset)
	bring_to_front(win)


func bring_to_front(win: Control) -> void:
	move_child(win, get_child_count() - 1)


func has_windows() -> bool:
	return get_child_count() > 0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if get_child_count() == 0:
		return
	var top := get_child(get_child_count() - 1)
	if top is Control and top.has_method("close"):
		top.close()
		get_viewport().set_input_as_handled()
