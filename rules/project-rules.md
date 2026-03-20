# Project Rules

## Architecture Rules

### Node References
- **NEVER** use `get_parent()` to check if a card is on the battlefield. Use `card_container` property instead.
- **PREFER** `@export` variables for UI node references over hardcoded `$Path` strings.
- **ALWAYS** use `get_node_or_null()` as fallback when exports are not wired in the inspector.
- **ALWAYS** use `is_instance_valid()` before accessing any node that could have been freed.

### Type Safety
- Use `UnitCard.CardType` enum (`UNIT`, `SPELL`, `HERO`) instead of raw string comparisons.
- Use the `_get_card_type()` helper method to convert JSON strings to enum values.
- There is **no BUILDING type** — it was removed.

### Signal-Driven Communication
- Stat changes **must** go through `add_permanent_stats()` or `add_temporary_stats()` to emit `unit_stats_changed`.
- Never modify `attack`/`health` directly without emitting the signal (breaks passive listeners like Robot Bill).

### Decoupled Managers
- All deck/draw operations go through `deck_manager` (not `battle_scene` directly).
- Spells call `main.deck_manager.draw_cards()` not `main._draw_cards()`.

## Card Data Rules

### JSON Requirements
- Every card **must** have: `name`, `display_name`, `type`, `side`, `cost`, `front_image`, `description`.
- Every unit/hero **must** also have: `health`, `attack`, `race`.
- The `"race"` field defaults to `"robot"` if omitted.
- Card `"name"` field must match the JSON filename (without `.json`).

### Keywords
- Keywords work on **all card types**: units, heroes, AND spells.
- Keyword names in JSON must match filenames in `battle_scene/units/keywords/` exactly.
- Do not create new keyword scripts unless adding a genuinely new mechanic.
- Battle Cry style keywords delegate to `custom_script_instance.execute_battle_cry()`.

## Board Rules
- Maximum **7 slots** per battle row (`TOTAL_SLOTS = 7`).
- Never hardcode slot bounds to `3` or `4` — always reference `TOTAL_SLOTS`.

## Art Style Rules
- All card art must be in **Rick and Morty cartoon style**: bold outlines, vibrant colors, exaggerated proportions, sci-fi theme.
- Card art is generated using **Nano Banana** (`generate_image` tool) — never use placeholder images.
- Prompt format: `"Rick and Morty style sci-fi [description], bold outlines, vibrant colors, card game art, no text"`

## UI Rules
- Text rendering relies on **MSDF fonts** — do not use `_crisp_text` scaling workarounds.
- Spell cards hide Attack/Health circles on both Card and Token views.
- Hero cards get gold border (`Color(0.9, 0.75, 0.1)`) and bright name banner.

## Git Rules
- Commit messages should be descriptive of what changed and why.
- Push to `main` branch after confirming changes work in-game.
