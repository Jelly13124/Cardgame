extends Node

## Regression contract for the authored Bill attack sheet.  The frames must be
## cut out cleanly enough that the battle background never flashes a white halo,
## and the gunshot origin must match the new pose instead of the retired sheet.

const HERO_ATTACK_DIR := "res://battle_scene/assets/images/heroes/cowboy_bill/attack/"
const PLAYER_VIEW = preload("uid://dky1c70n7vcfn")  # res://ui/battle/player_view.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	_test_attack_frames_have_clean_edges()
	_test_muzzle_anchor_matches_bill_pose()
	if failures.is_empty():
		print("[OK] hero attack art contract passed")
		get_tree().quit(0)
		return
	push_error("hero attack art contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_attack_frames_have_clean_edges() -> void:
	for frame in range(8):
		var path := "%scowboy_bill_attack_%d.png" % [HERO_ATTACK_DIR, frame]
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(image != null, "attack frame %d loads" % frame)
		if image == null:
			continue
		var bright_fringe := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.0 and pixel.a < 0.90 and pixel.r > 0.86 and pixel.g > 0.86 and pixel.b > 0.86:
					bright_fringe += 1
		_expect(bright_fringe == 0, "attack frame %d has no bright semi-transparent cutout fringe (got %d)" % [frame, bright_fringe])


func _test_muzzle_anchor_matches_bill_pose() -> void:
	var player: Node = PLAYER_VIEW.new()
	var constants: Dictionary = (player.get_script() as Script).get_script_constant_map()
	var anchor: Vector2 = constants.get("MUZZLE_NATIVE_POSITION", Vector2.ZERO)
	_expect(anchor.x >= 205.0, "Bill muzzle anchor stays at the right edge of the gun")
	_expect(anchor.y >= 120.0 and anchor.y <= 155.0, "Bill muzzle anchor follows the new lower gun pose")
	player.free()
