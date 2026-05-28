"""
Catalog stats generator (read-only).

Scans the data-driven JSON content and prints the *derivable* catalog
sections — counts, breakdowns, the summary table, and on-disk art presence —
to stdout. It NEVER writes files: the docs/catalog-*.md files also carry
hand-authored prose (flavor, design notes) that must be preserved, so the
caller (the /regen-catalogs skill) merges the fresh tables in by hand.

Usage:
    python scripts/gen_catalogs.py [cards|enemies|relics|equipment|all]

Default target is "all". Output is plain Markdown.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CARDS_DIR = ROOT / "battle_scene" / "card_info" / "player"
ENEMIES_DIR = ROOT / "battle_scene" / "card_info" / "enemy"
RELICS_DIR = ROOT / "run_system" / "data" / "relics"
EQUIPMENT_DIR = ROOT / "run_system" / "data" / "equipment"

CARD_ART_BASE = ROOT / "battle_scene" / "assets" / "images" / "cards"
ENEMY_ART_BASE = ROOT / "battle_scene" / "assets" / "images" / "enemies"
EQUIP_ART_BASE = ROOT / "battle_scene" / "assets" / "images"
RUN_MANAGER = ROOT / "run_system" / "core" / "run_manager.gd"

YES = "✅"   # white check mark
NO = "❌"    # cross mark

SCALE_ABBR = {
    "strength": "STR",
    "constitution": "CON",
    "intelligence": "INT",
    "luck": "LUCK",
    "charm": "CHARM",
}


def _load_json(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 — surface the bad file, keep going
        print(f"  > WARN: could not parse {path.name}: {exc}", file=sys.stderr)
        return None


def _art(present: bool) -> str:
    return YES if present else NO


# --------------------------------------------------------------------------- #
# Cards
# --------------------------------------------------------------------------- #

def _effect_str(eff: dict) -> str | None:
    t = eff.get("type", "")
    amt = eff.get("amount")
    scaling = eff.get("scaling")
    suffix = f" (+{SCALE_ABBR[scaling]})" if scaling in SCALE_ABBR else ""
    if t == "exhaust_self":
        return None  # surfaced as a keyword, not an effect
    if t in ("deal_damage", "deal_damage_all", "gain_block"):
        return f"{t} {amt}{suffix}"
    if t == "scale_damage_by_attacks":
        return f"scale_damage_by_attacks (base={eff.get('base')}, per={eff.get('per')})"
    if t in ("gain_energy", "draw_cards"):
        return f"{t} {amt}"
    if t.startswith("gain_"):  # gain_strength / _constitution / ...
        return f"{t} {amt}"
    if t in ("apply_status", "apply_status_self", "apply_status_all"):
        return f"{t} {eff.get('status')} {eff.get('stacks')}"
    if t in ("apply_shock", "apply_shock_all"):
        return f"{t} {eff.get('stacks', eff.get('amount'))}"
    # Unknown / new effect type — print raw so it shows up for review.
    extras = {k: v for k, v in eff.items() if k != "type"}
    return f"{t} {extras}" if extras else t


def gen_cards() -> str:
    cards = []
    for path in sorted(CARDS_DIR.glob("*.json")):
        if path.stem.endswith("_plus"):
            continue
        data = _load_json(path)
        if data:
            data["_id"] = path.stem
            cards.append(data)

    rarities = ["common", "uncommon", "rare"]
    by_rarity = {r: [c["_id"] for c in cards if c.get("rarity") == r] for r in rarities}
    by_type: dict[str, int] = {}
    retain, exhaust = [], []
    for c in cards:
        by_type[c.get("type", "?")] = by_type.get(c.get("type", "?"), 0) + 1
        if c.get("retain"):
            retain.append(c["_id"])
        if any(e.get("type") == "exhaust_self" for e in c.get("effects", [])):
            exhaust.append(c["_id"])

    out = [
        "# Cards Catalog",
        "",
        f"**Last updated:** {date.today().isoformat()}",
        f"**Total cards:** {len(cards)} (excludes `_plus` upgrade variants)",
        "",
        "## Quick stats",
        "",
        "| Rarity | Count | IDs |",
        "|---|---|---|",
    ]
    for r in rarities:
        ids = ", ".join(by_rarity[r]) or "—"
        out.append(f"| {r.capitalize()} | {len(by_rarity[r])} | {ids} |")
    out += ["", "| Type | Count |", "|---|---|"]
    for t, n in sorted(by_type.items()):
        out.append(f"| {t.capitalize()} | {n} |")
    out += ["", "| Keyword | Cards |", "|---|---|"]
    out.append(f"| Retain | {', '.join(retain) or '—'} |")
    out.append(f"| Exhaust | {', '.join(exhaust) or '—'} |")

    out += [
        "",
        "## Summary table",
        "",
        "| ID | Title | Type | Cost | Rarity | Effects | Keywords | Art |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for c in sorted(cards, key=lambda x: x["_id"]):
        effs = [s for s in (_effect_str(e) for e in c.get("effects", [])) if s]
        kw = []
        if c.get("retain"):
            kw.append("Retain")
        if any(e.get("type") == "exhaust_self" for e in c.get("effects", [])):
            kw.append("Exhaust")
        front = c.get("front_image", "")
        art_ok = bool(front) and (CARD_ART_BASE / front).exists()
        out.append(
            f"| `{c['_id']}` | {c.get('title', '')} | {c.get('type', '')} | "
            f"{c.get('cost', '')} | {c.get('rarity', '')} | {'; '.join(effs)} | "
            f"{', '.join(kw) or '—'} | {_art(art_ok)} |"
        )
    return "\n".join(out)


# --------------------------------------------------------------------------- #
# Enemies
# --------------------------------------------------------------------------- #

def _enemy_tiers() -> dict[str, str]:
    """Best-effort tier per enemy id by locating which encounter constant in
    run_manager.gd references it. Verify against the source — this is a regex
    heuristic, not a parse."""
    tiers: dict[str, str] = {}
    if not RUN_MANAGER.exists():
        return tiers
    text = RUN_MANAGER.read_text(encoding="utf-8", errors="replace")
    # constant name -> tier label, in rough precedence order
    consts = [
        ("ENCOUNTER_POOLS_EARLY", "standard"),
        ("ENCOUNTER_POOLS_MID", "standard"),
        ("ENCOUNTER_POOLS_LATE", "standard"),
        ("ELITE_ROSTER", "elite"),
        ("BOSS_BY_FLOOR", "boss"),
    ]
    # region of each constant = its declaration until the next top-level
    # declaration (const/var/func/@annotation), so a literal like BOSS_BY_FLOOR
    # can't bleed into unrelated later code and misclassify an id.
    regions = []
    decl = re.compile(r"\n(?:const |var |func |@)")
    for name, tier in consts:
        m = re.search(rf"\b{name}\b", text)
        if not m:
            continue
        start = m.start()
        nxt = decl.search(text, start + len(name))
        end = nxt.start() if nxt else len(text)
        regions.append((start, end, tier))
    precedence = {"standard": 1, "elite": 2, "boss": 3}
    for path in ENEMIES_DIR.glob("*.json"):
        eid = path.stem
        best = None
        for start, end, tier in regions:
            if re.search(rf'"{re.escape(eid)}"', text[start:end]):
                if best is None or precedence[tier] > precedence[best]:
                    best = tier
        tiers[eid] = best or "UNLISTED"
    return tiers


def gen_enemies() -> str:
    enemies = []
    for path in sorted(ENEMIES_DIR.glob("*.json")):
        data = _load_json(path)
        if data:
            data["_id"] = path.stem
            enemies.append(data)
    tiers = _enemy_tiers()

    out = [
        "# Enemies Catalog",
        "",
        f"**Last updated:** {date.today().isoformat()}",
        f"**Total combatants:** {len(enemies)}",
        "",
        "## Summary table",
        "",
        "_Tier is a best-effort read of `run_manager.gd` encounter constants — "
        "`UNLISTED` means the enemy JSON exists but is in no pool/roster (it will "
        "never spawn). Verify before trusting._",
        "",
        "| ID | Name | HP | Tier | Sprite ID | Pattern length | Frames |",
        "|---|---|---|---|---|---|---|",
    ]
    for e in sorted(enemies, key=lambda x: x["_id"]):
        sprite = e.get("sprite_id", "")
        frame0 = ENEMY_ART_BASE / sprite / "attack" / f"{sprite}_attack_0.png"
        pattern = e.get("action_pattern", [])
        out.append(
            f"| `{e['_id']}` | {e.get('name', '')} | {e.get('max_health', '')} | "
            f"{tiers.get(e['_id'], '?')} | `{sprite}` | {len(pattern)} | "
            f"{_art(frame0.exists())} |"
        )
    unlisted = [eid for eid, t in tiers.items() if t == "UNLISTED"]
    if unlisted:
        out += ["", f"> WARNING: UNLISTED (won't spawn): {', '.join(sorted(unlisted))}"]
    return "\n".join(out)


# --------------------------------------------------------------------------- #
# Relics
# --------------------------------------------------------------------------- #

def gen_relics() -> str:
    relics = []
    for path in sorted(RELICS_DIR.glob("*.json")):
        data = _load_json(path)
        if data:
            data["_id"] = path.stem
            relics.append(data)

    rarities = ["common", "uncommon", "rare"]
    by_rarity = {r: sum(1 for x in relics if x.get("rarity") == r) for r in rarities}

    out = [
        "# Relics Catalog",
        "",
        f"**Last updated:** {date.today().isoformat()}",
        f"**Total relics:** {len(relics)}",
        "",
        "## Quick stats",
        "",
        "| Rarity | Count |",
        "|---|---|",
    ]
    for r in rarities:
        out.append(f"| {r.capitalize()} | {by_rarity[r]} |")
    out += [
        "",
        "## Summary table",
        "",
        "| ID | Title | Rarity | Trigger | Effect | Once/combat | Icon |",
        "|---|---|---|---|---|---|---|",
    ]
    for x in sorted(relics, key=lambda v: v["_id"]):
        effs = x.get("effects", [{}])
        e0 = effs[0] if effs else {}
        trig = e0.get("trigger", "")
        if e0.get("round") is not None:
            trig += f" (round {e0['round']})"
        effstr = f"{e0.get('type', '')} {e0.get('amount', '')}".strip()
        once = "✓" if e0.get("once_per_combat") else "—"
        icon = x.get("icon", "").replace("res://", "")
        icon_ok = bool(icon) and (ROOT / icon).exists()
        out.append(
            f"| `{x['_id']}` | {x.get('title', '')} | {x.get('rarity', '')} | "
            f"{trig} | {effstr} | {once} | {_art(icon_ok)} |"
        )
    return "\n".join(out)


# --------------------------------------------------------------------------- #
# Equipment (bonus — no hand-authored catalog exists yet)
# --------------------------------------------------------------------------- #

def gen_equipment() -> str:
    items = []
    for path in sorted(EQUIPMENT_DIR.glob("*.json")):
        data = _load_json(path)
        if data:
            data["_id"] = path.stem
            items.append(data)

    out = [
        "# Equipment Catalog",
        "",
        f"**Last updated:** {date.today().isoformat()}",
        f"**Total equipment:** {len(items)}",
        "",
        "| ID | Name | Slot | Rarity | Set | Bonuses | Icon |",
        "|---|---|---|---|---|---|---|",
    ]
    for x in sorted(items, key=lambda v: v["_id"]):
        bonuses = ", ".join(f"{k} +{v}" for k, v in (x.get("bonuses") or {}).items())
        sprite = x.get("sprite", "")
        icon_ok = bool(sprite) and (EQUIP_ART_BASE / sprite).exists()
        out.append(
            f"| `{x['_id']}` | {x.get('name', '')} | {x.get('slot', '')} | "
            f"{x.get('rarity', '')} | {x.get('set_id', '—')} | {bonuses or '—'} | "
            f"{_art(icon_ok)} |"
        )
    return "\n".join(out)


GENERATORS = {
    "cards": gen_cards,
    "enemies": gen_enemies,
    "relics": gen_relics,
    "equipment": gen_equipment,
}


def main(argv: list[str]) -> int:
    target = (argv[1] if len(argv) > 1 else "all").lower()
    if target == "all":
        chosen = list(GENERATORS)
    elif target in GENERATORS:
        chosen = [target]
    else:
        print(f"Unknown target '{target}'. Use: {', '.join(GENERATORS)}, all", file=sys.stderr)
        return 2
    blocks = [GENERATORS[name]() for name in chosen]
    print(("\n\n" + "=" * 72 + "\n\n").join(blocks))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
