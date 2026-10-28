extends RefCounted

## Enemy intents (STS2 MonsterMoves.Intents): the plain-language text of a move
## (intent tooltip and interrupt message), generated from its type and its
## computed attack damage.

## English short labels for statuses without a UI_COMBAT_SHORT_* row.
const STATUS_SHORT_NAMES = {
	"weak": "Weak",
	"vulnerable": "Vuln",
	"short_circuit": "Short Circuit",
	"burn": "Burn",
	"stun": "Stun",
}


## Text for `action`; `damage` is its attack damage after the pipeline. Without
## tips the "can be interrupted" line is left out (one-line messages).
static func text(action: Dictionary, damage: int, with_tips: bool = true) -> String:
	var out := _text_with_tips(action, damage)
	if not with_tips:
		out = out.trim_suffix("\n" + _t("UI_COMBAT_INTENT_TIP_INTERRUPTIBLE"))
	return out


## Localized short status label ("Vuln"), falling back to the English table.
static func short_status(status: String) -> String:
	var key := "UI_COMBAT_SHORT_%s" % status.to_upper()
	var localized := _t(key)
	if localized != key:
		return localized
	return STATUS_SHORT_NAMES.get(status, status.capitalize())


static func _text_with_tips(next: Dictionary, dmg: int) -> String:
	var action_type := str(next.get("type", ""))
	match action_type:
		"attack", "attack_all", "attack_ramp":
			var tip := _t("UI_COMBAT_INTENT_TIP_ATTACK").format({"n": dmg})
			if action_type == "attack_ramp":
				tip += "\n" + _t("UI_COMBAT_INTENT_TIP_RAMP")
			return _append_interrupt_tip(tip, next)
		"attack_status":
			var status := short_status(str(next.get("status", "")))
			var k := int(next.get("stacks", 1))
			return _append_interrupt_tip(
				_t("UI_COMBAT_INTENT_TIP_ATTACK_STATUS").format({"n": dmg, "status": status, "k": k}),
				next
			)
		"block":
			return _t("UI_COMBAT_INTENT_TIP_DEFEND").format({"n": int(next.get("amount", 0))})
		"breakable_block":
			return _t("UI_COMBAT_INTENT_TIP_BREAKABLE_ARMOR").format(
				{
					"n": int(next.get("amount", 0)),
					"status": short_status(str(next.get("status", "vulnerable"))),
					"k": int(next.get("stacks", 1)),
				}
			)
		"reflective_plating":
			return _t("UI_COMBAT_INTENT_TIP_REFLECTIVE_PLATING").format(
				{"n": int(next.get("amount", 0)), "k": int(next.get("thorns", 0))}
			)
		"heal":
			return _t("UI_COMBAT_INTENT_TIP_HEAL").format({"n": int(next.get("amount", 0))})
		"buff_self", "buff":
			var status_id := str(next.get("status", ""))
			if status_id != "":
				return _t("UI_COMBAT_INTENT_TIP_BUFF_STATUS").format(
					{"status": short_status(status_id), "k": int(next.get("stacks", 1))}
				)
			return _t("UI_COMBAT_INTENT_TIP_BUFF")
		"telegraph":
			return _t("UI_COMBAT_INTENT_TIP_CHARGE")
		"summon":
			return _t("UI_COMBAT_INTENT_TIP_SUMMON")
		_:
			return _t("UI_COMBAT_INTENT_TIP_UNKNOWN")


static func _append_interrupt_tip(tip: String, action: Dictionary) -> String:
	if bool(action.get("interruptible", false)):
		return tip + "\n" + _t("UI_COMBAT_INTENT_TIP_INTERRUPTIBLE")
	return tip


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
