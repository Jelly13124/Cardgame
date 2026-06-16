#!/usr/bin/env python3
"""Audit which data-referenced art is missing or still a placeholder.

Read-only. Cross-references card/relic/equipment/enemy/status JSON against the
PNGs on disk and reports: MISSING (referenced, no file) and PLACEHOLDER (card art
byte-identical to strike.png / defend.png). Codex owns the fixes (ADR-0005).
"""
import hashlib
import json
import os
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

CARD_DIR = ROOT / "battle_scene/card_info/player"
CARD_ART_BASE = ROOT / "battle_scene/assets/images/cards"
RELIC_DIR = ROOT / "run_system/data/relics"
EQUIP_DIR = ROOT / "run_system/data/equipment"
EQUIP_ART_BASE = ROOT / "battle_scene/assets/images"
ENEMY_DIR = ROOT / "battle_scene/card_info/enemy"
ENEMY_ART_BASE = ROOT / "battle_scene/assets/images/enemies"


def res_to_fs(p: str) -> pathlib.Path:
    return ROOT / p.replace("res://", "")


def md5(path: pathlib.Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest() if path.exists() else ""


def load(p: pathlib.Path):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        return {"__error__": str(e)}


def main() -> None:
    placeholder_hashes = {}
    for ph in ("strike.png", "defend.png"):
        f = CARD_ART_BASE / "player" / ph
        if f.exists():
            placeholder_hashes[md5(f)] = ph

    missing_cards, placeholder_cards = [], []
    hash_to_cards = {}  # md5 -> [card ids]  (to catch reused/duplicate art)
    for jf in sorted(CARD_DIR.glob("*.json")):
        d = load(jf)
        fi = d.get("front_image", "")
        if not fi:
            missing_cards.append(f"{jf.stem}: (no front_image field)")
            continue
        art = CARD_ART_BASE / fi
        if not art.exists():
            missing_cards.append(f"{jf.stem}  ->  cards/{fi}")
        else:
            h = md5(art)
            hash_to_cards.setdefault(h, []).append(jf.stem)
            if h in placeholder_hashes:
                placeholder_cards.append(f"{jf.stem}  (= {placeholder_hashes[h]})")

    dup_cards = [cards for cards in hash_to_cards.values() if len(cards) > 1]

    missing_relics = []
    for jf in sorted(RELIC_DIR.glob("*.json")):
        d = load(jf)
        icon = d.get("icon", "")
        if not icon:
            continue  # some relics may legitimately have no icon field
        if not res_to_fs(icon).exists():
            missing_relics.append(f"{jf.stem}  ->  {icon}")

    missing_equip = []
    for jf in sorted(EQUIP_DIR.glob("*.json")):
        d = load(jf)
        spr = d.get("sprite", "")
        if not spr:
            continue
        if not (EQUIP_ART_BASE / spr).exists():
            missing_equip.append(f"{jf.stem}  ->  {spr}")

    missing_enemies = []
    for jf in sorted(ENEMY_DIR.glob("*.json")):
        d = load(jf)
        sid = d.get("sprite_id", "")
        if not sid:
            missing_enemies.append(f"{jf.stem}: (no sprite_id)")
            continue
        frame0 = ENEMY_ART_BASE / sid / "attack" / f"{sid}_attack_0.png"
        if not frame0.exists():
            missing_enemies.append(f"{jf.stem}  ->  enemies/{sid}/attack/{sid}_attack_0.png")

    def section(title, items, total):
        print(f"\n=== {title}  ({len(items)} / {total}) ===")
        if not items:
            print("  OK all present")
        for it in items:
            print(f"  X  {it}")

    n_cards = len(list(CARD_DIR.glob("*.json")))
    n_relics = len(list(RELIC_DIR.glob("*.json")))
    n_equip = len(list(EQUIP_DIR.glob("*.json")))
    n_enemies = len(list(ENEMY_DIR.glob("*.json")))

    print("ART AUDIT - referenced in data but MISSING on disk")
    section("CARDS missing art", missing_cards, n_cards)
    section("CARDS on placeholder (strike/defend copy)", placeholder_cards, n_cards)
    section(
        "CARDS sharing identical art (reused image)",
        [" + ".join(c) for c in dup_cards],
        n_cards,
    )
    section("RELIC icons missing", missing_relics, n_relics)
    section("EQUIPMENT sprites missing", missing_equip, n_equip)
    section("ENEMY attack frames missing", missing_enemies, n_enemies)

    total_missing = (
        len(missing_cards)
        + len(missing_relics)
        + len(missing_equip)
        + len(missing_enemies)
    )
    print(f"\nTOTAL hard-missing (excl. placeholders): {total_missing}")
    print(f"Cards still on placeholder art: {len(placeholder_cards)}")


if __name__ == "__main__":
    main()
