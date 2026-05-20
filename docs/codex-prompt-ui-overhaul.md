# Codex Prompt — UI Overhaul Slice 1A

Copy everything below the `---` line into your Codex session.

---

You are working in the Godot 4.6 project at `C:\Users\Jerry\Desktop\Cardgame` — a roguelite deckbuilder with a strict **Hardcore 128 Pixel Wasteland Art** style. The game has 87 sprite assets you already generated (cards, enemies, heroes, FX, backgrounds). Now we are entering a UI overhaul: **redoing the 2D UI components (panels, buttons, HP bars, card frames, intent icons)** to match the rest of the art.

## Step 1 — Read these files before doing anything else

1. **`docs/asset-spec-ui-overhaul.md`** — your authoritative work order. Lists every PNG, exact paths, dimensions, 9-slice margins, palette to anchor against, per-component prompt hints. This is the canonical spec.
2. **`tools/palette_report.md`** — the canonical 14-color palette sampled from your existing art. Every new UI component must visually anchor on these colors. The palette is **already final**; do not propose new colors.
3. **`docs/adr/0008-art-pivot-to-hardcore-128-pixel-wasteland.md`** — the style ADR you've been working against.
4. **`docs/adr/0010-third-palette-recalibration.md`** — why this palette was chosen and from which sprites.
5. **`docs/project-rules.md`** §1–§5 — non-negotiable wasteland style rules + pipeline conventions.

Also look at one reference of each asset type that already exists in the project, so component-level detail matches existing scale and weight:
- Existing card art: `battle_scene/assets/images/cards/player/strike.png`
- Existing enemy sprite: `battle_scene/assets/images/enemies/trash_robot/idle/trash_robot_idle_0.png`
- Existing UI components (the **OLD STYLE** ones you are replacing): `battle_scene/assets/images/ui/` and `battle_scene/assets/images/cards/ui/`

## Step 2 — Deliverables

**18 UI components → 19 PNGs total** (button has 3 states, intent has 4 variants):

| Category | Components | NEW or REPLACE |
|---|---|---|
| Panels (9-slice) | `panel_default`, `panel_dark` | 2 NEW |
| Buttons (9-slice, 3 states) | `button_normal/hover/pressed` | 3 NEW |
| Battle HUD | `hp_bar_frame`, `hp_bar_fill`, `block_badge`, `status_badge_bg` | 3 REPLACE + 1 NEW |
| Intent badges | `intent_attack/block/buff/charge` | 3 REPLACE + 1 NEW |
| Cards | `card_bg`, `card_back`, `art_frame_common/uncommon/rare` | 5 REPLACE |

Full per-component spec (dimensions, 9-slice margins, prompt hints, file paths): **`docs/asset-spec-ui-overhaul.md` §2**.

## Step 3 — Pipeline rules (non-negotiable)

These come from `docs/project-rules.md` §2–§5. Follow exactly:

1. **Every prompt** must preserve the Hardcore 128 Pixel Wasteland Art style anchor. The palette in `tools/palette_report.md` is the **authoritative color reference** — your generated UI must visually anchor on those hex codes. Don't introduce colors outside the palette unless the prompt hint in §2 explicitly says so.
2. **Native resolution**: 128 px for hand-painted UI components (panels, frames). 64 px or 32 px is OK for small icons (status badges, intent icons) where 128 wastes space — see per-component spec.
3. **9-slice components** (anything that needs to stretch — panels, buttons, bar frames) MUST have art-safe corner margins. Recommended: 16 px corners for 128 px components, 8 px corners for 64 px, 4 px corners for very small. The middle row/column should be tileable WITHOUT visible seams.
4. **Sheet generation background**: solid `#FF00FF` (magenta) for chroma-key cleanup during generation. Final per-frame PNG outputs must be **transparent PNG**.
5. **Card art has no text, no logos baked in** — text is rendered by Godot at runtime.
6. **REPLACE assets** must keep the same filename + path so Godot re-imports automatically (the `.import` sidecar's UID is reused, so consumer code doesn't need to update).
7. **NEW assets** go to the paths listed in the spec; do not invent alternate locations.
8. **Intermediate pipeline sheets** (raw, magenta, pre-chroma) stay in a `generated_sheet/` subfolder beside the final assets. Do not commit them next to the final PNGs.

## Step 4 — Style anchor checklist

For every component, before submitting:
- [ ] Color palette is anchored on the 14 canonical colors from `palette_report.md`
- [ ] Style matches the existing card art (`strike.png`) and enemy sprite (`trash_robot/idle/0.png`)
- [ ] Bold dark outlines (LEATHER_DARK `#302010` or close) on all visible edges
- [ ] 9-slice components have stretchable middle (no detail crossing the corner margins)
- [ ] Wasteland aesthetic: rivets, dents, weathering, NOT clean modern UI
- [ ] No neon accent abused as a base color — accents are highlights only

## Step 5 — Order of operations (suggested)

You can deliver in any order — each component is independently consumed. Suggested order to maximize player-visible progress:

1. **Battle HUD first** (REPLACE existing): hp_bar_frame, hp_bar_fill, block_badge, intent_*. These light up immediately in any battle.
2. **Cards next** (REPLACE existing): card_bg, card_back, art_frame_*. Visible every card draw.
3. **NEW components last**: panel_default, panel_dark, button_*, status_badge_bg, intent_charge. Wired up later by Claude in Slice 1B/1C/1D.

## Step 6 — Don't touch

These already exist and must NOT be regenerated:
- `battle_scene/assets/images/heroes/cowboy_bill/*`
- `battle_scene/assets/images/enemies/*` (all enemy sprite folders)
- `battle_scene/assets/images/fx/*`
- `battle_scene/assets/images/cards/player/*` (card illustrations themselves — only frames around them are in scope)
- `battle_scene/assets/images/backgrounds/*`
- `run_system/assets/images/*` (map, loot icons, relic icons)
- Any `.import` file
- Any `.gd`, `.tscn`, `.json` file (Claude owns all gameplay code and content; you own UI art only)

## Step 7 — When you're done

1. Print a delivery summary listing every PNG you wrote, its path, and pixel dimensions.
2. Highlight any component you skipped or had a question about, with the reason.
3. Note any palette adjustments you'd suggest based on practice (Claude will read these and may update `palette_report.md` for the next slice).
4. Do NOT commit. Leave staged/unstaged state alone — the human reviews and commits.

## Step 8 — Coordination with Claude (parallel work)

While you generate art, Claude is writing Slice 1A's code-side deliverables (theme palette update, ADR, etc.) and brainstorming Slice 1B (card render integration). When you deliver assets:
- **REPLACE assets** light up immediately in-game on next editor open
- **NEW assets** sit in the folder until Claude wires them in (Slice 1B/1C/1D)

If you find a component too ambiguous to draw without a follow-up question, stop and ask the human — don't guess. Hardcore 128 Pixel Wasteland style consistency matters more than throughput.
