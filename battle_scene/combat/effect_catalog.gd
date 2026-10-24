extends RefCounted

## One shared effect registry with every combat, enemy and run effect type and
## its definition, for code that runs outside a battle: the validator, card UI,
## the upgrade resolver, discover. Battles build their own registry the same way
## (combat_services). No class_name — preload.

const EFFECT_REGISTRY = preload("uid://7gab4te60cto")  # res://core/effects/effect_registry.gd
const COMBAT_EFFECTS = preload("uid://do16of5onpg33")  # res://battle_scene/combat/combat_effects.gd
const RUN_EFFECTS = preload("uid://divb5pd0mx4cc")  # res://core/effects/run_effects.gd

static var _registry = null


static func registry():
	if _registry == null:
		_registry = EFFECT_REGISTRY.new()
		COMBAT_EFFECTS.register_into(_registry)
		RUN_EFFECTS.register_into(_registry)
	return _registry


## Drop the shared registry (tests that registered fixture types).
static func reset() -> void:
	_registry = null
