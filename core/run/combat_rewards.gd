extends RefCounted

## What a won fight gives and where the run goes next (STS2: the combat room
## ends, the run decides rewards). The battle only reports its result; this
## grants XP and the bounty event, the Caps and Scrap printed on the route
## node's card (core/run/map_generator.gd), or the boss award, equipment and
## Scrap, and returns the route the screen shows:
##   {route: "extract_choice", act, rewards: {continue, extract}}
##   {route: "demo_complete"}                 the run's final boss fell
##   {route: "loot"}                          the normal reward screen
## plus `backpack_full: true` when the boss equipment did not fit.

const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd


## `rewards`: the fought node's printed rewards, {gold, scrap}; the loot screen
## pays the gold, this pays an elite's Scrap.
static func settle_victory(node_type: String, act: int, rewards: Dictionary) -> Dictionary:
	# The boss's Caps go straight into the backpack; what does not fit is owed
	# and banked when the run settles.
	if node_type == "boss":
		var boss_gold := int(MODEL_DB.data("economy", "base:loot_economy").get("boss_gold", 45))
		RunManager.state.legacy_caps += boss_gold - RunManager.add_gold(boss_gold)
	# XP; each level gained queues an attribute pick (the loot screen consumes them).
	RunManager.gain_xp(node_type)
	# Bounty event, before a final-boss victory ends the run.
	RunManager.combat_won(node_type)
	if node_type == "boss":
		var out := {"backpack_full": not RunManager.add_equip_to_backpack(RunManager.roll_shell_drop("rare"))}
		var extract: Dictionary = ACTS.extract_rewards(act)
		if not extract.is_empty():
			out["route"] = "extract_choice"
			out["act"] = act
			out["rewards"] = extract
			return out
		# Final boss: the Scrap drops into the backpack and is banked when the run
		# ends, so end_run_victory banks 0 more.
		RunManager.add_scrap_to_backpack(int(ACTS.run_config().get("boss_victory_scrap", 130)))
		RunManager.end_run_victory(0, "victory")
		out["route"] = "demo_complete"
		return out
	if node_type == "elite":
		RunManager.add_scrap_to_backpack(int(rewards.get("scrap", 0)))
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
