extends RefCounted

## The one card-text generator (STS2: a card's description template filled from
## its numbers by one code path). Every view — battle card face, gallery,
## discover, shop, upgrade preview — calls `build`; the per-effect lines come
## from each effect type's definition (`describe` in combat_effects.gd), so a new
## type documents itself where it is registered. No class_name — preload.
##
## `view` carries what the text depends on besides the card data:
##   stats: {strength, constitution, intelligence, luck, charm}
##   pipeline: {effect_index: final value} from the battle preview (or {})
##   replay_bonus: extra replays on attacks from held relics (0 outside battle)

const EFFECT_CATALOG = preload("uid://880atc7mnnie")  # res://battle_scene/combat/effect_catalog.gd
const STATUS_SYS = preload("uid://cq4eulp4ci8is")  # res://core/combat/status_effects.gd
const MODEL_ID = preload("uid://ddtqasxna3kbq")  # res://core/content/model_id.gd

const DEFAULT_STATS := {"strength": 0, "constitution": 0, "intelligence": 0, "luck": 0, "charm": 0}
const SCALING_OPT_OUT := {"strength": "no_str", "constitution": "no_con"}
const OVERLOAD_KEYWORD_COLOR := Color(0.20, 0.92, 1.0)


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


## Card description BBCode lines (before keyword colouring).
static func build(data: Dictionary, view: Dictionary = {}) -> String:
	var card_key: String = MODEL_ID.key_entry(str(data.get("id", "")))
	var effects: Array = data.get("effects", [])
	var registry = EFFECT_CATALOG.registry()
	# Types whose definition asks for authored text (Discover) read the card's
	# own description.
	for e in effects:
		if typeof(e) == TYPE_DICTIONARY and bool(registry.definition(str(e.get("type", ""))).get("authored_text", false)):
			return Settings.t("CARD_%s_DESC" % card_key, str(data.get("description", "")))
	if effects.is_empty():
		# Raw description is CONTENT — route through Settings.t (CARD_<id>_DESC)
		# with the English source as fallback, THEN strip BBCode for plain display.
		var raw: String = Settings.t("CARD_%s_DESC" % card_key, str(data.get("description", "")))
		return (
			raw
			. replace("[b]", "")
			. replace("[/b]", "")
			. replace("[i]", "")
			. replace("[/i]", "")
			. replace("[center]", "")
			. replace("[/center]", "")
		)

	var stats: Dictionary = view.get("stats", DEFAULT_STATS)
	var pipeline: Dictionary = view.get("pipeline", {})
	var lines: PackedStringArray = []
	for effect_index in effects.size():
		var effect = effects[effect_index]
		var etype: String = effect.get("type", "")
		var def: Dictionary = registry.definition(etype)
		var base: int = int(effect.get("amount", 0))
		var mult: float = float(effect.get("multiplier", 1))
		var stacks: int = int(effect.get("stacks", 1))
		# The breakdown shows base + attribute; the colored total is the pipeline
		# number in battle. Scaling effects ALWAYS show the "(base+stat)"
		# breakdown — even when the stat is 0 — so players can tell a card that
		# grows from a fixed one.
		var base_after_mult: int = int(base * mult) if mult != 1 else base
		var scales := str(def.get("scales", ""))
		if scales != "" and bool(effect.get(SCALING_OPT_OUT.get(scales, ""), false)):
			scales = ""
		var stat_val: int = int(stats.get(scales, 0)) if scales != "" else 0
		var total: int = base_after_mult + stat_val
		var v := {
			"data": data,
			"base": base,
			"mult": mult,
			"stacks": stacks,
			"base_after_mult": base_after_mult,
			"scales": scales != "",
			"stat_val": stat_val,
			"total": total,
			"final": int(pipeline.get(effect_index, total)),
		}
		if def.has("describe"):
			lines.append_array(def["describe"].call(effect, v))
		else:
			lines.append(etype.replace("_", " ").capitalize())

	# Keyword tags (Retain / Exhaust) appear on their own line, dimmer than effects.
	var keywords: PackedStringArray = []
	# Replay tag (double-fire clip etc.): card's own replay + held-relic bonus on
	# attacks. Display only — never mutates the shared/preloaded card_info.
	var replay_n: int = int(data.get("replay", 0))
	if str(data.get("type", "")).to_lower() == "attack":
		replay_n += int(view.get("replay_bonus", 0))
	if replay_n > 0:
		keywords.append(_t("UI_BATTLE_KEYWORD_REPLAY").format({"n": replay_n}))
	if bool(data.get("retain", false)):
		keywords.append(_t("UI_BATTLE_KEYWORD_RETAIN"))
	for e in effects:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "exhaust_self":
			keywords.append(_t("UI_BATTLE_KEYWORD_EXHAUST"))
			break
	if keywords.size() > 0:
		lines.append("[i]%s[/i]" % " · ".join(keywords))

	return "\n".join(lines)


## StS-style keyword tinting: colour status / keyword terms in a card's description
## so the player sees at a glance what it touches (definitions show in the hover
## glossary). Terms resolve in the current locale, so 短路/Short Circuit and 过载/Overload match.
static func colorize(text: String) -> String:
	var terms: Array = []  # [[term, hex], ...]
	for status in STATUS_SYS.status_keys():
		var nm: String = STATUS_SYS.format_name_localized(status)
		if nm.strip_edges() != "":
			terms.append([nm, STATUS_SYS.status_color(status).to_html(false)])
	var overload_name := _t("UI_BATTLE_KEYWORD_OVERLOAD_NAME")
	if overload_name != "UI_BATTLE_KEYWORD_OVERLOAD_NAME":
		terms.append([overload_name, OVERLOAD_KEYWORD_COLOR.to_html(false)])
	# (Exhaust / Retain already arrive pre-coloured from their UI_BATTLE_KEYWORD_*
	# translation rows, so they are NOT re-tinted here.)
	# Longest term first so a short term can't pre-empt a longer one.
	terms.sort_custom(func(a, b): return a[0].length() > b[0].length())
	for pair in terms:
		var term: String = pair[0]
		if term != "" and text.contains(term):
			text = text.replace(term, "[color=#%s]%s[/color]" % [pair[1], term])
	return text


## Hover glossary: the attributes, statuses and keywords the card touches. The
## per-type parts come from each definition's `glossary` list.
static func glossary(data: Dictionary) -> String:
	var effects: Array = data.get("effects", [])
	var registry = EFFECT_CATALOG.registry()
	var seen: Dictionary = {}
	var lines: PackedStringArray = []
	var keys: Dictionary = {}
	for effect in effects:
		for entry in registry.definition(str(effect.get("type", ""))).get("glossary", []):
			var key := str(entry)
			if key == "attr:from_effect":
				key = "attr:" + str(effect.get("attr", "intelligence"))
			keys[key] = true

	# --- Global attributes the card scales with or grants — one line per attribute. ---
	for attr in ["strength", "constitution", "intelligence", "luck", "charm"]:
		if not keys.has("attr:" + attr):
			continue
		var attr_key: String = attr.to_upper()
		var d := _t("UI_BATTLE_KEYWORD_%s_DESC" % attr_key)
		if d != "UI_BATTLE_KEYWORD_%s_DESC" % attr_key:
			lines.append("[b]%s[/b]: %s" % [_t("UI_COMBAT_ATTR_%s" % attr_key), d])

	# --- Statuses applied via apply_status / _self / _all (carry a `status` field). ---
	for effect in effects:
		var status := str(effect.get("status", ""))
		if status == "" or seen.has(status):
			continue
		seen[status] = true
		var up := status.to_upper()
		var kw_name := _t("UI_COMBAT_STATUS_%s" % up)
		if kw_name == "UI_COMBAT_STATUS_%s" % up:
			kw_name = STATUS_SYS.format_name_localized(status)
		var desc := _t("UI_COMBAT_STATUS_%s_DESC" % up)
		if desc == "UI_COMBAT_STATUS_%s_DESC" % up:
			desc = STATUS_SYS.status_description(status)
		if desc != "":
			lines.append("[b]%s[/b]: %s" % [kw_name, desc])

	# Short Circuit's specialized apply/Overload effects do not carry a `status`
	# field, but the card still needs the same keyword explanation on hover.
	if keys.has("short_circuit") and not seen.has("short_circuit"):
		seen["short_circuit"] = true
		lines.append(
			"[b]%s[/b]: %s" % [_t("UI_COMBAT_STATUS_SHORT_CIRCUIT"), _t("UI_COMBAT_STATUS_SHORT_CIRCUIT_DESC")]
		)

	# Overload is an action keyword rather than a status, so it gets its own entry.
	if keys.has("overload"):
		lines.append(
			"[b]%s[/b]: %s" % [_t("UI_BATTLE_KEYWORD_OVERLOAD_NAME"), _t("UI_BATTLE_KEYWORD_OVERLOAD_DESC")]
		)

	# --- Stun: its own effect type (apply_stun / _all), with no `status` field. ---
	if keys.has("stun") and not seen.has("stun"):
		seen["stun"] = true
		var sd := _t("UI_COMBAT_STATUS_STUN_DESC")
		if sd != "UI_COMBAT_STATUS_STUN_DESC":
			lines.append("[b]%s[/b]: %s" % [_t("UI_COMBAT_STATUS_STUN"), sd])

	# --- Replay: the card's own replay count (an attack auto-repeats). ---
	if int(data.get("replay", 0)) > 0:
		var rd := _t("UI_BATTLE_KEYWORD_REPLAY_DESC")
		if rd != "UI_BATTLE_KEYWORD_REPLAY_DESC":
			lines.append("[b]%s[/b]: %s" % [_t("UI_BATTLE_KEYWORD_REPLAY_NAME"), rd])

	# Card keywords (Exhaust / Retain) — explain them when the card has them.
	if bool(data.get("retain", false)):
		lines.append(
			"[b]%s[/b]: %s" % [_t("UI_BATTLE_KEYWORD_RETAIN"), _t("UI_BATTLE_KEYWORD_RETAIN_DESC")]
		)
	if keys.has("exhaust"):
		lines.append(
			"[b]%s[/b]: %s" % [_t("UI_BATTLE_KEYWORD_EXHAUST"), _t("UI_BATTLE_KEYWORD_EXHAUST_DESC")]
		)

	return "\n".join(lines)
