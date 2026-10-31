extends RefCounted

## Base class of every scripted event (STS2 EventModel). An event is a small
## state machine: `page` names the text shown, `current_options` the choices.
## An option's callable changes run state, then moves to another page with
## `set_event_state` or ends the event with `set_event_finished`.
## Instances come from EventPool, which sets `id`, `owner` and `rng`.
## No class_name — preload.

const EVENT_OPTION = preload("uid://cdoxam5bb6ye8")  # res://core/run/events/event_option.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const EFFECT_REGISTRY = preload("uid://7gab4te60cto")  # res://core/effects/effect_registry.gd
const EFFECT_CONTEXT = preload("uid://bx2g3askncfr6")  # res://core/effects/effect_context.gd
const RUN_EFFECTS = preload("uid://divb5pd0mx4cc")  # res://core/effects/run_effects.gd

signal state_changed

var id: String
## The run facade (RunManager). Scripts read run state through it.
var owner
## The run's `events` stream.
var rng
## Numbers the copy shows and the effects use; text substitutes `{name}`.
var dynamic_vars: Dictionary = {}
var page: String = "INITIAL"
var current_options: Array = []
var is_finished: bool = false
var _choosing := false

static var _run_effects = null


# --- overridden by events ------------------------------------------------------

func generate_initial_options() -> Array:
	push_error("EventModel %s: generate_initial_options not overridden" % id)
	return []


func is_allowed(_run_state) -> bool:
	return true


func calculate_vars() -> void:
	pass


## Art name for `page`; "" means the event's own art.
func page_art(_page: String) -> String:
	return ""


# --- provided to events --------------------------------------------------------

func begin() -> void:
	calculate_vars()
	page = "INITIAL"
	is_finished = false
	current_options = generate_initial_options()


func option(key: String, on_chosen: Callable) -> RefCounted:
	var opt = EVENT_OPTION.new()
	opt.key = key
	opt.text_key = text_key("OPT_" + key)
	opt.on_chosen = on_chosen
	opt.owner = owner
	return opt


## A luck check: rolls the owner's luck chance on `rng` when chosen.
func luck_option(key: String, on_success: Callable, on_fail: Callable) -> RefCounted:
	var p: float = owner.luck_check_chance()
	var opt = option(key, func():
		if rng.chance(p):
			on_success.call()
		else:
			on_fail.call()
	)
	opt.chance = p
	return opt


func set_event_state(new_page: String, options: Array) -> void:
	page = new_page
	current_options = options
	state_changed.emit()


func set_event_finished(new_page: String) -> void:
	page = new_page
	var proceed = EVENT_OPTION.new()
	proceed.key = "PROCEED"
	proceed.text_key = "UI_EVENT_CONTINUE"
	proceed.on_chosen = func(): pass
	proceed.is_proceed = true
	proceed.owner = owner
	current_options = [proceed]
	is_finished = true
	state_changed.emit()


## Run option `index` once. False when out of range, locked, re-entered, or
## after the event finished (the proceed option is handled by the room).
func choose(index: int) -> bool:
	if _choosing or is_finished or index < 0 or index >= current_options.size():
		return false
	var opt = current_options[index]
	if opt.is_locked():
		return false
	_choosing = true
	opt.on_chosen.call()
	_choosing = false
	return true


## Run-context effects through the shared registry (core/effects/run_effects.gd).
## Run handlers are synchronous: every effect has applied when this returns.
func apply(effects: Array) -> void:
	if _run_effects == null:
		_run_effects = EFFECT_REGISTRY.new()
		RUN_EFFECTS.register_into(_run_effects)
	var ctx = EFFECT_CONTEXT.new()
	ctx.kind = "run"
	for effect in effects:
		if typeof(effect) == TYPE_DICTIONARY:
			_run_effects.execute(ctx, effect)


func will_kill(damage: int) -> bool:
	return int(owner.current_health) <= damage


func text_key(suffix: String) -> String:
	return "EVENT_%s_%s" % [MODEL_ID.entry_of(id).to_upper(), suffix]


func format(text: String) -> String:
	return text.format(dynamic_vars)
