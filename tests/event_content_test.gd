extends Node

## Every scripted event plays to its end (phase 9a): each first-page option,
## both luck branches, every text key in en and zh, and effect parity with the
## old option JSON.

const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const EVENT_POOL = preload("uid://dr3dtuxwul371")  # res://core/run/events/event_pool.gd
const EVENT_ROOM = preload("res://ui/events/event_room.gd")
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
	_test_rad_storm()
	await _test_rad_storm_lethal_dig_ends_run()
	_test_cursed_safe()

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


func _curses(card_id: String) -> int:
	var n := 0
	for entry in RunManager.player_deck:
		if str(entry.get("card_id", "") if entry is Dictionary else entry) == card_id:
			n += 1
	return n


func _option(model, key: String):
	for opt in model.current_options:
		if opt.key == key:
			return opt
	return null


func _choose_key(model, key: String) -> bool:
	for i in model.current_options.size():
		if model.current_options[i].key == key:
			return model.choose(i)
	return false


func _test_rad_storm() -> void:
	var model = _fresh("base:rad_storm")
	RunManager.max_health = 80
	RunManager.current_health = 80
	model.rng = _ForcedRng.new(1.0)
	var scrap: int = RunManager.total_run_scrap()
	_choose_key(model, "SPRINT")
	_expect(model.page == "BUNKER", "a successful sprint reaches BUNKER, got %s" % model.page)
	_expect(RunManager.total_run_scrap() == scrap + 20, "the sprint gives 20 scrap")
	var hp: int = RunManager.current_health
	for i in 3:
		_choose_key(model, "DIG")
	_expect(RunManager.total_run_scrap() == scrap + 50, "three digs give 30 more scrap")
	_expect(RunManager.current_health == hp - (3 + 5 + 7), "digs cost 3, 5 and 7 HP, lost %d" % (hp - RunManager.current_health))
	_expect(not model.is_finished, "digging keeps the event open")
	_choose_key(model, "LEAVE")
	_expect(model.is_finished, "LEAVE finishes")

	model = _fresh("base:rad_storm")
	model.rng = _ForcedRng.new(1.0)
	_choose_key(model, "SPRINT")
	RunManager.current_health = 9 + 3
	_choose_key(model, "DIG")  # takes 3 -> HP 9, rad becomes 5
	_expect(model.page == "BUNKER", "HP 9 against rad 5 is still BUNKER")
	_choose_key(model, "DIG")  # takes 5 -> HP 4, rad becomes 7
	_expect(model.page == "DEATH_WARNING", "the next dig would kill: DEATH_WARNING, got %s" % model.page)
	var dig = _option(model, "DIG")
	_expect(dig != null and dig.will_kill_player, "DIG is marked lethal on DEATH_WARNING")

	model = _fresh("base:rad_storm")
	RunManager.current_health = 4
	_expect(not model.is_allowed(RunManager.state), "rad_storm is not dealt at 4 HP")
	RunManager.current_health = 5
	_expect(model.is_allowed(RunManager.state), "rad_storm is dealt at 5 HP")


## rad_storm_lethal_dig_ends_run: a lethal dig ends the run; the room shows the
## defeat screen, no proceed button, and writes no save.
func _test_rad_storm_lethal_dig_ends_run() -> void:
	var model = _fresh("base:rad_storm")
	RunManager.state.current_event = {"node_id": "n1", "event_id": "base:rad_storm", "finished": true}
	model.rng = _ForcedRng.new(1.0)
	_choose_key(model, "SPRINT")
	RunManager.current_health = 3
	model.set_event_state("DEATH_WARNING", model.dig_options())
	var room = EVENT_ROOM.new()
	room.model = model
	add_child(room)
	await get_tree().process_frame
	RunManager.clear_run_save()
	var index := -1
	for i in model.current_options.size():
		if model.current_options[i].key == "DIG":
			index = i
	room._on_option_pressed(index)
	await get_tree().process_frame
	_expect(not RunManager.is_run_active, "a lethal dig ends the run")
	_expect(not model.is_finished and not model.current_options.any(func(o): return o.is_proceed),
		"no proceed option after death")
	_expect(not RunManager.has_run_save(), "no save is written after death")
	_expect(room.find_child("ResultScreen", true, false) != null, "the room shows the defeat screen")
	room.queue_free()
	await get_tree().process_frame


func _test_cursed_safe() -> void:
	var model = _fresh("base:cursed_safe")
	var gold: int = RunManager.gold
	_choose_key(model, "CRACK")
	_expect(model.page == "OPEN" and RunManager.gold == gold, "CRACK opens the box with no gold change")
	var rust := _curses("base:rust")
	_choose_key(model, "POCKET")
	_expect(RunManager.gold == gold + 40 and _curses("base:rust") == rust + 1, "POCKET gives 40 gold and one rust")
	_expect(model.is_finished, "POCKET finishes")

	model = _fresh("base:cursed_safe")
	model.rng = _ForcedRng.new(0.0)
	_choose_key(model, "CRACK")
	var panic := _curses("base:panic")
	_choose_key(model, "PRY")
	_expect(model.is_finished and model.page == "PRY_FAIL" and _curses("base:panic") == panic + 1, "a failed PRY adds panic")

	model = _fresh("base:cursed_safe")
	_expect(model.is_allowed(RunManager.state), "cursed_safe is dealt with no curses")
	RunManager.add_card_to_deck("base:rust")
	RunManager.add_card_to_deck("base:panic")
	_expect(not model.is_allowed(RunManager.state), "cursed_safe is not dealt with two curses")


## Stands in for the events stream: chance() always answers by `p`.
class _ForcedRng:
	var p: float

	func _init(value: float) -> void:
		p = value

	func chance(_x: float) -> bool:
		return p >= 1.0
