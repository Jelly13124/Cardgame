extends RefCounted

## Run-context effects: random-event options outside combat. Each handler is
## the RunManager mutation the option names.

const RUN := ["run"]


static func register_into(registry) -> void:
	registry.register("gain_gold", _gain_gold, RUN)
	registry.register("lose_hp", _lose_hp, RUN)
	registry.register("heal", _heal, RUN)
	registry.register("gain_scrap", _gain_scrap, RUN)
	registry.register("gain_relic", _gain_relic, RUN)
	registry.register("gain_equipment", _gain_equipment, RUN)
	registry.register("gain_attribute", _gain_attribute, RUN)
	registry.register("add_curse", _add_curse, RUN)


static func _gain_gold(_ctx, effect: Dictionary) -> void:
	RunManager.add_gold(int(effect.get("amount", 0)))


static func _lose_hp(_ctx, effect: Dictionary) -> void:
	RunManager.modify_health(-int(effect.get("amount", 0)))


static func _heal(_ctx, effect: Dictionary) -> void:
	RunManager.modify_health(int(effect.get("amount", 0)))


static func _gain_scrap(_ctx, effect: Dictionary) -> void:
	RunManager.add_scrap_to_backpack(int(effect.get("amount", 0)))


static func _gain_relic(_ctx, effect: Dictionary) -> void:
	RunManager.add_relic(str(effect.get("id", "")))


static func _gain_equipment(_ctx, effect: Dictionary) -> void:
	var rarity := str(effect.get("rarity", ""))
	if rarity != "":
		RunManager.add_equip_to_backpack(RunManager.roll_shell_drop(rarity))


static func _gain_attribute(_ctx, effect: Dictionary) -> void:
	RunManager.grant_attribute(str(effect.get("attr", "")), int(effect.get("amount", 0)))


## Permanent curse onto the run deck (clearable at the shop's card removal).
static func _add_curse(_ctx, effect: Dictionary) -> void:
	RunManager.add_card_to_deck(str(effect.get("curse", "base:radiation_dust")))
