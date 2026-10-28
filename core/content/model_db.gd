extends RefCounted

## Static content registry (STS2 ModelDb). Base content loads lazily from
## `res://content/<dir>/` under the `base` namespace; tests and mods add more with
## `inject_dir` / `inject`. Every query goes through `ensure_loaded()`. The
## loader is the one owner of reference parsing: JSON references are rewritten
## to full IDs here, so consumers never resolve bare refs themselves.
## No class_name — preload. No scene tree.

const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd
const CARD_VARS = preload("uid://dagno1w0jtl2n")  # res://core/content/card_vars.gd
const CONTENT_MODEL = preload("uid://bd6thqkfhu232")  # res://core/content/content_model.gd

const CONTENT_ROOT := "res://content/"
const CATEGORY_DIRS := {
	"card": "cards",
	"monster": "monsters",
	"relic": "relics",
	"equipment": "equipment",
	"equipment_set": "equipment_sets",
	"event": "events",
	"tool": "tools",
	"bounty": "bounties",
	"character": "characters",
	"base_upgrade": "base_upgrades",
	"card_pool": "card_pools",
	"relic_pool": "relic_pools",
	"status": "statuses",
	"ascension": "ascension",
	"encounter": "encounters",
	"act": "acts",
	"run_config": "runs",
	"economy": "economy",
}

static var _models: Dictionary = {}  # category -> {full id -> content model}
static var _errors: Array[String] = []
static var _base_loaded := false


static func ensure_loaded() -> void:
	if _base_loaded:
		return
	_base_loaded = true
	_load_root(CONTENT_ROOT, MODEL_ID.BASE)


## Drop everything; base content reloads on the next query.
static func reset() -> void:
	_models.clear()
	_errors.clear()
	_base_loaded = false


static func has(category: String, id: String) -> bool:
	ensure_loaded()
	return _models.has(category) and _models[category].has(id)


## The canonical model, or null.
static func get_model(category: String, id: String):
	ensure_loaded()
	if not _models.has(category):
		return null
	return _models[category].get(id, null)


## Read-only canonical data, or {} when absent.
static func data(category: String, id: String) -> Dictionary:
	var model = get_model(category, id)
	return model.data if model != null else {}


## A writable deep copy (STS2 ToMutable), or {} when absent.
static func mutable(category: String, id: String) -> Dictionary:
	var model = get_model(category, id)
	return model.to_mutable() if model != null else {}


## Sorted full IDs of one category.
static func ids(category: String) -> Array[String]:
	ensure_loaded()
	var out: Array[String] = []
	if _models.has(category):
		for id in _models[category]:
			out.append(str(id))
	out.sort()
	return out


static func models(category: String) -> Array:
	var out: Array = []
	for id in ids(category):
		out.append(_models[category][id])
	return out


## Full ID for `ref`: a registered full ref as is; a bare ref in `context_ns`,
## then in base; "" when unknown.
static func resolve(category: String, ref: String, context_ns: String = MODEL_ID.BASE) -> String:
	ensure_loaded()
	if ref == "" or not _models.has(category):
		return ""
	var bucket: Dictionary = _models[category]
	if MODEL_ID.is_full(ref):
		return ref if bucket.has(ref) else ""
	for ns in [context_ns, MODEL_ID.BASE]:
		var full := MODEL_ID.make(ns, ref)
		if bucket.has(full):
			return full
	return ""


static func load_errors() -> Array[String]:
	ensure_loaded()
	return _errors.duplicate()


## Load a directory laid out like `content/` under namespace `ns`.
static func inject_dir(root: String, ns: String) -> void:
	ensure_loaded()
	_load_root(root, ns)


## Register one entry. `entry_data.id`, when present, must equal `entry`.
static func inject(category: String, ns: String, entry: String, entry_data: Dictionary) -> void:
	ensure_loaded()
	if _register(category, ns, entry, entry_data.duplicate(true), "%s/%s/%s" % [ns, category, entry]):
		_finalize(category, MODEL_ID.make(ns, entry))


static func remove(category: String, id: String) -> void:
	ensure_loaded()
	if _models.has(category):
		_models[category].erase(id)


# --- loading ----------------------------------------------------------------

static func _load_root(root: String, ns: String) -> void:
	var added: Array = []  # [category, full id]
	for category in CATEGORY_DIRS:
		var dir_path: String = root.path_join(CATEGORY_DIRS[category])
		if not DirAccess.dir_exists_absolute(dir_path):
			continue
		for file_name in DirAccess.get_files_at(dir_path):
			if not file_name.ends_with(".json"):
				continue
			var path := dir_path.path_join(file_name)
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(parsed) != TYPE_DICTIONARY:
				_errors.append("%s: not a JSON object" % path)
				continue
			var entry := file_name.get_basename()
			if _register(category, ns, entry, parsed, path):
				added.append([category, MODEL_ID.make(ns, entry)])
	# References resolve only after the whole root is registered, so content
	# can point at entries in files loaded later.
	for pair in added:
		_finalize(pair[0], pair[1])


static func _register(category: String, ns: String, entry: String, raw: Dictionary, where: String) -> bool:
	if not CATEGORY_DIRS.has(category):
		_errors.append("%s: unknown category '%s'" % [where, category])
		return false
	var local_id := str(raw.get("id", entry))
	if local_id != entry:
		_errors.append("%s: id '%s' does not match file name '%s'" % [where, local_id, entry])
	if not _models.has(category):
		_models[category] = {}
	var model = CONTENT_MODEL.new(category, ns, entry, raw)
	raw["id"] = model.id
	_models[category][model.id] = model
	return true


static func _finalize(category: String, id: String) -> void:
	var model = _models[category][id]
	# References first, so the kept effect templates carry full IDs too.
	_normalize_refs(category, model.data, model.ns, "%s %s" % [category, id])
	if category == "card":
		_substitute_card_vars(model.data, "card %s" % id)
	_make_read_only(model.data)


# --- card vars -------------------------------------------------------------------

## Effect lists of a card that may use "$name" vars.
const CARD_VAR_LISTS := ["effects", "end_turn_in_hand", "matched_bonus"]


## A card's `vars` fill its "$name" fields (every effect list and upgrade.effects);
## the raw `effects` stay as `effects_template` so upgrades can re-fill them. A
## "$name" with no var — including on a card with no `vars` at all — is a load
## error, never a silent 0.
static func _substitute_card_vars(d: Dictionary, where: String) -> void:
	var has_vars := typeof(d.get("vars")) == TYPE_DICTIONARY
	var vars: Dictionary = d["vars"] if has_vars else {}
	for key in CARD_VAR_LISTS:
		for name in CARD_VARS.missing(d.get(key, []), vars):
			_errors.append("%s: %s use unknown var '%s'" % [where, key, name])
	var up: Variant = d.get("upgrade")
	if typeof(up) == TYPE_DICTIONARY:
		for name in up.get("vars", {}):
			if not vars.has(name):
				_errors.append("%s: upgrade.vars names unknown var '%s'" % [where, name])
		var up_vars := CARD_VARS.add(vars, up.get("vars", {}))
		for name in CARD_VARS.missing(up.get("effects", []), up_vars):
			_errors.append("%s: upgrade.effects use unknown var '%s'" % [where, name])
	if not has_vars:
		return
	d["effects_template"] = d.get("effects", []).duplicate(true)
	for key in CARD_VAR_LISTS:
		if d.has(key):
			d[key] = CARD_VARS.substitute(d[key], vars)
	if typeof(up) == TYPE_DICTIONARY:
		if up.has("effects"):
			var up_vars := CARD_VARS.add(vars, up.get("vars", {}))
			up["effects_template"] = up["effects"].duplicate(true)
			up["effects"] = CARD_VARS.substitute(up["effects"], up_vars)


# --- references (spec: "References inside JSON") ------------------------------

static func _normalize_refs(category: String, d: Dictionary, ns: String, where: String) -> void:
	match category:
		"card", "relic":
			_effects_refs(d.get("effects", []), ns, where)
			if typeof(d.get("upgrade")) == TYPE_DICTIONARY:
				_effects_refs(d["upgrade"].get("effects", []), ns, where)
		"monster":
			_effects_refs(d.get("action_pattern", []), ns, where)
			for phase in _dicts(d.get("phases", [])):
				_effects_refs(phase.get("action_pattern", []), ns, where)
				_effects_refs(phase.get("on_enter", []), ns, where)
		"event":
			for option in _dicts(d.get("options", [])):
				for key in option:
					if str(key).begins_with("effects"):
						_effects_refs(option[key], ns, where)
		"equipment":
			_ref_field(d, "set_id", "equipment_set", ns, where)
		"character":
			_ref_list(d, "starter_deck", "card", ns, where)
			_ref_list(d, "exclusive_cards", "card", ns, where)
			_ref_field(d, "card_pool", "card_pool", ns, where)
			_ref_field(d, "relic_pool", "relic_pool", ns, where)
		"card_pool":
			_ref_list(d, "cards", "card", ns, where)
		"relic_pool":
			_ref_list(d, "relics", "relic", ns, where)
		"encounter":
			_ref_list(d, "monsters", "monster", ns, where)
		"act":
			_ref_field(d, "boss", "encounter", ns, where)
			_ref_list(d, "elites", "encounter", ns, where)
			for band in _dicts(d.get("encounters", [])):
				_ref_list(band, "pool", "encounter", ns, where)
		"run_config":
			_ref_list(d, "acts", "act", ns, where)
			_ref_list(d, "heroes", "character", ns, where)
			if typeof(d.get("reward_pools")) == TYPE_DICTIONARY:
				var pools := {}
				for hero in d["reward_pools"]:
					pools[_resolve_or_report("character", str(hero), ns, where + ".reward_pools")] = (
						_resolve_or_report("card_pool", str(d["reward_pools"][hero]), ns, where + ".reward_pools")
					)
				d["reward_pools"] = pools


static func _effects_refs(effects: Variant, ns: String, where: String) -> void:
	for effect in _dicts(effects):
		_ref_field(effect, "card", "card", ns, where)
		_ref_field(effect, "curse", "card", ns, where)
		_ref_list(effect, "enemy_ids", "monster", ns, where)
		if str(effect.get("type", "")) == "gain_relic":
			_ref_field(effect, "id", "relic", ns, where)


static func _ref_field(d: Dictionary, key: String, target: String, ns: String, where: String) -> void:
	if d.has(key):
		d[key] = _resolve_or_report(target, str(d[key]), ns, "%s.%s" % [where, key])


static func _ref_list(d: Dictionary, key: String, target: String, ns: String, where: String) -> void:
	if typeof(d.get(key)) != TYPE_ARRAY:
		return
	var out: Array = []
	for ref in d[key]:
		out.append(_resolve_or_report(target, str(ref), ns, "%s.%s[]" % [where, key]))
	d[key] = out


## Unresolved refs are kept verbatim and reported; loading never aborts.
static func _resolve_or_report(target: String, ref: String, ns: String, where: String) -> String:
	var full := resolve(target, ref, ns)
	if full == "":
		_errors.append("%s: unknown %s '%s'" % [where, target, ref])
		return ref
	return full


static func _dicts(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			if typeof(item) == TYPE_DICTIONARY:
				out.append(item)
	return out


static func _make_read_only(value: Variant) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for v in value.values():
			_make_read_only(v)
		value.make_read_only()
	elif typeof(value) == TYPE_ARRAY:
		for v in value:
			_make_read_only(v)
		value.make_read_only()
