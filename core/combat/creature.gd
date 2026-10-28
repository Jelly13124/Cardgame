extends RefCounted

## One combatant (STS2 Creature): HP, Block, attributes and statuses, plus the
## player's energy and polarity or an enemy's move state. Pure data: every
## change is synchronous and announced by a signal; views subscribe, rules
## never wait on presentation here.

const STATUS_EFFECTS = preload("uid://cq4eulp4ci8is")  # res://core/combat/status_effects.gd

signal health_changed(new_amount: int)
signal block_changed(new_amount: int)
signal energy_changed(new_amount: int)
signal stats_changed
signal status_changed
signal intent_changed
signal died
## A presentation hint the rules raise without awaiting it ("block").
signal pulse_requested(kind: String)

## "player" or "enemy".
var side: String = "player"
## Monster model id ("" for the player).
var enemy_id: String = ""
## Display name (enemies).
var enemy_name: String = "ENEMY"
var is_elite: bool = false
var is_boss: bool = false

var max_health: int = 100
var health: int = 100
var block: int = 0

## Attributes; enemies keep 0 (the attribute rules add nothing for them).
var strength: int = 0
var constitution: int = 0
var intelligence: int = 0
var luck: int = 0
var charm: int = 0

var status_system = STATUS_EFFECTS.new()

## Set once HP first reaches 0; `died` has fired.
var dead: bool = false
## Taken off the field without dying (a boss's adds when the boss falls).
var removed: bool = false

# ─── Player ───────────────────────────────────────────────────────────────────

var max_energy: int = 3
var energy: int = 3
## Strength granted until end of turn (kinetic_hammer).
var _temp_strength: int = 0

## Yin/Yang polarity (Feng Shui Master). "" = non-polarity hero: the mechanic
## stays dormant. Reaching both polarities in one turn is Harmony: until end of
## turn both count as matched.
var current_polarity: String = ""
var _polarities_seen: Array = []
var harmony_active: bool = false

# ─── Enemy ────────────────────────────────────────────────────────────────────

## Move state machine (core/combat/monster_moves.gd); null for the player.
var moves = null
## Block gained by a breakable_block move: player damage that removes all of it
## exposes this enemy to the armed status.
var _breakable_armor_active := false
var _breakable_armor_status := "vulnerable"
var _breakable_armor_stacks := 1


static func player(p_max_health: int, p_health: int) -> RefCounted:
	var c = new()
	c.side = "player"
	c.max_health = p_max_health
	c.health = p_health
	return c


func is_player() -> bool:
	return side == "player"


func is_alive() -> bool:
	return not dead and not removed and health > 0


## Applies a hit of `amount` (already through the damage pipeline): Block
## absorbs first. Returns {blocked, hp_lost, killed, block_broken,
## armor_broken}. A dead creature takes nothing.
func apply_damage(amount: int, from_player := false) -> Dictionary:
	var out := {"blocked": 0, "hp_lost": 0, "killed": false, "block_broken": false, "armor_broken": false}
	if dead or amount <= 0:
		return out
	var block_before := block
	out["blocked"] = mini(block, amount)
	out["hp_lost"] = mini(health, maxi(0, amount - block))
	out["block_broken"] = block_before > 0 and amount >= block_before
	out["armor_broken"] = (
		_breakable_armor_active and from_player and block_before > 0 and amount >= block_before
	)
	block = maxi(0, block - amount)
	health = maxi(0, health - int(out["hp_lost"]))
	block_changed.emit(block)
	health_changed.emit(health)
	if health <= 0:
		out["killed"] = _die()
	elif out["armor_broken"]:
		_breakable_armor_active = false
		add_status(_breakable_armor_status, _breakable_armor_stacks)
	if not dead and moves != null:
		if moves.check_phases(health, max_health):
			intent_changed.emit()
	return out


## Direct HP loss (cards, events, curses): ignores Block. Returns HP lost.
func lose_hp(amount: int) -> int:
	if dead or amount <= 0:
		return 0
	var lost := mini(health, amount)
	health -= lost
	health_changed.emit(health)
	if health <= 0:
		_die()
	return lost


## Returns HP actually restored.
func heal(amount: int) -> int:
	if dead or amount <= 0:
		return 0
	var before := health
	health = mini(health + amount, max_health)
	health_changed.emit(health)
	return health - before


func add_block(amount: int) -> void:
	if amount <= 0:
		return
	block += amount
	block_changed.emit(block)


func set_block(value: int) -> void:
	block = maxi(0, value)
	block_changed.emit(block)


func add_status(status_name: String, stacks: int) -> void:
	status_system.add_status(status_name, stacks, self)


func get_status_stacks(status_name: String) -> int:
	return status_system.get_stacks(status_name)


func notify_status_changed() -> void:
	status_changed.emit()
	if not is_player():
		intent_changed.emit()


func notify_stats_changed() -> void:
	stats_changed.emit()


func play_block_pulse() -> void:
	pulse_requested.emit("block")


## Owner's turn start: statuses tick (Burn, Regen) before the reset; a living
## creature then loses its Block (and the player refills energy); powers that
## must survive the reset run after it (Metallicize).
func start_turn() -> void:
	status_system.on_turn_start(self)
	if not is_alive():
		return
	_breakable_armor_active = false
	if is_player():
		energy = max_energy
		energy_changed.emit(energy)
	block = 0
	block_changed.emit(block)
	status_system.after_owner_block_reset(self)


func end_turn() -> void:
	status_system.on_turn_end(self)
	if _temp_strength > 0:
		strength = maxi(0, strength - _temp_strength)
		_temp_strength = 0
		stats_changed.emit()


func gain_temp_strength(n: int) -> void:
	if n <= 0:
		return
	strength += n
	_temp_strength += n
	stats_changed.emit()


func gain_energy(amount: int) -> void:
	if amount <= 0:
		return
	energy += amount
	energy_changed.emit(energy)


func pay_energy(cost: int) -> bool:
	if energy < cost:
		return false
	energy -= cost
	energy_changed.emit(energy)
	return true


## Arms the Block gained this move as breakable armor; re-arming replaces the
## previous payload.
func arm_breakable_armor(status: String, stacks: int) -> void:
	_breakable_armor_active = true
	_breakable_armor_status = status
	_breakable_armor_stacks = maxi(1, stacks)


## Returns true if a stun stack was consumed (the move is skipped/cancelled).
func consume_stun_if_present() -> bool:
	return status_system.consume_stun(self)


# ─── Polarity ─────────────────────────────────────────────────────────────────


## Start-of-turn reset, driven by the starting relic.
func reset_polarity_turn(p: String) -> void:
	current_polarity = p
	_polarities_seen = [p]
	harmony_active = false


func set_polarity(p: String) -> void:
	current_polarity = p
	if not p in _polarities_seen:
		_polarities_seen.append(p)
	_check_harmony()


## Flip yin↔yang. No-op for a non-polarity hero.
func flip_polarity() -> void:
	if current_polarity == "yin":
		set_polarity("yang")
	elif current_polarity == "yang":
		set_polarity("yin")


## True the first time both Yin and Yang have been active this turn.
func _check_harmony() -> bool:
	if not harmony_active and ("yin" in _polarities_seen) and ("yang" in _polarities_seen):
		harmony_active = true
		return true
	return false


## Harmony matches everything; otherwise the card's polarity must equal the
## active one (neutral/empty never match).
func is_card_matched(polarity: String) -> bool:
	return (
		harmony_active
		or (polarity != "" and polarity != "neutral" and polarity == current_polarity)
	)


func _die() -> bool:
	if dead:
		return false
	dead = true
	died.emit()
	return true
