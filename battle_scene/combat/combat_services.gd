extends RefCounted

## Wires the combat pipeline onto a battle: hook dispatcher with its rule and
## content listeners, the command layer and the effect registry. The battle
## (or a test stand-in) declares `combat_hooks`, `combat_commands`,
## `effect_registry`, `crit_rules`, `relic_effect_system` and
## `equipment_set_system`; install() fills the first four and registers the
## relic / set systems as listeners. Listener order is fixed: attributes,
## statuses, crits, relics, equipment sets.

const COMBAT_HOOKS = preload("uid://cjb2wdqhw4j2x")  # res://core/combat/combat_hooks.gd
const ATTRIBUTE_RULES = preload("uid://ctdg0fm8xx4bv")  # res://core/combat/rules/attribute_rules.gd
const STATUS_RULES = preload("uid://b8rsme8h88mxo")  # res://core/combat/rules/status_rules.gd
const CRIT_RULES = preload("uid://bjfqp2irnmi37")  # res://core/combat/rules/crit_rules.gd
const EFFECT_REGISTRY = preload("uid://7gab4te60cto")  # res://core/effects/effect_registry.gd
const COMBAT_COMMANDS = preload("uid://drt6iikiv1eri")  # res://battle_scene/combat/combat_commands.gd
const COMBAT_EFFECTS = preload("uid://do16of5onpg33")  # res://battle_scene/combat/combat_effects.gd


static func install(battle: Object) -> void:
	var relics = battle.get("relic_effect_system")
	var sets = battle.get("equipment_set_system")

	var hooks = COMBAT_HOOKS.new()
	var commands = COMBAT_COMMANDS.new()
	commands.battle = battle
	commands.hooks = hooks
	hooks.commands = commands

	var status_rules = STATUS_RULES.new()
	status_rules.hooks = hooks
	status_rules.relics = relics
	var crit_rules = CRIT_RULES.new()
	crit_rules.relics = relics

	hooks.add_listener(ATTRIBUTE_RULES.new())
	hooks.add_listener(status_rules)
	hooks.add_listener(crit_rules)
	if relics:
		hooks.add_listener(relics)
	if sets:
		hooks.add_listener(sets)

	var registry = EFFECT_REGISTRY.new()
	COMBAT_EFFECTS.register_into(registry)

	battle.set("combat_hooks", hooks)
	battle.set("combat_commands", commands)
	battle.set("effect_registry", registry)
	battle.set("crit_rules", crit_rules)
