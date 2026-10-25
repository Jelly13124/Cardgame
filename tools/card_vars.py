"""Python mirror of core/content/card_vars.gd + the vars path of card_upgrade.gd,
for tools that read content/cards/*.json directly."""


def substitute(value, card_vars):
    if isinstance(value, dict):
        return {k: substitute(v, card_vars) for k, v in value.items()}
    if isinstance(value, list):
        return [substitute(v, card_vars) for v in value]
    if isinstance(value, str) and value.startswith("$") and value[1:] in card_vars:
        return card_vars[value[1:]]
    return value


def resolved(card):
    """The card with its vars filled in (what ModelDb serves)."""
    card_vars = card.get("vars")
    if not isinstance(card_vars, dict):
        return card
    out = dict(card)
    out["effects"] = substitute(card.get("effects", []), card_vars)
    up = card.get("upgrade")
    if isinstance(up, dict):
        up = dict(up)
        up_vars = upgraded_vars(card_vars, up.get("vars", {}))
        if "effects" in up:
            up["effects"] = substitute(up["effects"], up_vars)
        elif "vars" in up:
            # Var deltas: the upgraded effects re-fill the base template.
            up["effects"] = substitute(card.get("effects", []), up_vars)
        out["upgrade"] = up
    return out


def upgraded_vars(card_vars, deltas):
    out = dict(card_vars)
    for k, d in (deltas or {}).items():
        out[k] = int(out.get(k, 0)) + int(d)
    return out
