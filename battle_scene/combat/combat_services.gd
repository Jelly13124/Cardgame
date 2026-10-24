extends RefCounted

## Wires the combat pipeline onto a battle: hook dispatcher with its rule and
## content listeners, the command layer and the effect registry. The battle
## (or a test stand-in) declares `combat_hooks`, `combat_commands`,
## `effect_registry`, `crit_rules`, `relic_effect_system` and
## `equipment_set_system`; install() fills the first four and gives the hook
## broadcaster a provider that lists, on every dispatch: attributes, the status
## listeners of every creature (player first, then enemies), crits, relics,
## equipment sets, then any extra listeners added with add_listener (tests).

const COMBAT_HOOKS = preload("uid://cjb2wdqhw4j2x")  # res://core/combat/combat_hooks.gd
const ATTRIBUTE_RULES = preload("uid://ctdg0fm8xx4bv")  # res://core/combat/rules/attribute_rules.gd
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

	var crit_rules = CRIT_RULES.new()
	crit_rules.relics = relics
	crit_rules.hooks = hooks
	var attributes = ATTRIBUTE_RULES.new()
	hooks.provider = func() -> Array:
		var out: Array = [attributes]
		out.append_array(status_listeners(battle, hooks))
		out.append(crit_rules)
		if relics:
			out.append(relics)
		if sets:
			out.append(sets)
		out.append_array(hooks.listeners)
		return out

	var registry = EFFECT_REGISTRY.new()
	COMBAT_EFFECTS.register_into(registry)

	battle.set("combat_hooks", hooks)
	battle.set("combat_commands", commands)
	battle.set("effect_registry", registry)
	battle.set("crit_rules", crit_rules)


## Status listeners of the player, then each enemy in container order.
static func status_listeners(battle: Object, hooks) -> Array:
	var creatures: Array = []
	var player = battle.get("player")
	if player != null:
		creatures.append(player)
	var container = battle.get("enemy_container")
	if container != null and is_instance_valid(container):
		creatures.append_array(container.get_children())
	var out: Array = []
	for creature in creatures:
		if not is_instance_valid(creature) or not "status_system" in creature or creature.status_system == null:
			continue
		for listener in creature.status_system.listeners():
			listener.hooks = hooks
			out.append(listener)
	return out
