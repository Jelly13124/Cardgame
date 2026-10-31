extends Node

## Every scripted event plays to its end (phase 9a): each first-page option,
## both luck branches, every text key in en and zh, and effect parity with the
## old option JSON.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const EVENT_POOL = preload("uid://dr3dtuxwul371")  # res://core/run/events/event_pool.gd
const GUARD := 20

var failures: PackedStringArray = []
## Text keys seen on every page and option reached.
var _keys := {}


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _fresh(id: String):
	RunManager.start_new_run("base:cowboy_bill", [], 0, "EVTCONT01")
	RunManager.base_attributes["charm"] = 10  # open every gate
	RunManager.recompute_attributes()
	var model = EVENT_POOL.instantiate(id)
	model.begin()
	return model


func _note_keys(model) -> void:
	_keys[model.page_text_key()] = true
	for opt in model.current_options:
		_keys[opt.text_key] = true


## Choose `index` (luck forced to `luck` when it is a luck option), then option 0
## until the event finishes or the run ends.
func _play(id: String, index: int, luck: float) -> void:
	var model = _fresh(id)
	_note_keys(model)
	var opt = model.current_options[index]
	if opt.chance >= 0.0:
		model.rng = _ForcedRng.new(luck)
	_expect(model.choose(index), "%s: option %d runs" % [id, index])
	var guard := 0
	while not model.is_finished and RunManager.is_run_active and guard < GUARD:
		_note_keys(model)
		model.choose(0)
		guard += 1
	_note_keys(model)
	_expect(model.is_finished or not RunManager.is_run_active, "%s option %d (luck %s) reaches an end" % [id, index, luck])


func _run() -> void:
	var ids: Array = MODEL_DB.ids("event")
	_expect(ids.size() == 12, "twelve events registered, got %d" % ids.size())
	for id in ids:
		_expect(MODEL_DB.event_script(id) != null, "%s has a script" % id)
		if MODEL_DB.event_script(id) == null:
			continue
		var count: int = _fresh(id).current_options.size()
		for i in count:
			_play(id, i, 1.0)
			_play(id, i, 0.0)
		_keys[EVENT_POOL.instantiate(id).text_key("TITLE")] = true

	for locale in ["en", "zh"]:
		Settings.set_language(locale)
		for key in _keys:
			if key == "UI_EVENT_CONTINUE":
				continue
			_expect(tr(key) != key and tr(key) != "", "%s has %s text" % [key, locale])
	Settings.set_language("en")

	_test_parity()

	RunManager.is_run_active = false
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] event content passed")
		get_tree().quit(0)
		return
	push_error("event content failed: %s" % "; ".join(failures))
	get_tree().quit(1)


func _test_parity() -> void:
	var model = _fresh("base:hooded_stranger")
	RunManager.current_health = RunManager.max_health - 10
	var hp: int = RunManager.current_health
	var charm := int(RunManager.player_attributes.get("charm", 0))
	model.choose(0)  # SHARE
	_expect(RunManager.current_health == hp + 8, "SHARE heals 8")
	_expect(int(RunManager.player_attributes.get("charm", 0)) == charm + 1, "SHARE adds 1 Charm")
	model = _fresh("base:stranded_trader")
	var gold: int = RunManager.gold
	model.choose(0)  # DIG
	_expect(RunManager.gold == gold + 40, "DIG gives 40 gold")


## Stands in for the events stream: chance() always answers by `p`.
class _ForcedRng:
	var p: float

	func _init(value: float) -> void:
		p = value

	func chance(_x: float) -> bool:
		return p >= 1.0
