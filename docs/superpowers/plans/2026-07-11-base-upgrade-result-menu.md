# Base Upgrade, Defeat Return, and Menu Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved home-base building-upgrade flow, route defeat results back to the base, and remove title-menu button stretching.

**Architecture:** Keep the existing home-base overview and Outpost bounty shelf responsibilities intact. Replace only the building-tier confirmation overlay with a deterministic UI07 comparison modal, change the building-tier economy to Scrap, and reuse the shared scene transition for defeat return. Main-menu buttons receive native wide assets so their displayed 420×96 ratio no longer distorts source art.

**Tech Stack:** Godot 4.6, GDScript, existing UI03/UI07 assets, generated PNG button/modal components, headless Godot contract tests, runtime visual capture.

## Global Constraints

- Defeat keeps the result screen; its exit action goes to `home_base_scene.tscn`.
- New bounties remain claimable inside the Outpost; the home board remains read-only progress.
- Building unlocks and building tier upgrades both spend Scrap.
- Outpost permanent upgrades remain Caps purchases and are not part of this modal.
- The home-base upgrade modal shows building identity, current tier, next tier, current function, newly unlocked function, Scrap cost, balance, confirm, and cancel without tooltips.
- Preserve the UI07 charcoal + thin warm-brass style and the existing four-building overview.
- Do not modify map or battle background assets in this plan.

---

### Task 1: Generate project-bound UI components

**Files:**
- Create: `run_system/assets/images/ui/base_upgrade/base_upgrade_modal_frame.png`
- Create: `run_system/assets/images/ui/start_screen/button_main_normal_v2.png`
- Create: `run_system/assets/images/ui/start_screen/button_main_selected_v2.png`

**Interfaces:**
- Produces: native-ratio raster surfaces consumed by `home_base_scene.gd` and `main_menu.gd`.

- [ ] Generate the modal frame and two 4.375:1 title-menu button surfaces from the approved UI07 references.
- [ ] Remove flat chroma-key backgrounds, validate alpha corners, and copy final assets into the project.
- [ ] Inspect all three outputs for clean edges and no baked text.

### Task 2: Lock defeat routing and Scrap economy contracts

**Files:**
- Create: `tests/base_upgrade_result_contract_test.gd`
- Create: `tests/base_upgrade_result_contract_test.tscn`
- Modify: `run_system/ui/result_screen.gd`
- Modify: `run_system/core/meta_progress.gd`
- Modify: `assets/translations/ui_common.csv`

**Interfaces:**
- Consumes: `ResultScreen._on_back()`, `MetaProgress.building_cost_currency()`, and `MetaProgress.upgrade_building()`.
- Produces: defeat route to `HOME_BASE_PATH`, `RESULT_BACK_TO_BASE`, and Scrap-only building tier spending.

- [ ] Write assertions that result-screen source routes through `HOME_BASE_PATH`, that defeat button copy uses `RESULT_BACK_TO_BASE`, and that building cost currency is always `scrap`.
- [ ] Add a state-isolated behavior test proving `upgrade_building()` decrements Scrap and leaves Caps unchanged.
- [ ] Run the contract scene and confirm the new assertions fail against current behavior.
- [ ] Implement the route, translation key, currency selector, and Scrap deduction.
- [ ] Run the contract scene and confirm exit 0.

### Task 3: Implement the approved home-base building modal

**Files:**
- Modify: `run_system/ui/home_base_scene.gd`
- Test: `tests/base_upgrade_result_contract_test.gd`

**Interfaces:**
- Consumes: `MetaProgress.get_building_tier()`, `next_building_cost()`, `building_cost_currency()`, and each `BUILDING_DEFS.functions` dictionary.
- Produces: named nodes `BaseUpgradeModal`, `TierTransition`, `CurrentFeature`, `NextFeature`, `UpgradeCost`, `UpgradeConfirmButton`, and `UpgradeCancelButton`.

- [ ] Add failing layout assertions for the named modal nodes and the home bounty-board pickup hint.
- [ ] Run the contract and verify failure because the old generic confirmation dialog is still present.
- [ ] Replace `_show_tier_confirm()` presentation with the approved comparison layout while keeping its existing purchase callbacks.
- [ ] Add `新悬赏请进入前哨站领取` to the read-only bounty board.
- [ ] Run the contract and confirm exit 0.

### Task 4: Replace stretched main-menu button art

**Files:**
- Modify: `run_system/ui/main_menu.gd`
- Test: `tests/base_upgrade_result_contract_test.gd`

**Interfaces:**
- Consumes: native 420×96-proportion PNG button surfaces.
- Produces: unchanged menu interactions with non-distorted normal, hover, pressed, and disabled styling.

- [ ] Add failing assertions that the menu references the `button_main_*_v2.png` assets.
- [ ] Switch the two constants to the generated wide assets and retain existing interaction behavior.
- [ ] Run the contract and confirm exit 0.

### Task 5: Verify the complete flow

**Files:**
- Verify: `run_system/ui/result_screen.gd`
- Verify: `run_system/core/meta_progress.gd`
- Verify: `run_system/ui/home_base_scene.gd`
- Verify: `run_system/ui/main_menu.gd`

**Interfaces:**
- Produces: fresh contract output, clean boot evidence, and visual screenshots.

- [ ] Reimport new PNG and translation assets.
- [ ] Run the focused contract test fresh.
- [ ] Run existing equipment, character-window, tool-confirmation, scene-transition, and HUD contracts.
- [ ] Capture the title menu and home-base upgrade modal at 1920×1080 and inspect text clipping, asset distortion, and hierarchy.
- [ ] Run Godot cold boot and `git diff --check` for all touched files.
