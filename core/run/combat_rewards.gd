extends RefCounted

## What a won fight gives and where the run goes next (STS2: the combat room
## ends, the run decides rewards). The battle only reports its result; this
## grants Caps, XP and the bounty event, the boss equipment and Scrap or the
## elite Scrap, and returns the route the screen shows:
##   {route: "extract_choice", act, rewards: {continue, extract}}
##   {route: "demo_complete"}                 the run's final boss fell
##   {route: "loot"}                          the normal reward screen
## plus `backpack_full: true` when the boss equipment did not fit.

const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd


static func settle_victory(node_type: String, act: int) -> Dictionary:
	# Caps stay at death risk until banked; a boss grants only the boss award.
	RunManager.award_caps_for_combat(node_type)
	# A card draft per level gained (the loot screen consumes them).
	RunManager.gain_xp(node_type)
	# Bounty event, before a final-boss victory ends the run.
	RunManager.combat_won(node_type)
	if node_type == "boss":
		var out := {"backpack_full": not RunManager.add_equip_to_backpack(RunManager.roll_shell_drop("rare"))}
		var rewards: Dictionary = ACTS.extract_rewards(act)
		if not rewards.is_empty():
			out["route"] = "extract_choice"
			out["act"] = act
			out["rewards"] = rewards
			return out
		# Final boss: the Scrap drops into the backpack and is banked when the run
		# ends, so end_run_victory banks 0 more.
		RunManager.add_scrap_to_backpack(int(ACTS.run_config().get("boss_victory_scrap", 130)))
		RunManager.end_run_victory(0, "victory")
		out["route"] = "demo_complete"
		return out
	if node_type == "elite":
		var scrap: Array = MODEL_DB.data("economy", "base:loot_economy").get("elite_scrap", [8, 16])
		RunManager.add_scrap_to_backpack(RunManager.rng("rewards").next_range(int(scrap[0]), int(scrap[1])))
	return {"route": "loot", "backpack_full": false}


## The player chose after a non-final boss: extract ends the run with the
## extract Scrap ("home"); pushing on takes the continue Scrap into the next
## act and the normal loot ("loot").
static func choose_extract(extract: bool, rewards: Dictionary) -> String:
	if extract:
		RunManager.add_scrap_to_backpack(int(rewards.get("extract", 0)))
		RunManager.end_run_victory(0, "extracted")
		return "home"
	RunManager.add_scrap_to_backpack(int(rewards.get("continue", 0)))
	RunManager.advance_act()
	return "loot"
