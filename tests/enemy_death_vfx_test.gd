extends Node

## An enemy's death (STS2 NMonsterDeathVfx): the view leaves at once, as the
## combat rules expect, while a snapshot of its sprite dissolves through noise
## and sheds drifting flakes, then cleans itself up.

const BATTLE_SCENE = preload("uid://dnhj5pp3c1v2l")  # res://ui/battle/battle_screen.tscn
const DEATH_VFX = preload("uid://cayme2wbim86o")  # res://ui/battle/enemy_death_vfx.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	await test_death_dissolves_a_snapshot_and_cleans_up()
	if failures.is_empty():
		print("[OK] enemy death vfx passed")
		get_tree().quit(0)
		return
	push_error("enemy death vfx failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func test_death_dissolves_a_snapshot_and_cleans_up() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "DEATH001")
	RunManager.current_encounter = ["base:scrap_rat", "base:hex_drone"]
	RunManager.last_battle_node_type = "enemy"
	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	for _i in range(30):
		await get_tree().process_frame

	var enemy = battle.enemy_container.get_child(0)
	var sprite_pos: Vector2 = enemy._sprite.global_position
	enemy.play_death()
	_expect(enemy.is_queued_for_deletion(), "the enemy view leaves immediately")

	var vfx: Node = battle.find_child("EnemyDeathVfx*", true, false)
	_expect(vfx != null, "a death effect is spawned in the battle")
	if vfx == null:
		_finish(battle)
		return
	_expect(vfx.get_parent() != battle.enemy_container, "the effect is not counted as an enemy")
	var body: Sprite2D = vfx.get_node_or_null("Body")
	_expect(body != null and body.texture != null, "the effect shows a snapshot of the enemy sprite")
	if body:
		_expect(body.global_position.distance_to(sprite_pos) < 1.0, "the snapshot stands where the enemy stood")
		_expect(body.material is ShaderMaterial, "the snapshot dissolves through a shader")
	var flakes: CPUParticles2D = vfx.get_node_or_null("Flakes")
	_expect(flakes != null and flakes.emitting, "flakes drift off the body")

	await get_tree().create_timer(DEATH_VFX.DISSOLVE_SECONDS * 0.5).timeout
	if body and is_instance_valid(body):
		var progress: float = float((body.material as ShaderMaterial).get_shader_parameter("progress"))
		_expect(progress > 0.05 and progress < 1.0, "halfway through, the body is partly dissolved (%.2f)" % progress)

	await get_tree().create_timer(DEATH_VFX.LIFETIME_SECONDS).timeout
	_expect(not is_instance_valid(vfx), "the effect frees itself when done")
	_finish(battle)


func _finish(battle: Node) -> void:
	get_tree().current_scene = null
	battle.queue_free()
