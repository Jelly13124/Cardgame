# Workstation Transfer Handoff

## Objective

Preserve the current playable Godot card-game project, its latest visual
direction, and the unfinished non-boss enemy-art work so development can
continue from a fresh clone on another computer without relying on this
machine's Codex conversation history.

Repository:

- GitHub: `https://github.com/Jelly13124/Cardgame.git`
- Transfer branch: `codex/ui-short-circuit-baseline`
- Old-machine workspace: `C:\Users\Jerry\Desktop\Cardgame`
- Pre-transfer committed baseline: `25a2fcf`

The transfer commit that contains this file is the branch head after the final
push. Do not assume that `main` contains this work; explicitly switch to the
transfer branch after cloning.

## Latest User Request

Create a compact handoff that summarizes the durable project decisions and
current unfinished work, then commit and push every current worktree change so
the old computer can be retired.

## Current State

### Completed

- The current branch contains the accepted combat presentation/card-UI
  baseline. There are no pending UI-code changes in this transfer batch.
- Cowboy Bill is the only playable hero. His data lives at
  `C:\Users\Jerry\Desktop\Cardgame\run_system\data\heroes\cowboy_bill.json`.
  He has 50 HP, `animate_idle: false`, and a nine-card starter deck: four
  Shoot, one Weakening Shot, and four Defend.
- Shoot deals 3 damage. Weak reduces outgoing direct attack damage by 50%.
- Short Circuit is stored delayed damage. It does not tick or decay. Every
  `overload` effect consumes all Short Circuit on all living enemies and deals
  the stored damage. Charge Sink additionally gains Block equal to the damage
  dealt by that Overload.
- Bleed and Heat have been removed from the active player systems and must not
  be reintroduced. The authoritative gameplay contracts are
  `C:\Users\Jerry\Desktop\Cardgame\docs\PRD.md` and
  `C:\Users\Jerry\Desktop\Cardgame\docs\conventions\data-files.md`.
- The generated catalog currently contains 45 cards, 30 relics, 15 equipment
  entries, and 20 enemies. Its combined entry point is
  `C:\Users\Jerry\Desktop\Cardgame\docs\catalog_html\index.html`.
- All referenced card, relic, equipment, and enemy art files exist. No player
  card uses the Strike/Defend placeholder, and no two player cards share an
  identical illustration.

### In progress

- Non-boss enemy identities are being rebuilt. Bosses are outside the current
  art-rebuild scope.
- Four enemy identity sets are newer locally than the pre-transfer baseline:
  `armored_patrol`, `chrome_warden`, `ember_wisp`, and
  `wasteland_killer`.
- `ember_wisp` now displays as **Cinder Gullet / 烬喉蜥**.
  `wasteland_killer` now displays as **Wasteland Raider / 废土暴徒** and
  uses an escalating bash rather than an escalating shot.
- The latest low-detail humanoid comparison is tracked at
  `C:\Users\Jerry\Desktop\Cardgame\docs\art\previews\enemy_lowdetail_v3_battle_preview_20260724.png`.

## Decisions and Constraints

### Source-of-truth order

Read these before changing art, UI, content, or architecture:

1. `C:\Users\Jerry\Desktop\Cardgame\AGENTS.md`
2. `C:\Users\Jerry\Desktop\Cardgame\docs\project-rules.md`
3. `C:\Users\Jerry\Desktop\Cardgame\docs\art-style-reference.md`
4. `C:\Users\Jerry\Desktop\Cardgame\docs\enemy-art-direction.md`
5. `C:\Users\Jerry\Desktop\Cardgame\docs\PRD.md`
6. `C:\Users\Jerry\Desktop\Cardgame\docs\PROJECT_STRUCTURE.md`

The paths above identify the files on the old machine; after cloning, use the
same repository-relative paths under the new clone.

### Art direction

- Use original flat 2D American-comic sci-fi-western TV-cartoon art: wobbly
  dark outlines, rubbery but recognizable anatomy, large flat color shapes,
  sparse interior lines, broad cel shadows, funny expressions, and
  medium-low detail.
- The Rick-and-Morty-style influence is a visual-language reference only.
  Never copy existing characters, masks, props, vehicles, locations, logos,
  crops, or exact designs.
- Use real ImageGen output plus the sprite cleanup pipeline for raster art.
  Do not hardcode procedural shapes as final art.
- Current player card art is broadly accepted as a varied collective set.
  Do not mass-regenerate it and do not force every illustration to show Bill.
  Card art remains `512x320`, contains no baked UI/text, and should vary
  composition and palette from card to card.
- The active battle background is deliberately simple so cards and combat
  silhouettes remain readable.

### Enemy identity rules

- Design from combat role and survival function, not literally from the asset
  ID or English name.
- Begin with a recognizable humanoid, complete animal, or simple functional
  salvage machine. No human-animal hybrids, object-with-legs bodies, random
  blobs, or strange anatomy without a wasteland function.
- Humanoids need an immediately visible mutation or a crude face covering such
  as a mask, bucket helmet, hood, or respirator. Plain modern humans in generic
  clothing are not sufficient.
- Express the wasteland through three or four large silhouette/color-block
  cues: broad torn cloth, tire rubber, car-body scrap, a mask, a radiation
  change, and one improvised weapon. Do not use rust speckles, scratch fields,
  rivet rows, strap/pouch clusters, or dense surface texture to fake detail.
- Enemies face left. Keep dominant colors and silhouettes different across the
  roster.
- The owner asked for direct ImageGen iteration for this enemy pass, without a
  separate Superpowers brainstorming/spec flow.

### Animation rules

- The owner plans to generate attack videos and split them into frames.
  Current identity work should not invent large procedural animations.
- Standard enemy attacks use four restrained frames: rest/wind-up, prepare,
  exactly one small hit, and recoil/return. Feet/base stay planted; runtime
  flash, shake, numbers, sound, and hit FX provide weight.
- Do not add constant bobbing or large idle motion. Cowboy Bill's idle loop is
  disabled.
- For the four transferred enemy identity sets, `attack_0` through `attack_3`
  are currently identical static placeholders. They preserve the selected
  identity but are not finished attack animation.

### UI and content guardrails

- Preserve the current lightweight UI07 card frame. Do not regress to heavy
  rendered metal, stacked type bars, permanent glows, or oversized holders.
- Layout rhythm may reference STS2, but its rendered assets, materials, fonts,
  and ornament must not be copied.
- Curse cards have no cost badge and use the established rounded top-corner
  treatment. Card names must remain vertically centered in the title area.
- All in-run pages preserve the shared top bar and begin interactive content
  below its full height.
- Generated catalog HTML is never hand-edited. Change source JSON/translations
  and run `python scripts/gen_catalog_html.py`.

## Files and Changes

This transfer batch contains:

- Sixteen replaced enemy PNGs:
  - `C:\Users\Jerry\Desktop\Cardgame\battle_scene\assets\images\enemies\armored_patrol\attack\`
  - `C:\Users\Jerry\Desktop\Cardgame\battle_scene\assets\images\enemies\chrome_warden\attack\`
  - `C:\Users\Jerry\Desktop\Cardgame\battle_scene\assets\images\enemies\ember_wisp\attack\`
  - `C:\Users\Jerry\Desktop\Cardgame\battle_scene\assets\images\enemies\wasteland_killer\attack\`
- Enemy naming/action data:
  - `C:\Users\Jerry\Desktop\Cardgame\battle_scene\card_info\enemy\ember_wisp.json`
  - `C:\Users\Jerry\Desktop\Cardgame\battle_scene\card_info\enemy\wasteland_killer.json`
  - `C:\Users\Jerry\Desktop\Cardgame\assets\translations\content_enemies.csv`
- Stronger low-detail/mutation/mask rules:
  - `C:\Users\Jerry\Desktop\Cardgame\docs\art-style-reference.md`
  - `C:\Users\Jerry\Desktop\Cardgame\docs\enemy-art-direction.md`
- Regenerated enemy catalog output:
  - `C:\Users\Jerry\Desktop\Cardgame\docs\catalog_html\enemies.html`
  - `C:\Users\Jerry\Desktop\Cardgame\docs\catalog_html\index.html`
- Tracked comparison preview:
  - `C:\Users\Jerry\Desktop\Cardgame\docs\art\previews\enemy_lowdetail_v3_battle_preview_20260724.png`
- This handoff and the documentation-map link to it.

Generated raw ImageGen files under `C:\Users\Jerry\.codex\generated_images\`
and disposable files under `C:\Users\Jerry\Desktop\Cardgame\tmp\` are not
required after cloning; the processed runtime PNGs are in the repository.

## Verification

Completed on 2026-07-24:

- `C:\Users\Jerry\Desktop\Cardgame\scripts\smoke_test.ps1`
  - DataValidator: all schemas passed.
  - Godot headless boot: no script errors, parse failures, or `push_error`.
- `python C:\Users\Jerry\Desktop\Cardgame\scripts\check_missing_art.py`
  - Hard-missing art: 0.
  - Card placeholder art: 0.
  - Reused player-card illustration pairs: 0.
- `python C:\Users\Jerry\Desktop\Cardgame\scripts\gen_catalog_html.py`
  regenerated every catalog page successfully.
- Updated enemy PNGs are `256x256` RGBA with non-empty transparent margins.

Not verified in this final transfer pass:

- A complete A0 run or statistical balance simulation.
- Final owner approval of the newest `armored_patrol` and `chrome_warden`
  identity drawings.
- Finished attack motion for the four static-placeholder enemy sets.

## Open Issues and Risks

1. The four updated enemy sets have static duplicate attack frames. Replace
   frames 1-3 only after owner-approved video/frame extraction; preserve the
   frame-zero identity and restrained one-hit motion.
2. The broader non-boss enemy visual rebuild is not complete. Review each
   remaining frame-zero image against the active battle background and
   `docs/enemy-art-direction.md`; do not mass-regenerate without visual review.
3. The newest bucket-helmet shield mutant and road-sign-mask scavenger are the
   current implementation, but the owner moved to repository transfer before
   explicitly declaring them final.
4. Schema/boot/art checks pass, but they are not proof that the requested A0
   balance target has been met. Use actual playtests before claiming balance.
5. The newest work is on `codex/ui-short-circuit-baseline`, not necessarily
   `main`. Cloning only the default branch can appear to lose the transfer.

## Next Action

On the new computer:

```powershell
git clone https://github.com/Jelly13124/Cardgame.git
Set-Location Cardgame
git switch codex/ui-short-circuit-baseline
git pull --ff-only
& .\scripts\smoke_test.ps1
python .\scripts\check_missing_art.py
Start-Process .\docs\catalog_html\index.html
```

Then compare
`docs/art/previews/enemy_lowdetail_v3_battle_preview_20260724.png` with the
runtime enemy catalog. Confirm or revise the two newest humanoid identities
before producing their actual four-frame attack animations.
