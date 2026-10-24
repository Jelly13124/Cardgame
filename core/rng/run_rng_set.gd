extends RefCounted

## Named seeded streams for one run (STS2 RunRngSet + PlayerRngSet). The seed
## string is what the player sees and types; each stream is seeded with
## seed + fnv1a32(name), so draws in one system never shift another.
## No class_name — preload.

const RNG = preload("uid://ds3dd0kmgq0ib")  # res://core/rng/rng.gd

const STREAMS: Array[String] = [
	"up_front",  # event order, demo featured set
	"encounters",  # normal fights, in visit order
	"elites",  # elite fights, in visit order
	"shuffle",  # draw-pile shuffles
	"unknown_map_point",  # "?" node outcomes
	"combat_card_generation",  # discover candidates
	"combat_targets",  # random-target effects
	"combat_crits",  # crit rolls (no STS2 counterpart; kept apart from rewards)
	"monster_ai",  # random enemy intents
	"rewards",  # loot, card draft, equipment drops, affixes
	"shops",  # shop and market stock
	"events",  # event luck checks
	"niche",  # other gameplay rolls
]
const SEED_ALPHABET := "0123456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const SEED_LENGTH := 10

var seed_string: String
var seed: int
var _streams: Dictionary = {}  # name -> Rng


func _init(p_seed_string: String) -> void:
	seed_string = canonicalize(p_seed_string)
	seed = fnv1a32(seed_string)
	for name in STREAMS:
		_streams[name] = RNG.new((seed + fnv1a32(name)) & 0xFFFFFFFF)


func stream(name: String):
	if not _streams.has(name):
		push_error("RunRngSet: unknown stream '%s'" % name)
		return RNG.new(0)
	return _streams[name]


## A fresh stream for one-off generation keyed by `name` (e.g. an act map).
## Not saved: the same seed and name always give the same stream.
func derived(name: String):
	return RNG.new((seed + fnv1a32(name)) & 0xFFFFFFFF)


func to_dict() -> Dictionary:
	var counters := {}
	for name in STREAMS:
		counters[name] = _streams[name].counter
	return {"seed_string": seed_string, "counters": counters}


static func from_dict(d: Dictionary):
	var set = load("uid://ealvw2c6utr7").new(str(d.get("seed_string", "")))  # res://core/rng/run_rng_set.gd
	var counters: Dictionary = d.get("counters", {})
	for name in counters:
		if set._streams.has(str(name)):
			set._streams[str(name)].fast_forward(int(counters[name]))
	return set


static func canonicalize(s: String) -> String:
	return s.strip_edges().to_upper().replace("O", "0").replace("I", "1")


static func is_valid_seed(s: String) -> bool:
	var c := canonicalize(s)
	if c.is_empty():
		return false
	for ch in c:
		if not SEED_ALPHABET.contains(ch):
			return false
	return true


## A fresh 10-character seed from an unseeded generator.
static func random_seed_string() -> String:
	var gen := RandomNumberGenerator.new()
	gen.randomize()
	var out := ""
	for i in SEED_LENGTH:
		out += SEED_ALPHABET[gen.randi() % SEED_ALPHABET.length()]
	return out


## FNV-1a 32-bit over UTF-8 bytes (stable across platforms and runs).
static func fnv1a32(s: String) -> int:
	var h := 2166136261
	for b in s.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return h
