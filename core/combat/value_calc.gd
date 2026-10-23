extends RefCounted

## One value moving through the pipeline (combat_hooks.compute_*): a damage
## hit, a block gain or a status application. Listeners read the context and
## adjust `value`; anything that spends state (Deadeye, once-per-combat relics,
## crit side effects) is queued with `on_commit` and runs only when the command
## calls `commit()` — preview calculations never commit.

const VALUE_PROPS = preload("uid://cccfcqt180t4x")  # res://core/combat/value_props.gd

var kind: String = ""  # "damage" | "block" | "status"
var value: float = 0.0
var base: int = 0
var source = null  # combat_source.gd
var dealer: Object = null
var target: Object = null
var props: int = 0
var preview: bool = false
var play = null  # card_play.gd, or null outside a card play
## Effect-level additive bonus (Loaded): added in the additive stage when powered.
var flat_bonus: int = 0
var critical: bool = false
## Effect-specific markers, e.g. {"overload": true}.
var tags: Dictionary = {}
var status: String = ""
var effect_type: String = ""
var _commits: Array[Callable] = []


static func for_damage(
	p_source, p_target: Object, p_base: int, p_props: int, p_preview: bool, p_play = null
) -> RefCounted:
	var calc = new()
	calc._init_common("damage", p_source, p_target, p_base, p_props, p_preview)
	calc.play = p_play
	return calc


static func for_block(p_source, creature: Object, p_base: int, p_props: int, p_preview: bool) -> RefCounted:
	var calc = new()
	calc._init_common("block", p_source, creature, p_base, p_props, p_preview)
	return calc


static func for_status(
	p_source, p_target: Object, p_status: String, stacks: int, p_effect_type: String, p_preview: bool
) -> RefCounted:
	var calc = new()
	calc._init_common("status", p_source, p_target, stacks, 0, p_preview)
	calc.status = p_status
	calc.effect_type = p_effect_type
	return calc


func _init_common(
	p_kind: String, p_source, p_target: Object, p_base: int, p_props: int, p_preview: bool
) -> void:
	kind = p_kind
	source = p_source
	dealer = p_source.dealer if p_source else null
	target = p_target
	base = p_base
	value = float(p_base)
	props = p_props
	preview = p_preview


func has(flag: int) -> bool:
	return (props & flag) != 0


func is_powered() -> bool:
	return has(VALUE_PROPS.POWERED)


## True when the dealer acts for the player side.
func from_player() -> bool:
	return source != null and source.side == "player"


func on_commit(action: Callable) -> void:
	_commits.append(action)


func commit() -> void:
	var pending := _commits
	_commits = []
	for action in pending:
		action.call()
