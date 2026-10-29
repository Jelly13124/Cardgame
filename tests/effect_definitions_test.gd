extends Node

## One definition per effect type: registering a type with its handler and
## definition is enough for the validator, enemy targeting and the upgrade
## default to pick it up.

const EFFECT_CATALOG = preload("uid://880atc7mnnie")  # res://core/effects/effect_catalog.gd
const DATA_VALIDATOR = preload("uid://bdhbhkhs5p4v3")  # res://core/content/data_validator.gd
const PLAY_CARD = preload("uid://d4f71g73780ld")  # res://ui/battle/play_card.gd
const CARD_UPGRADE = preload("uid://d2e2bfj6oa3yp")  # res://core/run/card_upgrade.gd

## The card effect types the validator accepted before phase 4.
const OLD_CARD_TYPES := [
	"deal_damage", "deal_damage_all", "deal_damage_str_mult", "scale_damage_by_attacks",
	"gain_block", "gain_energy", "draw_cards", "gain_strength", "gain_constitution",
	"gain_intelligence", "gain_luck", "gain_charm", "apply_status", "apply_status_self",
	"apply_status_all", "apply_short_circuit_scaled", "apply_stun", "apply_stun_all",
	"exhaust_self", "flip_polarity", "lose_hp", "double_strength", "overload",
	"deal_damage_block_mult", "gain_gold", "heal", "gain_attack_allowance",
	"restore_attack_allowance", "add_card_to_hand", "lose_gold", "add_curse_to_deck", "discover",
]

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	var card_types: Array = Array(DATA_VALIDATOR.allowed_card_effect_types())
	card_types.sort()
	var old := OLD_CARD_TYPES.duplicate()
	old.sort()
	_expect(card_types == old, "card effect types come from the definitions: %s" % [card_types])
	_expect(EFFECT_CATALOG.registry().targets_enemy("apply_stun", "combat"), "stun needs an enemy target")
	_expect(not EFFECT_CATALOG.registry().targets_enemy("gain_block", "combat"), "block needs no target")

	EFFECT_CATALOG.registry().register(
		"zap_fixture", func(_ctx, _e): pass, ["combat"],
		{"target": "enemy", "params": ["amount"], "upgrade": {"amount": 1}}
	)
	var card := {"id": "test:zap", "title": "Zap", "type": "attack", "cost": 1,
		"effects": [{"type": "zap_fixture", "amount": 4}]}
	_expect(DATA_VALIDATOR.validate_card(card, "fixture"), "validator accepts the registered type")
	_expect(PLAY_CARD.data_requires_enemy_target(card), "targeting comes from the definition")
	_expect(int(CARD_UPGRADE.resolve(card)["effects"][0]["amount"]) == 5, "upgrade default comes from the definition")
	var missing := {"id": "test:zap", "title": "Zap", "type": "attack", "cost": 1, "effects": [{"type": "zap_fixture"}]}
	_expect(not DATA_VALIDATOR.validate_card(missing, "fixture-missing"), "required params enforced")
	EFFECT_CATALOG.reset()

	if failures.is_empty():
		print("[OK] effect definitions passed")
		get_tree().quit(0)
		return
	push_error("effect definitions failed: %s" % "; ".join(failures))
	get_tree().quit(1)
