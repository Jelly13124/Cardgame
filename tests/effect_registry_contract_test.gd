extends Node

## Contract for core/effects: one registry maps effect types to handlers per
## context ("combat", "enemy", "run"); event options run through it.

const EFFECT_REGISTRY = preload("uid://7gab4te60cto")  # res://core/effects/effect_registry.gd
const EFFECT_CONTEXT = preload("uid://bx2g3askncfr6")  # res://core/effects/effect_context.gd
const RUN_EFFECTS = preload("uid://divb5pd0mx4cc")  # res://core/effects/run_effects.gd
const DATA_VALIDATOR = preload("uid://bdhbhkhs5p4v3")  # res://battle_scene/data_validator.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var registry = EFFECT_REGISTRY.new()
	RUN_EFFECTS.register_into(registry)
	for event_type in DATA_VALIDATOR.ALLOWED_EVENT_EFFECT_TYPES:
		_expect(registry.has_type(event_type, "run"), "run registry handles event effect %s" % event_type)
	_expect(not registry.has_type("overload", "run"), "combat-only effects are not run effects")
	_expect(registry.types("run").size() == DATA_VALIDATOR.ALLOWED_EVENT_EFFECT_TYPES.size(), "run registry has no extra types")

	var gold_before: int = RunManager.gold
	var ctx = EFFECT_CONTEXT.new()
	ctx.kind = "run"
	await registry.execute(ctx, {"type": "gain_gold", "amount": 7})
	_expect(RunManager.gold == gold_before + 7, "run gain_gold adds 7 gold (got %d)" % (RunManager.gold - gold_before))
	RunManager.apply_event_effects([{"type": "gain_gold", "amount": 3}])
	_expect(RunManager.gold == gold_before + 10, "event options use the registry")
	RunManager.gold = gold_before

	if failures.is_empty():
		print("[OK] effect registry contract passed")
		get_tree().quit(0)
		return
	push_error("effect registry contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)
