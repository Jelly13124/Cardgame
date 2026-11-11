extends Node

## The home base lets the player type a run seed (empty = random; invalid text
## never starts a run) and the result screen shows the run's seed.

const HOME = preload("uid://c6bvuu6kbx0pq")  # res://ui/base/home_base_scene.tscn
const RESULT_SCREEN = preload("uid://bxh1x1hy6fylv")  # res://ui/rewards/result_screen.gd
const T = preload("uid://dfcqloc58bvde")  # res://ui/common/theme/wasteland_theme.gd
const TEST_SAVE_ROOT = preload("uid://c5pfll7nw68un")  # res://tests/support/test_save_root.gd

var failures: PackedStringArray = []


func _ready() -> void:
	TEST_SAVE_ROOT.use("seed_ui_contract_test")
	call_deferred("_run")


func _exit_tree() -> void:
	TEST_SAVE_ROOT.release()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	RunManager.is_run_active = false
	var home := HOME.instantiate()
	add_child(home)
	await get_tree().process_frame
	await get_tree().process_frame
	var field := home.find_child("SeedField", true, false) as LineEdit
	_expect(field != null, "home has a SeedField")
	if field != null:
		field.text = ""
		_expect(home.call("_resolve_seed_input") == {"ok": true, "seed": ""}, "empty seed means random")
		field.text = " testseedo1 "
		_expect(home.call("_resolve_seed_input") == {"ok": true, "seed": "TESTSEED01"}, "typed seed is canonical")
		field.text = "abc def"
		_expect(not bool(home.call("_resolve_seed_input")["ok"]), "seed with a space is invalid")
		home.call("_on_start_pressed")
		await get_tree().process_frame
		_expect(not RunManager.is_run_active, "invalid seed does not start a run")
		_expect(bool(field.get_meta("seed_invalid", false)), "invalid seed is flagged on the field")
		var invalid_style := field.get_theme_stylebox("normal") as StyleBoxTexture
		_expect(
			invalid_style != null and invalid_style.texture != null
			and invalid_style.texture.resource_path.ends_with("/kit/input_9slice.png")
			and invalid_style.modulate_color == T.INPUT_INVALID_TINT
			and str(field.get_meta(Tooltip.TOOLTIP_TEXT_META, "")) == tr("UI_HOME_SEED_INVALID")
			and field.tooltip_text.is_empty(),
			"invalid input keeps the shared field skin and shows a visible error tint and reason"
		)
		field.mouse_entered.emit()
		await get_tree().process_frame
		_expect(
			bool(Tooltip.get("_visible")) and int(Tooltip.get("_owner_id")) == field.get_instance_id(),
			"invalid seed hover shows its reason through the shared tooltip"
		)
		field.text = "VALIDSEED42"
		field.text_changed.emit(field.text)
		var valid_style := field.get_theme_stylebox("normal") as StyleBoxTexture
		_expect(
			not bool(field.get_meta("seed_invalid", true)) and field.tooltip_text.is_empty()
			and str(field.get_meta(Tooltip.TOOLTIP_TEXT_META, "")).is_empty()
			and not bool(Tooltip.get("_visible"))
			and valid_style != null and valid_style.modulate_color == Color.WHITE,
			"editing clears the seed error feedback"
		)
	home.queue_free()

	RunManager.start_new_run("base:cowboy_bill", [], 0, "SEEDTEST42")
	RunManager.is_run_active = true
	RunManager.abandon_run()  # production order: teardown first, then the result screen
	var screen = RESULT_SCREEN.new()
	screen.mode = "defeat"
	add_child(screen)
	await get_tree().process_frame
	var label := screen.find_child("SeedLabel", true, false) as Label
	_expect(label != null and label.text.contains("SEEDTEST42"), "result screen shows the seed")
	screen.queue_free()
	RunManager.is_run_active = false
	RunManager.clear_run_save()

	if failures.is_empty():
		print("[OK] seed ui contract passed")
		get_tree().quit(0)
		return
	push_error("seed ui contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)
