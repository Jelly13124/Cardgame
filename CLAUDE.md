# CardFramework — roguelite deckbuilder (Godot 4.6)

> **始终用中文回复用户(prose、说明、提问全用中文)。** 代码、标识符、文件名、
> commit message、JSON 等仍按项目惯例(多为英文)。这是项目主的硬性要求。

Data-driven roguelite deckbuilder. Gameplay content is JSON, validated at boot by
`battle_scene/data_validator.gd`. GDScript adds behavior only when a new shared
effect / trigger / UI surface is needed.

## Read these first

- `docs/PRD.md` — product scope, systems, roadmap, known tech debt.
- `docs/PROJECT_STRUCTURE.md` — the map: scenes, scripts, data files, asset locations.
- `docs/project-rules.md` — non-negotiable art / asset / naming / architecture rules.
- `docs/conventions/{gameplay-code,ui-code,data-files}.md` — coding conventions + documented deliberate violations.
- `docs/adr/` — architecture decisions. When something seems oddly done, the "why" is usually here. Write a new ADR before adding a major system.

## Load-bearing rules (the ones that bite if ignored)

1. **Claude owns code/data; Codex owns art (ADR-0005).** Claude edits all `.gd`,
   `.tscn`, `.json`, and `docs/`. Codex generates every PNG under
   `battle_scene/assets/images/**` and `run_system/assets/images/**`. Do NOT
   hand-write art or art prompts — write/update an `asset-spec-*.md` contract and
   let Codex deliver. (The `/codex-handoff` skill scaffolds that contract.)
2. **Content is data-driven.** New cards/enemies/relics/equipment = JSON only.
   A new effect/action/status type must be registered in **two** places: the
   handler (`combat_engine._apply_effect()` / `enemy_ai._execute_action()` /
   `status_effect_system`) AND the matching `ALLOWED_*` list in `data_validator.gd`.
   The validator IS the schema.
3. **Wiring is half the job.** JSON alone doesn't appear in-game — cards need a
   draft-pool/unlock entry, enemies need an encounter-pool/roster/`BOSS_BY_FLOOR`
   entry, base upgrades need `UPGRADE_ORDER` + an effect consumer. Use the
   `/new-content` skill — it has the schema AND the exact wiring step per type.
4. **`class_name` is banned for custom classes — use `preload`** (cold editor
   scans fail otherwise; ADR-0006). Autoloads (`RunManager`, `MetaProgress`,
   `Tooltip`) are the exception — reference them directly, never via `get_node_or_null`.
5. **Fail loud at startup for shipped data** (`push_error`/`assert`); warn-only
   with fallback for Codex assets that may still be regenerating.
6. **`addons/` is vendored — never hand-edit it** (card-framework).
   Same for `*.import` / `*.uid` sidecars and `generated_sheet/` intermediates.
   A PreToolUse hook blocks these.

## Verify before finishing

Any `.gd` / `.json` / `.tscn` change must pass the headless smoke gate before the
turn is done (a Stop hook enforces this automatically):

```bash
bash scripts/smoke_test.sh    # GODOT_BIN overrides the godot binary if not on PATH
```

Expected tail: `[OK] DataValidator: all schemas passed.` On this machine Godot is
`C:/Program Files/Godot/Godot_v4.6-stable_win64_console.exe`.

## Project-tuned tooling

- `/new-content <type> <id>` — scaffold a card/enemy/relic/hero/base_upgrade with schema + wiring.
- `/regen-catalogs [type]` — refresh the derivable sections of `docs/catalog-*.md` from JSON.
- `/codex-handoff` — draft the `asset-spec-*.md` + `codex-prompt-*.md` art contract per ADR-0005.
- `gdscript-reviewer` subagent — fast project-tuned pass for this repo's recurring bug classes.
- `content-balance` subagent — checks new content's numbers against the existing power curve.
