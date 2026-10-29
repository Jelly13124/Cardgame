extends Node

## A won fight reports only its result; the run layer
## (core/run/combat_rewards.gd) grants the rewards and picks the route:
## normal → loot, elite → loot + Scrap, non-final boss → extract choice with
## the act's rewards, final boss → demo complete (run ends).

const COMBAT_REWARDS = preload("uid://sn83hwnx1w3b")  # res://core/run/combat_rewards.gd
const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _run() -> void:
	RunManager.start_new_run("base:cowboy_bill", [], 0, "ROUTES0001")
	var scrap_before := RunManager.total_run_scrap()
	_expect(COMBAT_REWARDS.settle_victory("enemy", 1)["route"] == "loot", "a normal fight goes to the loot screen")
	_expect(RunManager.total_run_scrap() == scrap_before, "a normal fight drops no Scrap")
	_expect(COMBAT_REWARDS.settle_victory("elite", 1)["route"] == "loot", "an elite goes to the loot screen")
	var elite_scrap := RunManager.total_run_scrap() - scrap_before
	_expect(elite_scrap >= 8 and elite_scrap <= 16, "an elite drops 8–16 Scrap (%d)" % elite_scrap)

	ACTS.active_run = "base:full"
	var route: Dictionary = COMBAT_REWARDS.settle_victory("boss", 1)
	_expect(route["route"] == "extract_choice", "a non-final boss offers the extract choice (%s)" % route["route"])
	var rewards: Dictionary = route.get("rewards", {})
	_expect(
		int(rewards.get("continue", 0)) == 26 and int(rewards.get("extract", 0)) == 40,
		"act 1's extract rewards come from its data (%s)" % rewards
	)
	_expect(COMBAT_REWARDS.choose_extract(false, route["rewards"]) == "loot" and RunManager.current_act == 2, "pushing on enters act 2")
	ACTS.active_run = ACTS.ACTIVE_RUN

	RunManager.current_act = 1
	route = COMBAT_REWARDS.settle_victory("boss", 1)
	_expect(route["route"] == "demo_complete", "the demo's final boss completes the run (%s)" % route["route"])
	_expect(not RunManager.is_run_active, "the run ended")
	RunManager.clear_run_save()
	if failures.is_empty():
		print("[OK] combat rewards route passed")
		get_tree().quit(0)
		return
	push_error("combat rewards route failed: %s" % "; ".join(failures))
	get_tree().quit(1)
