# Base UI + Shop/Forge + Tool-System Overhaul — Overnight (2026-06-25)

**Branch:** overnight-0615 · **Mode:** `/goal` autonomous, "usual way".
Smoke-gate + **off-screen MCP screenshot verification** (background:true, no window) per phase.
Commit per phase. **Don't push.** Strip the temporary McpBridge from project.godot at the end.

## Tasks (owner's list, in order)
1. **Market (黑市) shelf** — equipment shown as a grid of item cards (icon + rarity border +
   name + price + buy), not a text list. Card-unlock section shows **real card art**, not text.
2. **Building tier-upgrade → moved to the base overview** — next to each floating "Lv<n> Name"
   label, add an upgrade button (with cost) → **confirmation popup** → upgrade. Drop the
   "升级到 T2" action card from the detail page (detail page = services only).
3. **Warehouse (仓库)** — hero select shows the **hero portrait/image** (not just text); empty
   stash cells render a **slot-frame UI** (not blank).
4. **Forge (铁匠铺) redesign** — left = stash list, right = a single **reforge/dismantle slot**.
   Drag equipment in → list its **affixes** → choose **Dismantle** (→ scrap) or **Reforge**;
   **Reforge lets you pick which affix** to reroll.
5. **Tool system rework** — tool slots → **1 base slot**; extra tools **stored in the backpack**;
   an **equip-tool system** (move a tool from backpack into the slot); a **relic that grants
   +1 tool slot**.

## Phases
- **P1 — Upgrade-on-overview** (task 2): overview floating label + upgrade button + confirm
  dialog (all 5 buildings); remove the detail-page action card. Foundational (changes the
  detail-page frame).
- **P2 — Market shelf** (task 1): equipment item-card grid + real card art for the unlock list.
- **P3 — Warehouse** (task 3): hero portrait + empty stash slot frames.
- **P4 — Forge** (task 4): stash + reforge slot, affix list, dismantle/reforge, reforge-by-affix.
- **P5 — Tool system** (task 5): 1 slot + backpack-held tools + equip system + `+1 tool slot`
  relic (JSON + RelicEffectSystem + data_validator + wiring).
- **P6 — Verify + report**: full smoke, regen catalog (new relic), update PRD/PROJECT_STRUCTURE,
  strip McpBridge, overnight report.

## Guardrails
- New relic/effect → register handler **and** the `ALLOWED_*` list in `data_validator.gd`; wire
  into the relic pool. New content → catalog regen.
- Tool rework touches RunManager (tool state) + run_top_bar (UI) + backpack — keep saves
  back-compatible (migrate old tool_inventory/slots).
- Verify each UI phase with an MCP screenshot before committing.
- gdscript-reviewer pass on the system changes (forge reforge, tool rework) before final commit.
