extends RefCounted
class_name RelicEffectSystem

## Owns the battle's relic listeners (core/listeners/data_relic.gd, or a relic's
## own `script`): one instance per relic in RunManager.relics, built when the
## battle starts and rebuilt only when the held relics change (a relic gained
## mid-combat). Instances keep their state for relics that stay held. The hook
## broadcaster asks `current_listeners()` on every dispatch.

const DATA_RELIC = preload("uid://dtkuqabpxc64u")  # res://core/listeners/data_relic.gd

var _battle_scene: Object
var _listeners: Array = []
var _built_for: Array = []  # relic ids the listeners were built for


func setup(battle_scene: Object) -> void:
	_battle_scene = battle_scene
	_listeners.clear()
	_built_for.clear()


func current_listeners(hooks) -> Array:
	var held: Array = RunManager.relics.duplicate() if RunManager.is_run_active else []
	if held != _built_for:
		_rebuild(held)
	for listener in _listeners:
		listener.hooks = hooks
	return _listeners


func _rebuild(held: Array) -> void:
	var previous := {}
	for listener in _listeners:
		previous[listener.id] = listener
	_listeners = []
	for relic_id in held:
		var id := str(relic_id)
		if previous.has(id):
			_listeners.append(previous[id])
			previous.erase(id)
			continue
		var data: Dictionary = RunManager.get_relic_data(id)
		var script_path := str(data.get("script", ""))
		var listener = (load(script_path) if script_path != "" else DATA_RELIC).new()
		listener.id = id
		listener.data = data
		listener.battle = _battle_scene
		_listeners.append(listener)
	_built_for = held
