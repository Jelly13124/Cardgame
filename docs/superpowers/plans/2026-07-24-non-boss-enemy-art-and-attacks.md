# Non-Boss Enemy Art and Attacks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all 17 non-boss enemy definitions with distinct, original nuclear-wasteland TV-cartoon identities and restrained four-frame attacks.

**Architecture:** Enemy gameplay data remains data-driven. Existing unique enemies keep their `sprite_id`; five definitions that currently borrow another body receive a matching unique `sprite_id` and asset folder. Every attack is generated as an exact `2x2` magenta sheet, deterministically converted to four aligned `256x256` RGBA frames, and loaded by the unchanged `EnemyEntity` animation path.

**Tech Stack:** Godot 4.6, GDScript, JSON, built-in ImageGen, Pillow-based `generate2dsprite.py`, PowerShell, PNG.

## Global Constraints

- Read `docs/project-rules.md`, `docs/art-style-reference.md`, and `docs/superpowers/specs/2026-07-24-non-boss-enemy-art-and-attacks-design.md` before generating any asset.
- Read and follow the `imagegen` and `generate2dsprite` skills before using their tools.
- Do not use the current English enemy name as the creative subject description. Use the roster identity brief and combat read from the spec.
- Preserve the mandatory prompt anchor from `docs/art-style-reference.md` verbatim.
- Use the episode screenshot board only for broad flat linework, rubbery proportions, color separation, and sparse staging. Never copy its characters, costumes, props, locations, crops, or exact designs.
- Do not produce half-human/half-animal bodies. Allowed bodies are coherent alien mutants, complete animals/creatures, simple robots/devices, or non-humanoid organisms.
- Every non-boss enemy definition receives a unique `sprite_id` and a unique visible identity.
- Every attack has exactly four frames: rest, local wind-up, one hit, recovery.
- Feet, wheels, treads, or body base remain planted. Grounded body translation stays below 6% of the frame width.
- No repeated strike, multi-swing, jump, charge across the frame, slash trail, impact star, or dust cloud.
- Production frames are `256x256` RGBA PNGs with transparent corners, safe margins, shared scale, and shared baseline.
- Enemies face left. Frame 0 is the static rest pose.
- Do not modify Boss assets, gameplay numbers, encounter pools, translations, cards, relics, UI, backgrounds, shared animation code, or combat feedback.
- Preserve all unrelated dirty-worktree changes. Stage and commit only files assigned to the task.

---

## Shared Asset Procedure

Each batch task applies this procedure independently to every listed enemy.

- [ ] **Step A: Inspect references**

Use the local image viewer on:

```text
docs/art/external-references/rick-morty-s8e3-western/reference-board.png
battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png
battle_scene/assets/images/backgrounds/wasteland_battlefield_quiet_v6.png
```

- [ ] **Step B: Generate one exact attack sheet**

Use built-in ImageGen with the enemy's exact identity brief and attack beat from
the design spec. The prompt must explicitly require:

```text
exactly four equal cells in a 2x2 grid;
same original character, same scale, same baseline, enemy faces left;
top-left rest, top-right local wind-up, bottom-left the only hit, bottom-right recovery;
perfectly uniform solid #FF00FF background;
no dividers, text, UI, scenery, floor, cast shadow, contact shadow, detached debris, or edge crossing
```

Copy the accepted built-in output to:

```text
tmp/imagegen/enemies/{enemy_id}/source.png
```

Save the exact final prompt to:

```text
tmp/imagegen/enemies/{enemy_id}/prompt.txt
```

- [ ] **Step C: Process the sheet**

Set `$id` and `$fit` to the exact values specified by the task, then run:

```powershell
$id = "acid_spitter"
$fit = "0.68"
python "C:\Users\Jerry\.codex\skills\generate2dsprite\scripts\generate2dsprite.py" process `
  --input "tmp\imagegen\enemies\$id\source.png" `
  --target creature `
  --mode attack `
  --output-dir "tmp\imagegen\enemies\$id\processed_256" `
  --prompt-file "tmp\imagegen\enemies\$id\prompt.txt" `
  --threshold 100 `
  --edge-threshold 150 `
  --rows 2 `
  --cols 2 `
  --cell-size 256 `
  --label-prefix "${id}_attack" `
  --fit-scale $fit `
  --trim-border 4 `
  --edge-clean-depth 3 `
  --align feet `
  --shared-scale `
  --component-mode largest `
  --component-padding 4 `
  --min-component-area 1 `
  --edge-touch-margin 3 `
  --reject-edge-touch `
  --duration 110
```

For floating organisms, `--align bottom` may replace `--align feet`, but all
four frames still use one shared baseline.

- [ ] **Step D: Validate before replacement**

Inspect `sheet-transparent.png`, `animation.gif`, and `pipeline-meta.json`.
Reject and regenerate if any frame touches an edge, changes identity, changes
scale, faces right, contains multiple hit poses, or moves the planted base.

- [ ] **Step E: Copy to production**

After validation:

```powershell
$id = "acid_spitter"
$src = "tmp\imagegen\enemies\$id\processed_256"
$dst = "battle_scene\assets\images\enemies\$id\attack"
New-Item -ItemType Directory -Force $dst | Out-Null
0..3 | ForEach-Object {
    Copy-Item -LiteralPath (
        Join-Path $src ("${id}_attack-" + ($_ + 1) + ".png")
    ) -Destination (
        Join-Path $dst ("${id}_attack_" + $_ + ".png")
    ) -Force
}
```

Do not copy raw sheets or GIFs into the production enemy folder.

- [ ] **Step F: Batch self-review**

Review the production frames at original size and the GIF at game scale. Record
the generated identities, processor results, edge-touch result, and any concern
in the task report.

---

### Task 1: Creature Batch

**Files:**

- Modify: `battle_scene/assets/images/enemies/acid_spitter/attack/acid_spitter_attack_0.png` through `_3.png`
- Modify: `battle_scene/assets/images/enemies/chrome_hound/attack/chrome_hound_attack_0.png` through `_3.png`
- Modify: `battle_scene/assets/images/enemies/riot_hound/attack/riot_hound_attack_0.png` through `_3.png`
- Create: `battle_scene/assets/images/enemies/riot_hound_alpha/attack/riot_hound_alpha_attack_0.png` through `_3.png`
- Modify: `battle_scene/assets/images/enemies/scrap_rat/attack/scrap_rat_attack_0.png` through `_3.png`
- Modify: `battle_scene/card_info/enemy/riot_hound_alpha.json`
- Create: `tmp/imagegen/enemies/{acid_spitter,chrome_hound,riot_hound,riot_hound_alpha,scrap_rat}/`

**Interfaces:**

- Consumes: the shared asset procedure and the exact roster briefs in the design spec.
- Produces: five distinct four-frame creature identities; `riot_hound_alpha.sprite_id == "riot_hound_alpha"`.

- [ ] **Step 1: Generate `acid_spitter`**

Use the pressure-throat radiation amphibian brief. Attack: compact throat
compression and exactly one small glob in frame 3. Use `fit_scale=0.68`.

- [ ] **Step 2: Generate `chrome_hound`**

Use the complete nervous desert dog brief. Attack: one short bite with planted
paws. Use `fit_scale=0.68`.

- [ ] **Step 3: Generate `riot_hound`**

Use the complete long-neck jackal brief. Attack: one compact snap, no leap.
Use `fit_scale=0.68`.

- [ ] **Step 4: Generate `riot_hound_alpha`**

Use the complete broad radiation hyena brief. It must not be a resized or
recolored `riot_hound`. Attack: one shoulder-and-jaw bump. Use
`fit_scale=0.75`.

- [ ] **Step 5: Generate `scrap_rat`**

Use the complete four-legged tunnel rodent brief. Attack: one tiny bite. Use
`fit_scale=0.50`.

- [ ] **Step 6: Split the borrowed alpha sprite**

Change only the `sprite_id` value in
`battle_scene/card_info/enemy/riot_hound_alpha.json`:

```json
"sprite_id": "riot_hound_alpha"
```

- [ ] **Step 7: Run batch checks**

Run:

```powershell
python scripts/check_missing_art.py
$env:GODOT_BIN = "C:\Program Files\Godot\Godot.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke_test.ps1
```

Expected: zero hard-missing enemy art, all schemas passed, clean headless boot.

- [ ] **Step 8: Commit assigned files only**

```powershell
git add -- `
  battle_scene/assets/images/enemies/acid_spitter/attack `
  battle_scene/assets/images/enemies/chrome_hound/attack `
  battle_scene/assets/images/enemies/riot_hound/attack `
  battle_scene/assets/images/enemies/riot_hound_alpha/attack `
  battle_scene/assets/images/enemies/scrap_rat/attack `
  battle_scene/card_info/enemy/riot_hound_alpha.json
git commit -m "art: rebuild non-boss creature enemies"
```

---

### Task 2: Machine Batch

**Files:**

- Modify: `battle_scene/assets/images/enemies/armored_patrol/attack/armored_patrol_attack_0.png` through `_3.png`
- Create: `battle_scene/assets/images/enemies/chrome_warden/attack/chrome_warden_attack_0.png` through `_3.png`
- Create: `battle_scene/assets/images/enemies/hex_drone/attack/hex_drone_attack_0.png` through `_3.png`
- Create: `battle_scene/assets/images/enemies/mortar_cart_siege/attack/mortar_cart_siege_attack_0.png` through `_3.png`
- Modify: `battle_scene/assets/images/enemies/trash_robot/attack/trash_robot_attack_0.png` through `_3.png`
- Modify: `battle_scene/card_info/enemy/chrome_warden.json`
- Modify: `battle_scene/card_info/enemy/hex_drone.json`
- Modify: `battle_scene/card_info/enemy/mortar_cart_siege.json`
- Create: `tmp/imagegen/enemies/{armored_patrol,chrome_warden,hex_drone,mortar_cart_siege,trash_robot}/`

**Interfaces:**

- Consumes: shared asset procedure and machine briefs.
- Produces: five distinct machine identities and three unique `sprite_id` mappings.

- [ ] **Step 1: Generate `armored_patrol`**

Use the autonomous fallout-shelter door robot brief. Attack: one padded
faceplate bump; treads fixed. Use `fit_scale=0.80`.

- [ ] **Step 2: Generate `chrome_warden`**

Use the tall decontamination booth robot brief. Attack: one short padded-arm
strike. Use `fit_scale=0.82`.

- [ ] **Step 3: Generate `hex_drone`**

Use the hovering broken television parasite brief. Attack: one short static
pulse only in frame 3. Use `fit_scale=0.62` and bottom alignment.

- [ ] **Step 4: Generate `mortar_cart_siege`**

Use the three-legged civil-defense siren brief. Attack: one restrained speaker
pulse. Use `fit_scale=0.72`.

- [ ] **Step 5: Generate `trash_robot`**

Use the crooked refuse-bin robot brief. Attack: one short grabber poke. Use
`fit_scale=0.70`.

- [ ] **Step 6: Split borrowed sprite mappings**

Change only these `sprite_id` values:

```json
// battle_scene/card_info/enemy/chrome_warden.json
"sprite_id": "chrome_warden"

// battle_scene/card_info/enemy/hex_drone.json
"sprite_id": "hex_drone"

// battle_scene/card_info/enemy/mortar_cart_siege.json
"sprite_id": "mortar_cart_siege"
```

- [ ] **Step 7: Run batch checks**

Run the same `check_missing_art.py` and `smoke_test.ps1` commands from Task 1.
Expected: zero hard-missing enemy art and clean Godot boot.

- [ ] **Step 8: Commit assigned files only**

```powershell
git add -- `
  battle_scene/assets/images/enemies/armored_patrol/attack `
  battle_scene/assets/images/enemies/chrome_warden/attack `
  battle_scene/assets/images/enemies/hex_drone/attack `
  battle_scene/assets/images/enemies/mortar_cart_siege/attack `
  battle_scene/assets/images/enemies/trash_robot/attack `
  battle_scene/card_info/enemy/chrome_warden.json `
  battle_scene/card_info/enemy/hex_drone.json `
  battle_scene/card_info/enemy/mortar_cart_siege.json
git commit -m "art: rebuild non-boss machine enemies"
```

---

### Task 3: Odd Organism Batch

**Files:**

- Modify: `battle_scene/assets/images/enemies/ember_wisp/attack/ember_wisp_attack_0.png` through `_3.png`
- Modify: `battle_scene/assets/images/enemies/mortar_cart/attack/mortar_cart_attack_0.png` through `_3.png`
- Modify: `battle_scene/assets/images/enemies/scrap_shard/attack/scrap_shard_attack_0.png` through `_3.png`
- Modify: `battle_scene/assets/images/enemies/slag_walker/attack/slag_walker_attack_0.png` through `_3.png`
- Create: `tmp/imagegen/enemies/{ember_wisp,mortar_cart,scrap_shard,slag_walker}/`

**Interfaces:**

- Consumes: shared asset procedure and organism briefs.
- Produces: four distinct non-humanoid identities.

- [ ] **Step 1: Generate `ember_wisp`**

Use the floating reactor-moth larva brief. Attack: exactly one small flame puff
in frame 3. Use `fit_scale=0.50` and bottom alignment.

- [ ] **Step 2: Generate `mortar_cart`**

Use the complete bunker-tick creature brief. Attack: one dorsal pressure pop;
all legs planted. Use `fit_scale=0.70`.

- [ ] **Step 3: Generate `scrap_shard`**

Use the reactor-glass mite brief. Attack: one short dart left and immediate
return. Use `fit_scale=0.45` and bottom alignment.

- [ ] **Step 4: Generate `slag_walker`**

Use the contained ooze in a cracked ceramic survival shell brief. Attack: one
short ooze appendage slap; shell fixed. Use `fit_scale=0.72`.

- [ ] **Step 5: Run batch checks**

Run the same `check_missing_art.py` and `smoke_test.ps1` commands from Task 1.
Expected: zero hard-missing enemy art and clean Godot boot.

- [ ] **Step 6: Commit assigned files only**

```powershell
git add -- `
  battle_scene/assets/images/enemies/ember_wisp/attack `
  battle_scene/assets/images/enemies/mortar_cart/attack `
  battle_scene/assets/images/enemies/scrap_shard/attack `
  battle_scene/assets/images/enemies/slag_walker/attack
git commit -m "art: rebuild non-boss organism enemies"
```

---

### Task 4: Heavy Silhouette Batch

**Files:**

- Modify: `battle_scene/assets/images/enemies/rust_brute/attack/rust_brute_attack_0.png` through `_3.png`
- Create: `battle_scene/assets/images/enemies/siege_breaker/attack/siege_breaker_attack_0.png` through `_3.png`
- Modify: `battle_scene/assets/images/enemies/wasteland_killer/attack/wasteland_killer_attack_0.png` through `_3.png`
- Modify: `battle_scene/card_info/enemy/siege_breaker.json`
- Create: `tmp/imagegen/enemies/{rust_brute,siege_breaker,wasteland_killer}/`

**Interfaces:**

- Consumes: shared asset procedure and heavy-silhouette briefs.
- Produces: three distinct identities and `siege_breaker.sprite_id == "siege_breaker"`.

- [ ] **Step 1: Generate `rust_brute`**

Use the lanky non-animal alien mechanic brief. The recently rejected pig-person
and boar concepts must not be used as visual references. Attack: one short
orange-glove jab with bent elbow. Use `fit_scale=0.78`.

- [ ] **Step 2: Generate `siege_breaker`**

Use the rolling decontamination drum robot brief. Attack: one small ram-pad
bump, not a charge. Use `fit_scale=0.82`.

- [ ] **Step 3: Generate `wasteland_killer`**

Use the complete cactus-mantis organism brief. Attack: one small hook slice
without a trail. Use `fit_scale=0.72`.

- [ ] **Step 4: Split the borrowed elite sprite**

Change only:

```json
// battle_scene/card_info/enemy/siege_breaker.json
"sprite_id": "siege_breaker"
```

- [ ] **Step 5: Run batch checks**

Run the same `check_missing_art.py` and `smoke_test.ps1` commands from Task 1.
Expected: zero hard-missing enemy art and clean Godot boot.

- [ ] **Step 6: Commit assigned files only**

```powershell
git add -- `
  battle_scene/assets/images/enemies/rust_brute/attack `
  battle_scene/assets/images/enemies/siege_breaker/attack `
  battle_scene/assets/images/enemies/wasteland_killer/attack `
  battle_scene/card_info/enemy/siege_breaker.json
git commit -m "art: rebuild heavy non-boss enemies"
```

---

### Task 5: Whole-Roster Integration and Visual Verification

**Files:**

- Verify: all 17 non-boss JSON files under `battle_scene/card_info/enemy/`
- Verify: all 68 production PNG frames under `battle_scene/assets/images/enemies/`
- Create: `tmp/enemy_redesign_20260724/all_enemies_rest_contact.png`
- Create: `tmp/enemy_redesign_20260724/all_enemies_attack_contact.png`
- Create: `tmp/enemy_redesign_20260724/verification-report.md`

**Interfaces:**

- Consumes: Tasks 1–4 production assets and JSON mappings.
- Produces: one integrated roster verification report and final test evidence.

- [ ] **Step 1: Import all changed assets**

```powershell
$root = (Resolve-Path ".").Path
$out = Join-Path $root "tmp\enemy-redesign-import-stdout.log"
$err = Join-Path $root "tmp\enemy-redesign-import-stderr.log"
$proc = Start-Process `
  -FilePath "C:\Program Files\Godot\Godot.exe" `
  -ArgumentList @("--headless", "--path", $root, "--import") `
  -WindowStyle Hidden `
  -RedirectStandardOutput $out `
  -RedirectStandardError $err `
  -PassThru `
  -Wait
if ($proc.ExitCode -ne 0) { throw "Godot import failed" }
```

- [ ] **Step 2: Verify data-to-art coverage**

```powershell
python scripts/check_missing_art.py
python scripts/gen_catalog_html.py
```

Expected: zero hard-missing enemy art; regenerated catalog completes.

- [ ] **Step 3: Build contact sheets**

Run:

```powershell
python tmp/art_audit/build_visual_audit.py
New-Item -ItemType Directory -Force "tmp\enemy_redesign_20260724" | Out-Null
Copy-Item `
  "tmp\art_audit\enemies_on_stage.png" `
  "tmp\enemy_redesign_20260724\all_enemies_rest_contact.png" `
  -Force
Copy-Item `
  "tmp\art_audit\enemy_attack_frames.png" `
  "tmp\enemy_redesign_20260724\all_enemies_attack_contact.png" `
  -Force
```

The contact sheets include the three unchanged Bosses as controls. They must
show 17 distinct non-boss definitions plus those three unchanged Bosses.

- [ ] **Step 4: Verify whole-roster invariants**

For each non-boss definition, verify:

```text
unique sprite_id
exactly four attack PNG files
256x256 RGBA
transparent corners
four unique frame hashes
frame 0 faces left
stable baseline
one hit pose only
readable separation over wasteland_battlefield_quiet_v6.png
```

Record the result for all 17 IDs in
`tmp/enemy_redesign_20260724/verification-report.md`.

- [ ] **Step 5: Verify Bosses are untouched**

```powershell
git diff --name-only 5348c8a..HEAD -- `
  battle_scene/assets/images/enemies/ash_warden `
  battle_scene/assets/images/enemies/junkyard_tyrant `
  battle_scene/assets/images/enemies/rust_titan `
  battle_scene/card_info/enemy/ash_warden.json `
  battle_scene/card_info/enemy/junkyard_tyrant.json `
  battle_scene/card_info/enemy/rust_titan.json
```

Expected: no output.

- [ ] **Step 6: Run final tests**

```powershell
$env:GODOT_BIN = "C:\Program Files\Godot\Godot.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke_test.ps1
```

Expected: all schemas passed and clean headless boot.

- [ ] **Step 7: Review dirty-worktree scope**

```powershell
git status --short
git diff --name-only 5348c8a..HEAD
```

Confirm implementation commits contain only assigned enemy PNGs and five
`sprite_id` edits.
Do not stage unrelated pre-existing changes.

- [ ] **Step 8: Preserve generated catalog and verification outputs**

The catalog regeneration and temporary verification files remain uncommitted
because the worktree already contains owner changes in generated catalog files.
Record their paths and verification result in the final handoff without staging
them.
