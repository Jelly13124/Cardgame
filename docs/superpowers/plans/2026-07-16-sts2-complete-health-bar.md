# STS2-Inspired Complete Health Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every visible battle health-bar layer with generated STS2-inspired raster components while preserving dynamic HP, delayed damage, block, typography, and combat behavior.

**Architecture:** Keep `CharacterHUD` as the sole health presentation owner. A generated nine-patch track replaces the current generated frame plus code-native `Panel`, and one generated nine-patch red fill texture drives both the live and delayed-loss `TextureProgressBar` layers. The loss layer differs only by tint, keeping the artwork and animation semantics consistent.

**Tech Stack:** Godot 4.6 GDScript, `NinePatchRect`, `TextureProgressBar`, PNG alpha assets, built-in ImageGen, chroma-key removal helper, Godot scene contract tests.

## Global Constraints

- Preserve health arithmetic, delayed-loss timing, healing behavior, status layout, block visibility, HUD placement, and all player/enemy width tiers.
- Preserve `block_badge_sts2_ui07.png` and Kreon combat numerals.
- Do not change the top bar, battle background, energy, end-turn button, character positions, encounters, or balance.
- Do not stage, commit, push, reset, or clean the shared dirty worktree.

---

### Task 1: Lock the complete generated-layer contract

**Files:**
- Modify: `tests/ui_sts2_hud_contract_test.gd`
- Test: `tests/ui_sts2_hud_contract_test.tscn`

**Interfaces:**
- Consumes: `CharacterHUD` child names `HpFrame`, `HpLossBar`, and `HpBar`.
- Produces: assertions requiring `battle_hp_track_sts2_ui07.png` and `battle_hp_fill_sts2_ui07.png`.

- [ ] **Step 1: Write the failing assertions**

Replace the old frame/track assertions and extend the fill assertions:

```gdscript
_expect(
    _texture_path(hp_frame).ends_with("/battle_hp_track_sts2_ui07.png"),
    "health track uses the generated complete STS2 texture"
)
_expect(player_hud.get_node_or_null("HpFrame/HpTrack") == null,
    "health track no longer overlays a code-native Panel")
_expect(
    hp_live.texture_progress.resource_path.ends_with("/battle_hp_fill_sts2_ui07.png"),
    "live health uses the generated red fill texture"
)
_expect(
    hp_loss.texture_progress.resource_path.ends_with("/battle_hp_fill_sts2_ui07.png"),
    "damage trail derives from the same generated red fill texture"
)
```

- [ ] **Step 2: Run the contract and verify RED**

Run:

```powershell
& 'tmp\godot_runner\Godot_v4.6-stable_win64_console.exe' --headless --path . res://tests/ui_sts2_hud_contract_test.tscn
```

Expected: exit 1; failures say the old frame path remains, `HpTrack` still exists, and both fill texture resource paths are missing.

---

### Task 2: Generate and normalize the track/fill pair

**Files:**
- Create: `battle_scene/assets/images/ui/battle_hp_track_sts2_ui07.png`
- Create: `battle_scene/assets/images/ui/battle_hp_fill_sts2_ui07.png`
- Intermediate: `tmp/imagegen/sts2_complete_health_bar_20260716/*`

**Interfaces:**
- Produces: two transparent, long horizontal PNGs with compatible inset geometry.

- [ ] **Step 1: Generate the empty track**

Use built-in ImageGen with a perfectly flat `#ff00ff` chroma background. Request a single centered 15:1 dark blue-teal empty HP trough, one near-black contour, one subtle pale steel-blue upper edge, restrained pointed ends, original 2D American-comic line art, and no red fill, text, symbols, brass, rivets, glow, shadow, or texture outside the bar.

- [ ] **Step 2: Generate the red fill**

Use built-in ImageGen with the same composition and chroma background. Request a single centered 15:1 inner red HP fill strip, dusty crimson body, narrow warm-red upper highlight, dark lower edge, compact clean end caps, no surrounding frame, text, symbols, glow, shadow, brass, or rivets.

- [ ] **Step 3: Remove chroma and normalize dimensions**

Run the installed helper for both images:

```powershell
& $python $helper --input <raw.png> --out <alpha.png> --auto-key border --soft-matte --transparent-threshold 14 --opaque-threshold 215 --despill --edge-contract 1
```

Crop to alpha bounds with 8 px padding and resize each to a centered `768x64` RGBA canvas. Save the two final project files with the exact names above.

- [ ] **Step 4: Import and inspect**

Run:

```powershell
& 'tmp\godot_runner\Godot_v4.6-stable_win64_console.exe' --headless --editor --path . --quit
```

Expected: `.import` files exist for both assets. Inspect both final PNGs at original detail and reject visible magenta fringe, asymmetrical crop, stray ornament, or illegible edges.

---

### Task 3: Replace all procedural health visuals

**Files:**
- Modify: `battle_scene/ui/character_hud.gd`
- Test: `tests/ui_sts2_hud_contract_test.tscn`

**Interfaces:**
- Consumes: generated track/fill textures from Task 2.
- Preserves: `update_stats(hp: int, max_hp: int, blk: int) -> void`.
- Removes: `_hp_track`, `TRACK_INSET`, `_make_hp_fill_texture()`, `_make_hp_loss_texture()`, and `_make_vertical_gradient_texture()`.

- [ ] **Step 1: Load the generated assets**

Use exact constants:

```gdscript
const HP_TRACK_PATH = "res://battle_scene/assets/images/ui/battle_hp_track_sts2_ui07.png"
const HP_FILL_PATH = "res://battle_scene/assets/images/ui/battle_hp_fill_sts2_ui07.png"
```

- [ ] **Step 2: Make the generated track the bottom layer**

Set `HpFrame.texture = load(HP_TRACK_PATH)`, retain its existing nine-patch size/margins, and remove creation of the child `Panel` named `HpTrack`.

- [ ] **Step 3: Make both progress layers use the generated fill**

Set both `HpLossBar.texture_progress` and `HpBar.texture_progress` to `load(HP_FILL_PATH)`. Keep `_configure_progress_layer()` and apply a warm light tint to the loss layer only:

```gdscript
_hp_loss_bar.self_modulate = Color("#e6a26f")
_hp_bar.self_modulate = Color.WHITE
```

Delete all three procedural-gradient helpers.

- [ ] **Step 4: Run the contract and verify GREEN**

Run the Task 1 command.

Expected: exit 0 and `[OK] STS2 HUD contract passed`.

---

### Task 4: Real-render and regression verification

**Files:**
- Refresh: `tmp/ui-battle-runtime.png`
- Modify only if the render exposes a defect: `battle_scene/ui/character_hud.gd`

**Interfaces:**
- Consumes: final runtime HUD.
- Produces: visual and automated evidence for handoff.

- [ ] **Step 1: Capture a real battle render**

Run:

```powershell
& 'tmp\godot_runner\Godot_v4.6-stable_win64_console.exe' --path . --display-driver windows --rendering-method gl_compatibility res://tests/ui_sts2_hud_visual_capture.tscn
```

Expected: exit 0 and a refreshed `tmp/ui-battle-runtime.png` showing generated track, generated fill, cyan block shield, and Kreon numerals.

- [ ] **Step 2: Verify partial HP visually**

Use the visual fixture or a temporary runtime state to show less than max HP. Confirm the fill end cap remains coherent, missing HP reveals the generated dark track, and the delayed layer does not become a rectangular code-gradient strip.

- [ ] **Step 3: Run all 13 non-visual test scenes**

Run every `tests/*test.tscn` with the Godot console runner. Expected: `ALL_PASS 13`.

- [ ] **Step 4: Run hygiene checks**

Run:

```powershell
git diff --check
git status --short -- battle_scene/ui/character_hud.gd battle_scene/assets/images/ui tests/ui_sts2_hud_contract_test.gd
```

Expected: `git diff --check` emits no output; status lists only intentional modified/new files plus pre-existing unrelated work.
