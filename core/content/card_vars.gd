extends RefCounted

## Card variables (STS2 DynamicVars): a card declares `vars` once and any effect
## field may say "$name". `substitute` returns a deep copy with every "$name"
## replaced by its value; `missing` lists the names that have no var.
## No class_name — preload.


static func substitute(value: Variant, vars: Dictionary) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				out[key] = substitute(value[key], vars)
			return out
		TYPE_ARRAY:
			var out: Array = []
			for item in value:
				out.append(substitute(item, vars))
			return out
		TYPE_STRING:
			var s: String = value
			if s.begins_with("$") and vars.has(s.substr(1)):
				return vars[s.substr(1)]
	return value


static func missing(value: Variant, vars: Dictionary) -> Array:
	var out: Array = []
	match typeof(value):
		TYPE_DICTIONARY:
			for key in value:
				out.append_array(missing(value[key], vars))
		TYPE_ARRAY:
			for item in value:
				out.append_array(missing(item, vars))
		TYPE_STRING:
			var s: String = value
			if s.begins_with("$") and not vars.has(s.substr(1)):
				out.append(s.substr(1))
	return out


## `vars` with `deltas` added (upgrade.vars).
static func add(vars: Dictionary, deltas: Dictionary) -> Dictionary:
	var out := vars.duplicate(true)
	for key in deltas:
		out[key] = int(out.get(key, 0)) + int(deltas[key])
	return out
