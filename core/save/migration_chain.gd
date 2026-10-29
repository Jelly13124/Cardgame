extends RefCounted

## The ordered migrations of one save kind (STS2 MigrationManager): each step
## takes a save of version N to N + 1. A chain must cover every version from its
## first to `current` exactly once; `problems()` names a gap or a duplicate so a
## test catches it before a player's save does.

var kind: String = ""
var first: int = 1
var current: int = 1
var _steps: Dictionary = {}  # from version -> Callable(Dictionary) -> Dictionary
var _duplicates: PackedStringArray = []


static func make(p_kind: String, p_first: int, p_current: int) -> RefCounted:
	var c = new()
	c.kind = p_kind
	c.first = p_first
	c.current = p_current
	return c


## Register the step from `from` to `from + 1`. `step` gets a deep copy and
## returns the migrated dictionary.
func add(from: int, step: Callable) -> RefCounted:
	if _steps.has(from):
		_duplicates.append("%s: two steps from v%d" % [kind, from])
	_steps[from] = step
	return self


## Gaps, duplicates and steps outside first..current-1; empty when sound.
func problems() -> PackedStringArray:
	var out := _duplicates.duplicate()
	for v in range(first, current):
		if not _steps.has(v):
			out.append("%s: no step from v%d" % [kind, v])
	for v in _steps:
		if int(v) < first or int(v) >= current:
			out.append("%s: step from v%d is outside v%d..v%d" % [kind, v, first, current])
	return out


func needs_migration(version: int) -> bool:
	return version < current


## Every step from `version` up to `current`, on a deep copy. A save newer than
## this build is returned unchanged (the loader decides what to do with it).
func migrate(data: Dictionary, version: int) -> Dictionary:
	var out := data.duplicate(true)
	for v in range(maxi(version, first), current):
		out = _steps[v].call(out)
	return out
