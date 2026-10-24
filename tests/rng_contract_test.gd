extends Node

## Seeded Rng and RunRngSet (STS2 RunRngSet): deterministic sequences, counters
## that round-trip through saves, and streams that do not disturb each other.

const RNG = preload("uid://ds3dd0kmgq0ib")  # res://core/rng/rng.gd
const RUN_RNG_SET = preload("uid://ealvw2c6utr7")  # res://core/rng/run_rng_set.gd

var failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	print("[FAIL] ", message)


func _draws(r) -> Array:
	var out: Array = []
	for i in 5:
		out.append(r.next_int(100))
		out.append(r.next_range(3, 9))
		out.append(snappedf(r.next_float(), 0.000001))
		out.append(r.next_bool())
	return out


func _run() -> void:
	var a = RNG.new(42)
	var b = RNG.new(42)
	_expect(_draws(a) == _draws(b), "same seed gives the same sequence")
	_expect(a.counter == 20, "each draw counts once, got %d" % a.counter)
	var items := [1, 2, 3, 4, 5]
	a.shuffle(items)
	_expect(a.counter == 24, "shuffle of 5 counts 4 draws")
	_expect(items.size() == 5 and items.has(1) and items.has(5), "shuffle keeps items")
	var c = RNG.from_dict(a.to_dict())
	_expect(c.counter == a.counter and _draws(c) == _draws(a), "from_dict continues the same sequence")
	var d = RNG.new(7)
	for i in 3:
		d.next_int(10)
	d.fast_forward(1)
	_expect(d.counter == 3, "fast_forward never goes back")
	var r = RNG.new(9)
	for i in 50:
		var v: int = r.next_range(2, 4)
		_expect(v >= 2 and v <= 4, "next_range is inclusive and in bounds")
	_expect(RNG.new(1).pick([]) == null, "pick on empty is null")

	_expect(RUN_RNG_SET.fnv1a32("") == 2166136261, "fnv1a32 offset basis")
	_expect(RUN_RNG_SET.canonicalize(" o1i ") == "011", "canonicalize maps O and I and trims")
	_expect(not RUN_RNG_SET.is_valid_seed("A-B") and not RUN_RNG_SET.is_valid_seed(""), "invalid seeds rejected")
	_expect(RUN_RNG_SET.is_valid_seed("testseedo1"), "lower-case seed valid after canonicalize")
	var random_seed: String = RUN_RNG_SET.random_seed_string()
	_expect(random_seed.length() == 10 and RUN_RNG_SET.is_valid_seed(random_seed)
		and RUN_RNG_SET.canonicalize(random_seed) == random_seed, "random seed is 10 canonical chars")
	var s1 = RUN_RNG_SET.new("abc")
	var s2 = RUN_RNG_SET.new("ABC")
	_expect(s1.seed == s2.seed and s1.seed_string == "ABC", "seed string is canonicalized")
	_expect(RUN_RNG_SET.STREAMS.size() == 11, "eleven named streams")
	var noisy = RUN_RNG_SET.new("SEEDX")
	var quiet = RUN_RNG_SET.new("SEEDX")
	for i in 50:
		noisy.stream("combat_crits").next_float()
	_expect(noisy.stream("rewards").next_int(1000) == quiet.stream("rewards").next_int(1000),
		"drawing one stream leaves the others unchanged")
	_expect(noisy.stream("rewards").seed != noisy.stream("shops").seed, "streams have distinct seeds")
	var copy = RUN_RNG_SET.from_dict(noisy.to_dict())
	var same := true
	for name in RUN_RNG_SET.STREAMS:
		if copy.stream(name).next_int(1 << 30) != noisy.stream(name).next_int(1 << 30):
			same = false
	_expect(same and copy.seed_string == "SEEDX", "set round-trips through to_dict/from_dict")

	if failures.is_empty():
		print("[OK] rng contract passed")
		get_tree().quit(0)
		return
	push_error("rng contract failed: %s" % "; ".join(failures))
	get_tree().quit(1)
