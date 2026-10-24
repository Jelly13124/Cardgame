extends Node

## Golden snapshot of every card's text and resolved effects, base and upgraded,
## in both locales and with/without player stats. Phase 4 moves the description
## and upgrade code; this test pins the output to what main produced.
## Run with CAPTURE_GOLDEN=1 to (re)write the fixture.

const CARD_FACTORY = preload("uid://diap3gdfbqvjv")  # res://battle_scene/my_card_factory.tscn
const CARD_UPGRADE = preload("uid://d2e2bfj6oa3yp")  # res://run_system/core/card_upgrade.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const FIXTURE := "res://tests/fixtures/golden/cards.json"

## Read by play_card._get_player_stats through get_tree().current_scene.
var player: Node = null
var failures: PackedStringArray = []


class Stats:
	extends Node
	var strength := 2
	var constitution := 3
	var intelligence := 1
	var luck := 4
	var charm := 2


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	get_tree().current_scene = self
	var factory = CARD_FACTORY.instantiate()
	add_child(factory)
	await get_tree().process_frame
	var snapshot := {}
	for locale in ["en", "zh"]:
		TranslationServer.set_locale(locale)
		for profile in ["plain", "stats"]:
			player = Stats.new() if profile == "stats" else null
			if player:
				add_child(player)
			for card_id in MODEL_DB.ids("card"):
				var key := "%s|%s|%s" % [locale, profile, card_id]
				var base: Dictionary = MODEL_DB.mutable("card", card_id)
				var upgraded: Dictionary = CARD_UPGRADE.resolve(base)
				snapshot[key] = {
					"text": await _text(factory, card_id, base),
					"up_text": await _text(factory, card_id, upgraded),
					"effects": JSON.stringify(base.get("effects", [])),
					"up_effects": JSON.stringify(upgraded.get("effects", [])),
					"up_cost": str(int(upgraded.get("cost", 0))),
				}
			if player:
				player.queue_free()
				player = null
	TranslationServer.set_locale("en")

	if OS.get_environment("CAPTURE_GOLDEN") == "1":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE.get_base_dir()))
		var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
		f.store_string(JSON.stringify(snapshot, "  ", true))
		f.close()
		print("[OK] golden captured: %d entries" % snapshot.size())
		get_tree().quit(0)
		return

	var golden: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if typeof(golden) != TYPE_DICTIONARY:
		failures.append("golden fixture missing")
	else:
		for key in golden:
			if not snapshot.has(key):
				failures.append("%s missing now" % key)
				continue
			for field in golden[key]:
				if str(golden[key][field]) != str(snapshot[key][field]):
					failures.append("%s %s:\n  was: %s\n  now: %s" % [key, field, golden[key][field], snapshot[key][field]])
		for key in snapshot:
			if not golden.has(key):
				failures.append("%s new card not in golden" % key)
	if failures.is_empty():
		print("[OK] card text golden passed (%d entries)" % snapshot.size())
		get_tree().quit(0)
		return
	for line in failures.slice(0, 20):
		print("[FAIL] ", line)
	push_error("card text golden failed: %d differences" % failures.size())
	get_tree().quit(1)


func _text(factory, card_id: String, info: Dictionary) -> String:
	var card = factory.create_card(card_id, null)
	card.set_card_data(info)
	await get_tree().process_frame
	# The visible text and the BBCode the card face renders (colours included).
	var text: String = card.desc_label.get_parsed_text() + "\n--bbcode--\n" + _bbcode(card, info)
	card.free()
	return text


## The card face's BBCode for `info` (the generator's output).
func _bbcode(card, info: Dictionary) -> String:
	return card._colorize_keywords(card._build_description(info))
