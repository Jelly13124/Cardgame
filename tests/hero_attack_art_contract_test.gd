extends Node

## Regression contract for the authored Bill attack sheet.  The frames must be
## cut out cleanly enough that neither a white nor black matte flashes,
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
	_test_fringe_detector_distinguishes_outline_from_shadow()
	_test_attack_frames_have_clean_edges()
	_test_hero_geometry()
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
		var dark_fringe := _count_detached_dark_fringe(image)
		_expect(dark_fringe <= 6, "attack frame %d has no detached near-black cutout fringe (got %d; <=6 antialias pixels allowed)" % [frame, dark_fringe])
		_expect(bright_fringe <= 6, "attack frame %d has no bright semi-transparent cutout fringe (got %d; <=6 antialias pixels allowed)" % [frame, bright_fringe])


func _count_detached_dark_fringe(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.047 or pixel.a >= 0.90 or maxf(pixel.r, maxf(pixel.g, pixel.b)) >= 0.157:
				continue
			# A legitimate antialiased outline is directly beside opaque art.
			# A matte shadow has a wider translucent band or detached remnants.
			var touches_opaque := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var sample := Vector2i(x + dx, y + dy)
					if sample.x >= 0 and sample.y >= 0 and sample.x < image.get_width() and sample.y < image.get_height():
						if image.get_pixelv(sample).a >= 0.90:
							touches_opaque = true
			if not touches_opaque:
				count += 1
	return count


func _test_fringe_detector_distinguishes_outline_from_shadow() -> void:
	var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(4, 4, 4, 4), Color(0.08, 0.06, 0.04, 1.0))
	image.fill_rect(Rect2i(3, 4, 1, 4), Color(0.08, 0.06, 0.04, 0.5))
	_expect(_count_detached_dark_fringe(image) == 0, "opaque dark outlines and their one-pixel antialias remain valid")
	image.fill_rect(Rect2i(2, 4, 1, 4), Color(0.08, 0.06, 0.04, 0.5))
	_expect(_count_detached_dark_fringe(image) == 4, "near-black translucent matte outside the outline is detected")
	image.set_pixel(10, 10, Color(0.10, 0.09, 0.08, 0.3))
	_expect(_count_detached_dark_fringe(image) == 5, "detached near-black background residue is detected")


func _opaque_rect(image: Image) -> Rect2i:
	var left := image.get_width()
	var top := image.get_height()
	var right := 0
	var bottom := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a < 0.90:
				continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x + 1)
			bottom = maxi(bottom, y + 1)
	return Rect2i(left, top, right - left, bottom - top)


func _test_hero_geometry() -> void:
	var saved_data: Dictionary = RunManager.current_hero_data.duplicate(true)
	var hero_id := "cowboy" + "_" + "bill"
	RunManager.current_hero_data = {"sprite_id": hero_id, "animate_idle": true}
	var player: Node2D = PLAYER_VIEW.new()
	add_child(player)
	var sprite: AnimatedSprite2D = player.get("_sprite")
	for animation in ["idle", "attack"]:
		for frame in range(8):
			var texture := sprite.sprite_frames.get_frame_texture(animation, frame)
			var path := "res://battle_scene/assets/images/heroes/cowboy_bill/%s/cowboy_bill_%s_%d.png" % [animation, animation, frame]
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			var bounds := _opaque_rect(image)
			var label := "%s frame %d" % [animation, frame]
			_expect(image.get_size() == Vector2i(384, 384), label + " uses a source canvas large enough for the hero")
			_expect(sprite.scale.x <= 1.0 and sprite.scale.y <= 1.0, label + " is never enlarged from too few source pixels")
			var body_height := bounds.size.y * sprite.scale.y
			_expect(body_height >= 338.0 and body_height <= 360.0, label + " is visibly taller than a 256px ordinary enemy")
			var feet := sprite.position.y + (bounds.end.y - texture.get_height() * 0.5) * sprite.scale.y
			_expect(absf(feet + 20.0) <= 1.0, label + " preserves the existing visible ground baseline")
			_expect(bounds.position.x > 4 and bounds.end.x < image.get_width() - 4, label + " keeps the complete silhouette inside the canvas")
	var hud: Control = player.get("_hud")
	_expect(hud.position == Vector2(-125, 28), "hero health bar remains anchored below the planted feet")
	var hit: Vector2 = player.call("get_hit_global_position")
	_expect(hit.y < -140.0 and hit.y > -220.0, "hit feedback follows the enlarged torso")
	player.queue_free()
	RunManager.current_hero_data = saved_data


func _test_muzzle_anchor_matches_bill_pose() -> void:
	var player: Node = PLAYER_VIEW.new()
	var constants: Dictionary = (player.get_script() as Script).get_script_constant_map()
	var anchor: Vector2 = constants.get("MUZZLE_NATIVE_POSITION", Vector2.ZERO)
	_expect(anchor.x >= 320.0 and anchor.x <= 350.0, "Bill muzzle anchor stays at the enlarged firing barrel")
	_expect(anchor.y >= 205.0 and anchor.y <= 230.0, "Bill muzzle anchor follows the enlarged firing pose")
	player.free()
