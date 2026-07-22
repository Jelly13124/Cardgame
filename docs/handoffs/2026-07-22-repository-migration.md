# Repository Migration Handoff — 2026-07-22

## Objective

Leave the Godot project in a clone-ready, evidence-backed state before the
current computer is retired. The authoritative local checkout during this audit
was `C:\Users\Jerry\Desktop\Cardgame`; on a new computer, treat paths below as
repo-relative after cloning.

The cloud handoff target is:

- Repository: `https://github.com/Jelly13124/Cardgame.git`
- Branch: `codex/ui-short-circuit-baseline`
- Draft PR: `https://github.com/Jelly13124/Cardgame/pull/1`
- Base branch: `main`

## Latest User Request

“审查项目过时的文档和代码，然后写handoff文档，然后push到云端，这个电脑要废弃了，新的电脑要从github clone然后接手这个项目”

## Current State

- Engine: Godot 4.6 stable. No package-manager bootstrap is required.
- The public demo remains Cowboy Bill-only and one act, ending at Rust Titan.
- Player content is 45 card JSON files: 13 Attacks, 21 Skills, 6 Abilities,
  and 5 Curses. The starter deck is 4 Shoot, 1 Weakening Shot, and 4 Defend.
- The focused Bill demo reward pool contains 28 cards and is defined in
  `C:\Users\Jerry\Desktop\Cardgame\run_system\core\meta_progress.gd`.
- Bleed and Heat are removed. Short Circuit stores delayed damage; Overload
  consumes all Short Circuit on all enemies. Weak reduces outgoing attack damage
  by 50%.
- The current card UI uses the unified Cowboy Bill shell plus a dedicated
  no-cost curse shell. Card titles were optically raised and visually checked in
  the ignored local capture `C:\Users\Jerry\Desktop\Cardgame\tmp\card-title-centering-runtime.png`.
- All 45 card JSONs reference present, non-placeholder, non-duplicate card art.
- `C:\Users\Jerry\Desktop\Cardgame\docs\catalog_html\index.html` was regenerated
  from current data and reports 45 cards, 30 relics, 15 equipment definitions,
  20 enemies, 11 tools, 10 bounties, 12 events, 11 affixes, and 28 keywords.
- The migration branch intentionally remains separate from `main`; use the draft
  PR for review/merge. The branch's pre-migration baseline was commit `81c1284`.

## Decisions and Constraints

- `docs/project-rules.md` and `docs/art-style-reference.md` are the visual and
  architecture sources of truth. UI stays UI07; visual rhythm may reference
  another game, but rendered assets, fonts, chrome, and exact card designs may
  not be copied.
- `battle_scene/assets/images/cards/player/strike.png` is the only approved
  controlled-detail card-art exemplar until more legacy art is explicitly
  approved. Card art remains 512×320 PNG with no baked UI or text.
- Keep legacy ids that preserve saves even when their displayed identity changed:
  `hemorrhage.json` displays Critical Discharge; `blood_kit` displays Circuit
  Kit; `toxin_vial` displays Capacitor Spike. Removed-card migration entries in
  `run_system/core/run_manager.gd` and absence assertions in tests are deliberate,
  not dead code.
- Game data is authoritative over old plans. Regenerate the catalog with
  `python scripts/gen_catalog_html.py`; never hand-edit generated HTML.
- Do not commit `.gemini_key`, `.mcp.json`, `.env`, `.godot/`, or `tmp/`. Those are
  correctly ignored and are not part of the cloud migration.
- Git does not carry Godot `user://` profiles or run saves. A fresh clone starts
  with fresh local player data unless saves are migrated separately and privately.

## Files and Changes

- Canonical documentation updated:
  `C:\Users\Jerry\Desktop\Cardgame\docs\PRD.md`,
  `C:\Users\Jerry\Desktop\Cardgame\docs\PROJECT_STRUCTURE.md`,
  `C:\Users\Jerry\Desktop\Cardgame\docs\conventions\data-files.md`, and
  `C:\Users\Jerry\Desktop\Cardgame\docs\conventions\gameplay-code.md` now match
  the current card count, 28-card pool, contract-test suite, Short Circuit /
  Overload behavior, Weak 50%, and active status/effect registries.
- `C:\Users\Jerry\Desktop\Cardgame\docs\README.md` now separates current sources
  of truth, generated references, and historical records.
- The old StS2 port table, Gem asset request, and status-icon request were replaced
  with explicit superseded/current-runtime documents. The stale generated
  `docs/catalog_html/proposed.html` was removed.
- Obsolete root workflow/session artifacts were removed: `CLAUDE.md`,
  `findings.md`, `progress.md`, `task_plan.md`, and `tscn_files.txt`.
- Runtime remnants of removed Bleed/old statuses were removed from
  `C:\Users\Jerry\Desktop\Cardgame\scripts\gen_audio.py`, audio assets, status
  icons, and obsolete generated status-icon intermediates. Generic direct HP-loss
  comments no longer describe deleted blood cards.
- The broader migration snapshot also contains the existing uncommitted Cowboy
  Bill card-system/UI/art pass: 10 removed legacy cards, the new Kinetic Baffle
  card, revised Short Circuit/Overload cards and translations, unified/curse card
  shells, title/type presentation, varied replacement card illustrations, updated
  tests, and regenerated catalogs.

## Verification

Verified on 2026-07-22 from `C:\Users\Jerry\Desktop\Cardgame`:

- `python scripts/gen_catalog_html.py` — passed; all 9 catalog tabs regenerated.
- `C:\Program Files\Godot\Godot.exe --headless --path . --quit-after 5` through
  `scripts/smoke_test.ps1` — DataValidator passed and headless boot was clean.
- All 15 `tests/*_contract_test.tscn` scenes — passed, including Gunslinger,
  Short Circuit, demo content/pool, encounter balance, combat feedback, UI HUD,
  transitions, inventory, forge, shop, and tool-confirmation contracts.
- `python scripts/check_missing_art.py` — 0/45 missing card art, 0/45 placeholder
  card art, 0/45 duplicate card art; no hard-missing relic/equipment/enemy assets.
- Current tracked-tree secret-pattern scan — no candidate current-tree secrets.
  `.gemini_key` and `.mcp.json` remain ignored and were not staged.
- `git diff --check` — no whitespace errors; generated HTML only reports the
  repository's existing CRLF-to-LF normalization warning.
- `git fsck --full --no-progress` — no corrupt reachable objects. It reports many
  harmless dangling/local temporary objects; a fresh clone will not need them.

## Open Issues and Risks

- `barbed_plating` and `intimidator_plate` still share one relic icon. This is the
  only bespoke-art duplication reported by `scripts/check_missing_art.py`.
- Active statuses `deadeye`, `overload_protocol`, `reactive_plating`, and `loaded`
  currently use the runtime glyph fallback because dedicated PNG icons are absent.
- `blood_kit` and `toxin_vial` keep legacy ids and their existing icons predate the
  Circuit Kit / Capacitor Spike rename; perform a future visual review.
- Historical Git commits exposed a PixelLab credential. The current tree reads
  `PIXELLAB_API_KEY` from the environment, but the old credential must be rotated
  at the provider because deleting it from the current tree does not erase history.
- `steam_appid.txt` is still test App ID 480; configure the real Steam App ID and
  store URL before release.
- Final windowed QA is still required across supported aspect ratios. Headless
  contracts do not prove animation feel, drag targeting, or every layout crop.
- On this computer, `Godot_v4.6-stable_win64_console.exe` points to a missing
  sibling executable. `C:\Program Files\Godot\Godot.exe` passed all validation.
  Install a complete Godot 4.6 stable build on the new computer.
- Local Git storage contains roughly 314 MiB of packed history plus unreachable
  objects. A fresh clone is the preferred cleanup; do not copy the old `.git`
  directory by hand.

## Next Action

On the new computer:

```powershell
git clone https://github.com/Jelly13124/Cardgame.git
Set-Location Cardgame
git switch --track origin/codex/ui-short-circuit-baseline
git status -sb
```

Install Godot 4.6 stable and Python 3, then run:

```powershell
$env:GODOT_BIN = (Get-Command Godot.exe).Source
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke_test.ps1
python scripts/gen_catalog_html.py
python scripts/check_missing_art.py
gh pr view 1 --repo Jelly13124/Cardgame --web
```

Confirm the clone is clean and the draft PR contains this handoff. Then continue
from PR #1 or merge it into `main` after visual review. Recreate any required API
credentials as environment variables or ignored local files; do not copy them
into the repository. If old playtest saves matter, migrate Godot `user://` data
separately before disposing of the old machine.
