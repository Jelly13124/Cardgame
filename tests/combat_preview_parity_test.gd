extends Node

## Parity: the targeting damage preview must equal the damage the card actually
## deals (finding S1-01). Both now run the shared pipeline; this test keeps it
## that way across Strength, Weak, Vulnerable, Loaded, Intangible and Deadeye.
## The preview runs twice before the real play to prove it changes nothing.

const FAKE_BATTLE = preload("uid://j25pi73kmisn")  # res://tests/support/fake_battle.gd
const PLAY_CARD = preload("uid://d4f71g73780ld")  # res://ui/battle/play_card.gd
const COMBAT_EFFECTS = preload("uid://do16of5onpg33")  # res://core/combat/combat_effects.gd
const COMBAT_SOURCE = preload("uid://jgs131055xrk")  # res://core/combat/combat_source.gd
const CARD_PLAY = preload("uid://bxaw24a7fumhm")  # res://core/combat/card_play.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const CARD_INSTANCE = preload("uid://c50mv4hudoncd")  # res://core/combat/card_instance.gd


## A combat card (core/combat/card_instance.gd) built from a test dictionary.
class FakeCard:
	extends CARD_INSTANCE


var failures: PackedStringArray = []
var battle


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 20.0
	RunManager.is_run_active = false
	RunManager.relics = []
	if RunManager.crit_chance() != 0.0:
		failures.append("precondition: crit chance must be 0 outside a run")
	battle = FAKE_BATTLE.new()
	add_child(battle)
	battle.setup()

	var mismatches := 0
	var compared := 0
	for card_data in _target_damage_cards():
		for strength in [0, 3]:
			for weak in [false, true]:
				for vulnerable in [false, true]:
					for loaded in [0, 2]:
						for intangible in [false, true]:
							for deadeye in [0, 1]:
								var state := [strength, weak, vulnerable, loaded, intangible, deadeye]
								var result := await _compare(card_data, state)
								compared += 1
								if result[0] != result[1]:
									mismatches += 1
									print(
										"MISMATCH %s STR=%d weak=%s vulnerable=%s loaded=%d intangible=%s deadeye=%d preview=%d actual=%d"
										% ([card_data["name"]] + state + result)
									)
	Engine.time_scale = 1.0
	print("compared %d preview/actual pairs" % compared)
	if compared < 64 * 4:
		failures.append("expected at least 4 target damage cards x 64 states (got %d pairs)" % compared)
	if mismatches > 0:
		failures.append("%d preview/actual mismatches" % mismatches)
	if failures.is_empty():
		print("[OK] combat preview parity")
		get_tree().quit(0)
		return
	print("[FAIL] ", "; ".join(failures))
	get_tree().quit(1)


func _target_damage_cards() -> Array:
	var cards: Array = []
	for card_id in MODEL_DB.ids("card"):
		var data: Variant = MODEL_DB.mutable("card", card_id)
		if typeof(data) != TYPE_DICTIONARY or not PLAY_CARD.data_requires_enemy_target(data):
			continue
		for effect in data.get("effects", []):
			if typeof(effect) == TYPE_DICTIONARY and str(effect.get("type", "")) in COMBAT_EFFECTS.DAMAGE_TYPES:
				cards.append(data)
				break
	cards.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return cards


## Returns [preview, actual] for one card under one state.
func _compare(card_data: Dictionary, state: Array) -> Array:
	var player = battle.player
	player.status_system = player.STATUS_EFFECTS.new()
	player.strength = state[0]
	player.block = 5
	if state[1]:
		player.add_status("weak", 1)
	if state[3] > 0:
		player.add_status("loaded", state[3])
	if state[5] > 0:
		player.add_status("deadeye", state[5])
	battle.clear_enemies()
	var target = battle.add_enemy()
	if state[2]:
		target.add_status("vulnerable", 1)
	if state[4]:
		target.add_status("intangible", 1)
	battle.turn_manager.attacks_played_this_turn = 1
	battle.turn_manager.attacks_played_this_combat = 2
	battle.combat_engine.reset_turn_crit()
	var card := FakeCard.new()
	card.card_info = card_data.duplicate(true)

	COMBAT_EFFECTS.preview_card_damage(battle, card, target)
	var preview: int = COMBAT_EFFECTS.preview_card_damage(battle, card, target)

	var play = CARD_PLAY.new()
	play.card = card
	play.target = target
	play.dealer = player
	var source = COMBAT_SOURCE.make("card", "player", player, card)
	for effect in card_data.get("effects", []):
		if typeof(effect) == TYPE_DICTIONARY and str(effect.get("type", "")) in COMBAT_EFFECTS.DAMAGE_TYPES:
			await battle.combat_engine.execute_effect(effect, target, source, play)
	var actual: int = target.damage_received
	return [preview, actual]
