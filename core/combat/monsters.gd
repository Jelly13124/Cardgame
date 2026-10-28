extends RefCounted

## Builds an enemy creature from its monster definition (STS2 MonsterModel →
## Creature): display name, HP after ascension and act scaling, elite/boss
## flags and its move state machine.

const CREATURE = preload("uid://kab2636ev63e")  # res://core/combat/creature.gd
const MONSTER_MOVES = preload("uid://bqwa1txur3b52")  # res://core/combat/monster_moves.gd
const MODEL_DB = preload("uid://8k42t37sefpw")  # res://core/content/model_db.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const ACTS = preload("uid://c7qo73muxvmd4")  # res://core/run/acts.gd


static func create(id: String) -> RefCounted:
	var c = CREATURE.new()
	c.side = "enemy"
	c.enemy_id = id
	c.max_health = 30
	c.health = 30
	c.is_elite = ACTS.monster_in_room(id, "elite")
	c.is_boss = ACTS.monster_in_room(id, "boss")
	# Writable copy: action patterns and phases are per-instance runtime state.
	var data: Dictionary = MODEL_DB.mutable("monster", id)
	if data.is_empty():
		push_error("Monsters: unknown monster '%s'. Encounter will spawn a placeholder enemy." % id)
		assert(false, "Monsters: unknown monster '%s'" % id)
		c.moves = MONSTER_MOVES.new()
		return c
	# Display name routes through the content-translation table; the English
	# JSON `name` is the fallback.
	c.enemy_name = Settings.t(
		"ENEMY_%s_NAME" % MODEL_ID.key_entry(id), str(data.get("name", MODEL_ID.key_entry(id).to_upper()))
	)
	c.max_health = int(data.get("max_health", 30))
	# Tough enemies: HP scales by a percentage per ascension level.
	if RunManager.has_ascension("base:a1_tough_enemies"):
		var pct := float(RunManager.ascension_param("base:a1_tough_enemies", "hp_pct_per_level", 10))
		c.max_health = int(round(c.max_health * (1.0 + pct / 100.0 * RunManager.ascension)))
	# Per-act scaling (bosses exempt — see RunManager.scale_enemy_hp).
	c.max_health = RunManager.scale_enemy_hp(c.max_health, id)
	c.health = c.max_health
	c.moves = MONSTER_MOVES.from_data(data)
	return c


## Sprite folder id of a monster (view data).
static func sprite_id(id: String) -> String:
	return str(MODEL_DB.data("monster", id).get("sprite_id", ""))
