## Run-deck / gem-socket screen. Renders every card in RunManager.player_deck with
## its 1 gem socket, plus a gem-inventory panel. Click a gem in the inventory to
## select it, then click an empty socket on a card to insert it (locked after —
## gems cannot be removed this run). Card upgrades were replaced by gems.
## Opened from the map [📚 DECK] button and the rest-stop "Socket Gems" button.
extends Control
class_name RunDeckViewerModal

const T = preload("res://run_system/ui/theme/wasteland_theme.gd")
const CARD_FACTORY_SCENE = preload("res://battle_scene/my_card_factory.tscn")

var _card_factory: Node
## The gem id currently selected from the inventory (to insert on the next socket
## click). "" = nothing selected.
var _selected_gem: String = ""
var _rebuild: Callable = Callable()
## Stable container for the gem-inventory list (repopulated, never freed/recreated).
var _gem_box: VBoxContainer


func _ready() -> void:
	# MapScene's Control rect is NOT viewport-sized (it draws via get_viewport_rect()
	# but never sets its own size), so PRESET_FULL_RECT would collapse to (0,0).
	# Size ourselves to the viewport explicitly and stay updated on resize.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card_factory = CARD_FACTORY_SCENE.instantiate()
	add_child(_card_factory)
	_card_factory.card_size = Vector2(208, 286)
	_build()


func _fit_to_viewport() -> void:
	set_position(Vector2.ZERO)
	set_size(get_viewport_rect().size)


func _build() -> void:
	# Opaque full-screen page (pseudo-scene). Map _input is gated separately so
	# clicks can't fall through; in battle the STOP overlay blocks card input.
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.035, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 48)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header with close X
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = tr("UI_COMMON_RUN_DECK_TITLE").format({"n": RunManager.player_deck.size()})
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	header.add_child(title)

	var subtitle := Label.new()
	subtitle.text = tr("UI_COMMON_DECK_GEM_HINT")
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	vbox.add_child(subtitle)

	# Main: card grid (left) + gem inventory (right)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 18)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(main)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 600)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "CardGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	# Gem panel built ONCE; only its inner list (_gem_box) is repopulated on rebuild.
	# (Reassigning a captured local inside the _rebuild lambda does not persist across
	# calls, so we never free/recreate the panel — we refill stable containers.)
	main.add_child(_build_gem_panel())

	# Rebuild closure repaints the (stable) card grid and gem list after a socket.
	_rebuild = func() -> void:
		if not is_instance_valid(grid):
			return
		for c in grid.get_children():
			c.queue_free()
		for entry in RunManager.player_deck:
			if typeof(entry) == TYPE_DICTIONARY and str(entry.get("card_id", "")) != "":
				grid.add_child(_make_card_slot(entry))
		_populate_gem_box()
	_rebuild.call()
	_add_close_x()


## Top-right ✕ — same effect as the second-press toggle (queue_free).
func _add_close_x() -> void:
	var x := T.close_x_button()
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -64.0
	x.offset_right = -16.0
	x.offset_top = 16.0
	x.offset_bottom = 64.0
	x.pressed.connect(queue_free)
	add_child(x)


## ESC closes the page. Battle's top-bar only consumes ESC when its settings menu
## is already visible, so this never conflicts; the map has no ESC handler.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


## Right-hand gem inventory panel. Built once; the dynamic gem list lives in
## `_gem_box` (repopulated by _populate_gem_box on every rebuild).
func _build_gem_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	var m := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 12)
	panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	m.add_child(box)

	var hdr := Label.new()
	hdr.text = tr("UI_COMMON_GEM_INVENTORY")
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
	box.add_child(hdr)

	_gem_box = VBoxContainer.new()
	_gem_box.add_theme_constant_override("separation", 8)
	box.add_child(_gem_box)
	_populate_gem_box()
	return panel


## (Re)fill the gem-inventory list. Safe to call repeatedly — clears first.
func _populate_gem_box() -> void:
	if not is_instance_valid(_gem_box):
		return
	for c in _gem_box.get_children():
		c.queue_free()
	if RunManager.gem_inventory.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_COMMON_GEM_NONE")
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_gem_box.add_child(empty)
		return
	for gem_id in RunManager.gem_inventory:
		_gem_box.add_child(_make_gem_button(str(gem_id)))


func _make_gem_button(gem_id: String) -> Button:
	var b := Button.new()
	b.text = _gem_label(gem_id)
	b.custom_minimum_size = Vector2(0, 40)
	b.tooltip_text = _gem_desc(gem_id)
	# Gem art (Codex) as the button icon, constrained to fit the row height.
	var gicon := str(RunManager.get_gem_data(gem_id).get("icon", ""))
	if gicon != "" and ResourceLoader.exists(gicon):
		b.icon = load(gicon)
		b.add_theme_constant_override("icon_max_width", 28)
	if gem_id == _selected_gem:
		b.modulate = Color(0.6, 1.0, 0.7)  # highlight the chosen gem
	b.pressed.connect(
		func() -> void:
			_selected_gem = "" if _selected_gem == gem_id else gem_id
			if _rebuild.is_valid():
				_rebuild.call()
	)
	return b


func _gem_label(gem_id: String) -> String:
	var d := RunManager.get_gem_data(gem_id)
	return Settings.t("GEM_%s_TITLE" % gem_id, str(d.get("title", gem_id)))


func _gem_desc(gem_id: String) -> String:
	return Settings.t("GEM_%s_DESC" % gem_id, "")


## One deck card: its art + a row of 1 socket widget underneath.
func _make_card_slot(entry: Dictionary) -> Control:
	var card_id: String = str(entry.get("card_id", ""))
	var uid: String = str(entry.get("uid", ""))
	var gems: Array = entry.get("gems", [])

	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(190, 300)
	wrapper.add_theme_constant_override("separation", 4)

	var art_holder := Control.new()
	art_holder.custom_minimum_size = Vector2(180, 250)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override(
		"panel", T.panel_with_shadow(Color(0.09, 0.072, 0.055, 0.92), T.PANEL_BORDER, 3)
	)
	art_holder.add_child(frame)
	var card = _card_factory.create_card(card_id, null)
	if card:
		if card.get_parent():
			card.get_parent().remove_child(card)
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(10, 18)
		card.pivot_offset = Vector2.ZERO
		card.scale = Vector2(160.0 / 208.0, 160.0 / 208.0)
		art_holder.add_child(card)
	wrapper.add_child(art_holder)

	# 1 socket widget
	var sockets := HBoxContainer.new()
	sockets.alignment = BoxContainer.ALIGNMENT_CENTER
	sockets.add_theme_constant_override("separation", 6)
	wrapper.add_child(sockets)
	for slot in range(1):
		sockets.add_child(_make_socket(uid, gems, slot))

	return wrapper


func _make_socket(uid: String, gems: Array, slot: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(84, 34)
	if slot < gems.size():
		# Filled (locked).
		b.text = _gem_label(str(gems[slot]))
		b.disabled = true
		b.tooltip_text = _gem_desc(str(gems[slot]))
		b.modulate = Color(0.7, 0.95, 1.0)
	else:
		# Empty — inserts the selected gem on click.
		b.text = "＋"
		b.disabled = _selected_gem == ""
		b.pressed.connect(
			func() -> void:
				if _selected_gem != "" and RunManager.socket_gem(uid, _selected_gem):
					_selected_gem = ""
					if _rebuild.is_valid():
						_rebuild.call()
		)
	return b
