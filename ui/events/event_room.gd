## The "?" node's event screen (STS2 NEventRoom, default layout): the event's
## illustration in a framed portrait on the left, its text and options on the
## right, an act backdrop behind both. Owner sets `model` (already begun), adds
## the room, and waits for `resolved`.
## class_name is intentionally omitted by project convention — preload.
extends Control

const RUN_TOP_BAR = preload("uid://dd4fkkrkiwgrj")  # res://ui/common/run_top_bar.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const RESULT_SCREEN = preload("uid://bxh1x1hy6fylv")  # res://ui/rewards/result_screen.gd
const EVENT_LAYOUT = preload("res://ui/events/event_layout.gd")

const ART_DIR := "res://run_system/assets/images/events/"
## Shown at 1:1 in the 1920x1080 viewport (spec: left-portrait layout).
const PORTRAIT_SIZE := Vector2(1024, 768)
const PORTRAIT_X := 80.0
const CONTENT_LEFT := 1144.0
const CONTENT_RIGHT := 1840.0
const SCREEN_HEIGHT := 1080.0

signal resolved

var model
var _portrait_art: TextureRect
var _layout
## Bumped on every state_changed: an option that changed nothing still gets
## its buttons back.
var _state_seq := 0
var _done := false
## BGM playing when the event opened — restored on close.
var _prev_music: String = ""


func _ready() -> void:
	# Fill the screen whatever the parent: a Control under a CanvasLayer gets
	# no viewport-sized rect from anchors alone.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	_build()
	_prev_music = AudioManager.current_track()
	AudioManager.play_music("event")


func _fit_to_viewport() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x > 0.0 and vp.y > 0.0:
		position = Vector2.ZERO
		size = vp


func _build() -> void:
	_add_backdrop()
	var below_bar := RUN_TOP_BAR.BAR_HEIGHT
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.03, 0.03, 0.03)
	frame.border_color = Color(0.62, 0.52, 0.32)
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(4)
	var portrait := Panel.new()
	portrait.name = "EventPortrait"
	portrait.position = Vector2(PORTRAIT_X, below_bar + (SCREEN_HEIGHT - below_bar - PORTRAIT_SIZE.y) * 0.5)
	portrait.size = PORTRAIT_SIZE
	portrait.clip_contents = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_theme_stylebox_override("panel", frame)
	add_child(portrait)
	_portrait_art = TextureRect.new()
	_portrait_art.name = "EventPortraitArt"
	_portrait_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Fills the 768-high frame: 1024x768 art fits exactly, older 1408x768 art is
	# centre-cropped; neither is scaled up.
	_portrait_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(_portrait_art)
	# The frame's border is drawn again over the art's edge.
	var edge := frame.duplicate() as StyleBoxFlat
	edge.draw_center = false
	var border := Panel.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_theme_stylebox_override("panel", edge)
	portrait.add_child(border)

	_layout = EVENT_LAYOUT.new()
	_layout.name = "EventContent"
	_layout.position = Vector2(CONTENT_LEFT, below_bar + 16.0)
	_layout.size = Vector2(CONTENT_RIGHT - CONTENT_LEFT, SCREEN_HEIGHT - below_bar - 48.0)
	add_child(_layout)
	_layout.bind(model)
	_layout.option_pressed.connect(_on_option_pressed)
	model.state_changed.connect(_on_state_changed)
	_refresh_portrait()


## The act's backdrop under a dark scrim, opaque so the map is hidden; a flat
## fill while the act has no backdrop.
func _add_backdrop() -> void:
	var path := ART_DIR + "backdrops/act_%d.png" % int(RunManager.current_act)
	var bg: Control
	if ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg = tex
	else:
		var fill := ColorRect.new()
		fill.color = Color(0.08, 0.07, 0.06)
		bg = fill
	bg.name = "EventBackground"
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var scrim := ColorRect.new()
	scrim.name = "EventScrim"
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.offset_top = RUN_TOP_BAR.PAGE_ART_TOP
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


## events/<page art>.png, falling back to the event's art (JSON `art`, else
## its entry).
func _refresh_portrait() -> void:
	var event_art := str(MODEL_DB.data("event", model.id).get("art", MODEL_ID.entry_of(model.id)))
	for art in [model.page_art(model.page), event_art]:
		var path: String = ART_DIR + str(art) + ".png"
		if str(art) != "" and ResourceLoader.exists(path):
			_portrait_art.texture = load(path)
			return
	_portrait_art.texture = null


## The run ended inside the event: the end-of-run screen on top, as after a
## lost battle.
func _show_defeat() -> void:
	_done = true
	var canvas := CanvasLayer.new()
	canvas.layer = 250
	add_child(canvas)
	var screen = RESULT_SCREEN.new()
	screen.name = "ResultScreen"
	screen.mode = "defeat"
	canvas.add_child(screen)


func _on_state_changed() -> void:
	_state_seq += 1
	_refresh_portrait()


func _on_option_pressed(index: int) -> void:
	if _done or index < 0 or index >= model.current_options.size():
		return
	if model.current_options[index].is_proceed:
		_done = true
		RunManager.finish_event()
		if _prev_music != "":
			AudioManager.play_music(_prev_music)
		resolved.emit()
		queue_free()
		return
	var seq := _state_seq
	var chosen: bool = model.choose(index)
	if not RunManager.is_run_active:
		_show_defeat()  # the run was lost inside the event
		return
	if seq == _state_seq:
		_layout.rebuild()  # nothing changed the page: give the buttons back
	if chosen:
		RunManager.event_option_resolved()
