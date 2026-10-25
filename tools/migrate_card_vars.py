"""One-shot migration (phase 4): card numbers become `vars`, effects refer to
them as "$name", and upgrades become var deltas.

- Every numeric field of a top-level effect becomes a var named by its role
  (damage, block, draw, energy, <attribute>, <status>, stun, hp_loss,
  short_circuit, cards) or by the field name (base, per, mult, ...).
- An `upgrade.effects` list that differs from `effects` only in those numbers
  becomes `upgrade.vars` deltas; any structural difference keeps the list.
- Cards without `upgrade.effects` (the old formula path, cost-only upgrades
  included) get explicit `upgrade.vars` from the effect types' default deltas.

Usage: python tools/migrate_card_vars.py [content/cards]
"""
import json
import os
import sys

NUMERIC_FIELDS = ["amount", "stacks", "base", "per", "mult", "multiplier", "charge_multiplier", "attr_mult"]
ROLE_BY_TYPE = {
    "deal_damage": "damage",
    "deal_damage_all": "damage",
    "gain_block": "block",
    "draw_cards": "draw",
    "gain_energy": "energy",
    "lose_hp": "hp_loss",
    "apply_short_circuit_scaled": "short_circuit",
    "add_card_to_hand": "cards",
    "apply_stun": "stun",
    "apply_stun_all": "stun",
}
# Default upgrade deltas = the effect definitions' `upgrade` (combat_effects.gd).
DEFAULT_DELTAS = {
    "deal_damage": {"amount": 2},
    "deal_damage_all": {"amount": 2},
    "gain_block": {"amount": 3},
    "gain_strength": {"amount": 1},
    "gain_intelligence": {"amount": 1},
    "gain_luck": {"amount": 1},
    "gain_energy": {"amount": 1},
    "draw_cards": {"amount": 1},
    "apply_status": {"stacks": 1},
    "apply_status_all": {"stacks": 1},
}


def role(effect, field):
    t = effect.get("type", "")
    if field in ("amount", "stacks"):
        if t in ROLE_BY_TYPE:
            return ROLE_BY_TYPE[t]
        if t.startswith("gain_"):
            return t[len("gain_"):]
        if t.startswith("apply_status"):
            return effect.get("status", "stacks")
    return field


def number(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def as_int(v):
    return int(v) if float(v).is_integer() else v


def migrate(card):
    effects = card.get("effects", [])
    if "vars" in card or not effects:
        return False
    vars_, refs = {}, []  # refs: [(effect index, field, var name)]
    for i, e in enumerate(effects):
        for field in NUMERIC_FIELDS:
            if field in e and number(e[field]):
                name = role(e, field)
                n, k = name, 2
                while n in vars_:
                    n = "%s_%d" % (name, k)
                    k += 1
                vars_[n] = as_int(e[field])
                refs.append((i, field, n))
    if not vars_:
        return False
    up = card.get("upgrade")
    deltas = {}
    if isinstance(up, dict) and "effects" in up:
        ue = up["effects"]
        same_shape = len(ue) == len(effects) and all(
            {k: v for k, v in a.items() if k not in NUMERIC_FIELDS or not number(v)}
            == {k: v for k, v in b.items() if k not in NUMERIC_FIELDS or not number(v)}
            for a, b in zip(effects, ue)
        )
        if same_shape:
            for i, field, n in refs:
                if field not in ue[i] or not number(ue[i][field]):
                    same_shape = False
                    break
                d = as_int(ue[i][field] - effects[i][field])
                if d:
                    deltas[n] = d
        if same_shape:
            del up["effects"]
            if deltas:
                up["vars"] = deltas
    elif card.get("type") != "curse":
        for i, field, n in refs:
            d = DEFAULT_DELTAS.get(effects[i].get("type", ""), {}).get(field, 0)
            if d:
                deltas[n] = d
        if deltas:
            up = card.setdefault("upgrade", {})
            up["vars"] = deltas
    for i, field, n in refs:
        effects[i][field] = "$" + n
    # vars sit just before effects for readability
    out = {}
    for k, v in card.items():
        if k == "effects":
            out["vars"] = vars_
        out[k] = v
    card.clear()
    card.update(out)
    return True


def main():
    d = sys.argv[1] if len(sys.argv) > 1 else "content/cards"
    changed = 0
    for f in sorted(os.listdir(d)):
        if not f.endswith(".json"):
            continue
        p = os.path.join(d, f)
        card = json.load(open(p, encoding="utf-8"))
        if migrate(card):
            changed += 1
            with open(p, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(json.dumps(card, indent=2, ensure_ascii=False) + "\n")
    print("migrated %d cards" % changed)


if __name__ == "__main__":
    main()
