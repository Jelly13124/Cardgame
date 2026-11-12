extends Node

## Regression contract for Cowboy Bill's runtime presentation.
## The authored frames are high-resolution and opaque enough to survive the
## battle backdrop, while the runtime keeps the hero at the compact combat
## height.  Idle and attack must share one baseline and anchor system.

const HERO_DIR := "res://battle_scene/assets/images/heroes/cowboy_bill/"
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
	_test_frames_are_high_res_and_not_matte_faded()
	_test_runtime_uses_one_compact_scale_and_baseline()
	_test_runtime_keeps_combat_anchors_together()
	if failures.is_empty():
		print("[OK] hero presentation contract passed")
		get_tree().quit(0)
		return
	push_error("hero presentation contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _load_frame(animation: String, frame: int) -> Image:
	var path := "%s%s/cowboy_bill_%s_%d.png" % [HERO_DIR, animation, animation, frame]
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _test_frames_are_high_res_and_not_matte_faded() -> void:
	for animation in ["idle", "attack"]:
		for frame in range(8):
			var image := _load_frame(animation, frame)
			var label := "%s frame %d" % [animation, frame]
			_expect(image != null and not image.is_empty(), label + " loads")
			if image == null or image.is_empty():
				continue
			_expect(image.get_size() == Vector2i(384, 384), label + " keeps the authored 384px canvas")
			var opaque := 0
			var semi := 0
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var alpha := image.get_pixel(x, y).a
					if alpha >= 0.90:
						opaque += 1
					elif alpha > 0.0:
						semi += 1
			_expect(opaque > 0, label + " contains visible art")
			_expect(semi * 8 <= opaque, label + " does not rely on a translucent matte")


func _test_runtime_uses_one_compact_scale_and_baseline() -> void:
	var saved_data: Dictionary = RunManager.current_hero_data.duplicate(true)
	RunManager.current_hero_data = {"sprite_id": "cowboy_bill", "animate_idle": true, "tint": "#ffffff80"}  # bare-ok: sprite id
	var player: Node2D = PLAYER_VIEW.new()
	add_child(player)
	var sprite: AnimatedSprite2D = player.get("_sprite")
	_expect(sprite != null, "animated hero sprite is built")
	if sprite == null:
		RunManager.current_hero_data = saved_data
		return
	_expect(sprite.scale.x < 0.75 and sprite.scale.y < 0.75, "hero is not enlarged from the 384px source")
	_expect(is_equal_approx(sprite.scale.x, sprite.scale.y), "hero keeps uniform display scale")
	_expect(sprite.modulate.a >= 0.99, "idle/attack runtime tint stays fully opaque")
	var bounds := _opaque_rect(_load_frame("idle", 0))
	var feet := sprite.position.y + (bounds.end.y - 192.0) * sprite.scale.y
	_expect(absf(feet + 20.0) <= 1.0, "idle feet stay on the planted baseline")
	var attack_bounds := _opaque_rect(_load_frame("attack", 0))
	var attack_feet := sprite.position.y + (attack_bounds.end.y - 192.0) * sprite.scale.y
	_expect(absf(attack_feet - feet) <= 1.0, "attack feet share the idle baseline")
	var hud: Control = player.get("_hud")
	_expect(hud != null and hud.position == Vector2(-100, 28), "health bar remains centered below the hero")
	player.queue_free()
	RunManager.current_hero_data = saved_data


func _test_runtime_keeps_combat_anchors_together() -> void:
	var player: Node = PLAYER_VIEW.new()
	var constants: Dictionary = (player.get_script() as Script).get_script_constant_map()
	var target_height := float(constants.get("TARGET_DISPLAY_HEIGHT", 0.0))
	var muzzle: Vector2 = constants.get("MUZZLE_NATIVE_POSITION", Vector2.ZERO)
	_expect(target_height >= 248.0 and target_height <= 264.0, "combat hero display height stays compact")
	_expect(muzzle.x >= 320.0 and muzzle.x <= 350.0, "muzzle anchor follows the high-resolution barrel")
	_expect(muzzle.y >= 205.0 and muzzle.y <= 230.0, "muzzle anchor follows the firing pose")
	var hit: Vector2 = player.call("get_hit_global_position")
	_expect(hit.y < -108.0 and hit.y > -120.0, "hit feedback follows the compact torso")
	player.free()


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
