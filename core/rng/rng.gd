extends RefCounted

## Seeded random stream (STS2 Rng): a seed plus a counter of draws. Every public
## draw makes exactly one `randi()` call on the backing generator and bumps
## `counter`, so a saved `{seed, counter}` restores the stream by replaying.
## No class_name — preload.

var seed: int
var counter: int = 0
var _gen := RandomNumberGenerator.new()


func _init(p_seed: int = 0, p_counter: int = 0) -> void:
	seed = p_seed
	_gen.seed = p_seed
	fast_forward(p_counter)


func _next() -> int:
	counter += 1
	return _gen.randi()


## Integer in [0, max_exclusive).
func next_int(max_exclusive: int) -> int:
	return _next() % maxi(max_exclusive, 1)


## Integer in [min, max_inclusive] (replaces the global randi_range).
func next_range(min_value: int, max_inclusive: int) -> int:
	return min_value + _next() % maxi(max_inclusive - min_value + 1, 1)


## Float in [0, 1).
func next_float() -> float:
	return float(_next()) / 4294967296.0


func next_bool() -> bool:
	return _next() % 2 == 0


func chance(p: float) -> bool:
	return next_float() < p


## A random element, or null for an empty array (no draw).
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[next_int(items.size())]


## Fisher–Yates in place; draws size - 1 times.
func shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := next_int(i + 1)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


func fast_forward(target: int) -> void:
	if target < counter:
		push_error("Rng: cannot fast-forward from %d back to %d" % [counter, target])
		return
	while counter < target:
		_next()


func to_dict() -> Dictionary:
	return {"seed": seed, "counter": counter}


static func from_dict(d: Dictionary):
	return load("uid://ds3dd0kmgq0ib").new(int(d.get("seed", 0)), int(d.get("counter", 0)))  # res://core/rng/rng.gd
