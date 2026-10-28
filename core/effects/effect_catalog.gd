extends RefCounted

## One shared effect registry with every combat, enemy and run effect type and
## its definition, for code that runs outside a battle: the validator, card UI,
## the upgrade resolver, discover. Battles build their own registry the same way
## (combat_services). No class_name — preload.

const EFFECT_REGISTRY = preload("uid://7gab4te60cto")  # res://core/effects/effect_registry.gd
## Loaded on first use, not preloaded: combat_effects reaches the card UI
## (discover modal → play_card → card_description), which reads this catalog.
const COMBAT_EFFECTS_PATH := "uid://do16of5onpg33"  # res://core/combat/combat_effects.gd
const RUN_EFFECTS_PATH := "uid://divb5pd0mx4cc"  # res://core/effects/run_effects.gd

static var _registry = null


static func registry():
	if _registry == null:
		_registry = EFFECT_REGISTRY.new()
		load(COMBAT_EFFECTS_PATH).register_into(_registry)
		load(RUN_EFFECTS_PATH).register_into(_registry)
	return _registry


## Drop the shared registry (tests that registered fixture types).
static func reset() -> void:
	_registry = null
