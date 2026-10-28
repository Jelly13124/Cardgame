extends Node2D

## Minimal creature for combat contract tests: Block absorbs first, HP clamps
## at 0, `damage_received` sums what reached take_damage (before Block) and
## `hp_lost` what reached HP.

const STATUS_SYSTEM = preload("uid://cq4eulp4ci8is")  # res://core/combat/status_effects.gd

var status_system = STATUS_SYSTEM.new()
var health := 999
var max_health := 999
var block := 0
var energy := 3
var strength := 0
var constitution := 0
var intelligence := 0
var luck := 0
var damage_received := 0
var hp_lost := 0
var hits: Array[int] = []


func add_status(status: String, stacks: int) -> void:
	status_system.add_status(status, stacks, self)


func get_status_stacks(status: String) -> int:
	return status_system.get_stacks(status)


func add_block(amount: int) -> void:
	block += amount


func take_damage(amount: int, _silent: bool = false, _tags: Dictionary = {}) -> void:
	if amount <= 0:
		return
	damage_received += amount
	hits.append(amount)
	var through := maxi(0, amount - block)
	block = maxi(0, block - amount)
	var lost := mini(health, through)
	health -= lost
	hp_lost += lost


func lose_hp(amount: int) -> void:
	var lost := mini(health, amount)
	health -= lost
	hp_lost += lost


func heal(amount: int) -> void:
	health = mini(max_health, health + amount)


func gain_energy(amount: int) -> void:
	energy += amount
