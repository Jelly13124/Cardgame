# Asset Spec — Status Effect Icons (Codex)

> **For Codex (ADR-0005).** 13 combat statuses. Today each badge renders as a
> shared `status_badge_bg.png` (24×24 NinePatch) with a single letter/glyph + stack
> count drawn on top (`battle_scene/status_effect_system.gd` `_refresh_badges`).
> This spec is for **per-status icon art** to replace the letter glyph.

## Deliverable

One PNG per status id below.

- **Target path:** `battle_scene/assets/images/ui/status/<id>.png`
- **Source size:** 64×64, transparent background (displayed at 24×24, so the
  silhouette must read at tiny size — bold, single shape, high contrast).
- **Palette:** lead with each status's theme colour (hex below); keep a dark/!
  outline so it stays legible on the light badge bg and on any character sprite.
- The stack-count number is drawn by code on top — leave the lower-right corner
  relatively clear.

## Wiring note (Claude will do after art lands)

Per-status icons need a small code change: `_refresh_badges` currently draws
`STATUS_LABELS[status]` text. Once these PNGs exist, Claude will swap the letter
Label for a TextureRect that loads `ui/status/<id>.png`, falling back to the
letter if the PNG is missing. No data/JSON change required.

## Statuses

| id | name (en / zh) | effect | theme hex | icon direction |
|----|----------------|--------|-----------|----------------|
| `poison` | Poison / 中毒 | Start of turn: lose 1 HP per stack; decays 1/turn | `#66E633` | dripping toxin drop / skull bubble |
| `burn` | Burn / 燃烧 | Start of turn: take damage = stacks, then cleared | `#FF6619` | flame |
| `weak` | Weak / 虚弱 | Outgoing attack damage −25% | `#B380E6` | drooping / cracked fist |
| `vulnerable` | Vulnerable / 易伤 | Incoming attack damage +50% | `#F27333` | cracked shield / broken armor |
| `double_damage` | Double Damage / 双倍伤害 | Next N attacks deal double | `#33CCFF` | twin blades / ×2 bolt |
| `stun` | Stun / 眩晕 | Enemy skips a turn per stack (enemy-only) | `#F2F24D` | dizzy stars / lightning |
| `regen` | Regen / 再生 | Start of turn: heal = stacks; decays 1/turn | `#4DFF99` | medical cross / heart-leaf |
| `thorns` | Thorns / 荆棘 | When hit, attacker takes stacks damage | `#B3BFCC` | ring of spikes |
| `frail` | Frail / 脆弱 | Block gained −25% | `#9980B3` | shattering shield |
| `dodge` | Dodge / 闪避 | Fully negates one attack; one stack per attack | `#99F2FF` | afterimage / wind swish |
| `metallicize` | Plating / 镀装 | Start of turn: gain stacks Block (persistent) | `#B8CCDB` | layered metal plates |
| `feel_no_pain` | Numb / 镇痛 | On card Exhaust: gain stacks Block (persistent) | `#8CCCF2` | syringe + shield |
| `dark_embrace` | Salvage / 回收 | On card Exhaust: draw stacks cards (persistent) | `#B86BDB` | recycle arrows + card |

(Display names live in `assets/translations/ui_combat.csv` as
`UI_COMBAT_STATUS_<ID>` / `_DESC`. The last three are the StS2-port powers.)
