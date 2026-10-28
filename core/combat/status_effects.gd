## StatusEffectSystem is shared by PlayerEntity and EnemyEntity. It stores
## stacks, applies each status's decay rule from its definition
## (content/statuses, ModelDb category "status") and owns one listener instance
## per active status whose definition names a `script`
## (core/listeners/statuses/<key>.gd). Behaviour lives in those listeners; this
## class keeps storage and owner-scoped turn phases; the badges are
## ui/battle/status_badges_view.gd.
## Runtime keys are MODEL_ID.key_entry(status id): base statuses use bare names.
extends RefCounted
class_name StatusEffectSystem

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd

var _statuses: Dictionary = {}
var _listeners: Dictionary = {}  # key -> listener instance, in application order
## Deals status damage (Burn) through the combat pipeline:
## func(entity, amount: int, status: String). Unset in tests that use a bare
## entity; then the entity takes the damage directly.
var damage_router: Callable


static func format_name(status_name: String) -> String:
	return status_name.replace("_", " ").capitalize()


## Localized status display name for player-facing notifications/tooltips.
## Falls back to the English-capitalized format_name() for any status without a
## UI_COMBAT_STATUS_* row.
static func format_name_localized(status_name: String) -> String:
	var key := "UI_COMBAT_STATUS_%s" % status_name.to_upper()
	var localized := TranslationServer.translate(key)
	if localized == key:
		return format_name(status_name)
	return localized


## Definition of a runtime status key, or {}.
static func status_def(key: String) -> Dictionary:
	for model in MODEL_DB.models("status"):
		if MODEL_ID.key_entry(model.id) == key:
			return model.data
	return {}


## Runtime keys of every defined status.
static func status_keys() -> Array:
	return MODEL_DB.ids("status").map(func(i): return MODEL_ID.key_entry(i))


static func status_color(key: String) -> Color:
	var hex := str(status_def(key).get("color", ""))
	return Color.html(hex) if hex != "" else Color.WHITE


static func status_label(key: String) -> String:
	return str(status_def(key).get("label", key))


## English fallback for UI_COMBAT_STATUS_<KEY>_DESC.
static func status_description(key: String) -> String:
	return str(status_def(key).get("description", ""))


## Stacks of every active status, by runtime key (a copy, for views).
func snapshot() -> Dictionary:
	return _statuses.duplicate()


func add_status(status_name: String, stacks: int, entity: Object) -> void:
	if stacks <= 0:
		return
	status_name = _canonicalize_status_name(status_name)
	_statuses[status_name] = _statuses.get(status_name, 0) + stacks
	_ensure_listener(status_name, entity)
	_on_statuses_changed(entity)


func remove_status(status_name: String, entity: Object) -> void:
	status_name = _canonicalize_status_name(status_name)
	if not _statuses.has(status_name):
		return
	_clear(status_name)
	_on_statuses_changed(entity)


func get_stacks(status_name: String) -> int:
	status_name = _canonicalize_status_name(status_name)
	return _statuses.get(status_name, 0)


func has_status(status_name: String) -> bool:
	status_name = _canonicalize_status_name(status_name)
	return _statuses.get(status_name, 0) > 0


## Listener instances of this creature's active statuses, in key order (stable
## and independent of application order, so turn-start effects keep a fixed
## sequence: Burn before Regen).
func listeners() -> Array:
	var keys := _listeners.keys()
	keys.sort()
	return keys.map(func(k): return _listeners[k])


## Owner's turn start (before its energy/Block reset): Burn, Regen.
func on_turn_start(entity: Object) -> void:
	for listener in listeners():
		if listener.has_method("at_owner_turn_start"):
			listener.at_owner_turn_start(entity)


## Owner's turn start, after Block was reset (Metallicize).
func after_owner_block_reset(entity: Object) -> void:
	for listener in listeners():
		if listener.has_method("after_owner_block_reset"):
			listener.after_owner_block_reset(entity)


## Owner's turn end: statuses whose definition decays at turn end lose 1.
func on_turn_end(entity: Object) -> void:
	_decay("turn_end", entity)


## The owner's opponent ended its turn (Intangible).
func on_opponent_turn_end(entity: Object) -> void:
	_decay("opponent_turn_end", entity)


## Consume one stack of stun. Returns true if a stack was consumed
## (caller should treat this as "the action is stunned, skip it").
## Stun is manual-consume: it does NOT decay on its own.
func consume_stun(entity: Object) -> bool:
	if not has_status("stun"):
		return false
	spend_stacks("stun", 1, entity)
	_notify(entity, "STUNNED", status_color("stun"))
	return true


## Spend N stacks of a status (min 0). Used by triggers that decay on use,
## e.g. Thorns loses 1 stack each time it reflects an attack.
func spend_stacks(status_name: String, n: int, entity: Object) -> void:
	status_name = _canonicalize_status_name(status_name)
	if not _statuses.has(status_name):
		return
	_statuses[status_name] -= n
	if _statuses[status_name] <= 0:
		_clear(status_name)
	_on_statuses_changed(entity)


## Set a status to exactly `n` stacks (0 removes it).
func set_stacks(status_name: String, n: int, entity: Object) -> void:
	status_name = _canonicalize_status_name(status_name)
	if n <= 0:
		remove_status(status_name, entity)
		return
	_statuses[status_name] = n
	_ensure_listener(status_name, entity)
	_on_statuses_changed(entity)


## Status damage-over-time (Burn) through the combat pipeline when a router is
## set; a bare entity (tests) takes it directly. Kept here because the hit sound
## is presentation.
func deal_status_damage(entity: Object, dmg: int, status: String) -> void:
	if damage_router.is_valid():
		damage_router.call(entity, dmg, status)
		AudioManager.play_sfx("attack_hit", -4.0, 1.18, 0.03)
	elif entity.has_method("take_damage"):
		# DoT uses the same ordered feedback/readout, while source="status" keeps
		# it detached from attack-only triggers such as Thorns.
		entity.take_damage(dmg, false, {"source": "status", "status": status, "critical": false})
		AudioManager.play_sfx("attack_hit", -4.0, 1.18, 0.03)


func _decay(rule: String, entity: Object) -> void:
	var changed := false
	for key in _statuses.keys():
		if str(status_def(key).get("decay", "none")) != rule:
			continue
		_statuses[key] -= 1
		changed = true
		if _statuses[key] <= 0:
			_clear(key)
			_notify(entity, "%s FADED" % format_name(key).to_upper(), status_color(key))
	if changed:
		_on_statuses_changed(entity)


func _ensure_listener(key: String, entity: Object) -> void:
	if _listeners.has(key):
		return
	var script_path := str(status_def(key).get("script", ""))
	if script_path == "":
		return
	var listener = load(script_path).new()
	listener.owner = entity
	listener.id = key
	listener.def = status_def(key)
	listener.system = self
	_listeners[key] = listener


func _clear(key: String) -> void:
	_statuses.erase(key)
	_listeners.erase(key)


func _canonicalize_status_name(status_name: String) -> String:
	return status_name.to_lower()


## Center-screen yellow status text removed per UX feedback. DoT uses the local
## impact, damage number, trailing HP bar, and dedicated sound instead. Kept as a
## no-op so existing call sites don't error.
func _notify(_entity: Object, _text: String, _color: Color) -> void:
	pass


func _on_statuses_changed(entity: Object) -> void:
	if entity.has_method("notify_status_changed"):
		entity.notify_status_changed()
	elif entity.has_signal("status_changed"):
		entity.status_changed.emit()
