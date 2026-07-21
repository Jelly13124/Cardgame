extends Control

const CARD_FACTORY = preload("res://battle_scene/my_card_factory.tscn")
const OUTPUT_PATH = "res://tmp/circuit-breaker-card-ui-runtime.png"
const CARD_IDS: Array[String] = [
	"recoil_shot",
	"arc_flash",
	"acid_splash",
	"dissect",
	"bone_breaker",
	"coagulate",
	"limit_break",
	"hemorrhage",
]


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	RunManager.current_hero_id = "cowboy_bill"
	RunManager.current_hero_data = {"card_ui_skin": "cowboy_bill"}

	var background := TextureRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.texture = load(
		"res://battle_scene/assets/images/backgrounds/wasteland_battlefield_quiet_v6.png"
	)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.03, 0.075, 0.08, 0.42)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var factory = CARD_FACTORY.instantiate()
	add_child(factory)
	factory.card_size = Vector2(208, 286)
	factory.preload_card_data()

	const SCALE := 1.08
	const START_X := 190.0
	const GAP_X := 410.0
	const START_Y := 180.0
	const GAP_Y := 420.0
	for index in range(CARD_IDS.size()):
		var card = factory.create_card(CARD_IDS[index], null)
		if card == null:
			continue
		card.position = Vector2(
			START_X + GAP_X * float(index % 4),
			START_Y + GAP_Y * float(index / 4)
		)
		card.scale = Vector2.ONE * SCALE
		card.pivot_offset = Vector2.ZERO
		card.can_be_interacted_with = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for _i in range(12):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save Circuit Breaker card capture: %s" % error)
		get_tree().quit(1)
		return
	get_tree().quit(0)
