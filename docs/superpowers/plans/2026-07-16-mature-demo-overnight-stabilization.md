# Mature Demo Overnight Stabilization Implementation Plan

> **Execution note:** The owner delegated this unattended pass. Execute in this session, test-first, without subagents, commits, pushes, or destructive cleanup of the shared dirty worktree.

**Goal:** Close the current UI07 / 2D American-comic build into a visually coherent and semantically reliable mature demo without redesigning the map, world, economy, or core progression.

**Architecture:** Keep the existing Godot scene graph and data-driven equipment model. Add narrow contract/runtime coverage around the current surfaces, correct only reproducible defects, and use real Windows/OpenGL captures for visual decisions. Generated art remains presentation-only; runtime text, prices, counts, and state remain Godot controls.

**Tech Stack:** Godot 4.6, GDScript, JSON equipment data, PowerShell smoke/import tooling, PNG/NinePatch UI assets.

---

## Task 1: Establish a fresh regression and resource-reference baseline

**Files:**
- Modify: `.planning/2026-07-16-mature-demo-overnight/findings.md`
- Modify: `.planning/2026-07-16-mature-demo-overnight/progress.md`
- Modify: `.planning/2026-07-16-mature-demo-overnight/task_plan.md`
- Inspect: `tests/*.tscn`
- Inspect: `scripts/smoke_test.ps1`

1. Enumerate contract/runtime scenes and separate screenshot-only fixtures.
2. Run the headless contract/runtime suite individually so failures identify the owning surface.
3. Run Godot import and `git diff --check` as an initial health gate.
4. Record every failure with exact scene and error; do not fix before a reproducible RED result exists.
5. Audit literal `res://` asset references touched by the current UI work and verify each target exists.

## Task 2: Remove main-menu save-strip distortion and stale hover artifacts

**Files:**
- Modify: `tests/base_upgrade_result_contract_test.gd`
- Modify: `run_system/ui/main_menu.gd`
- Potentially modify: `tests/base_upgrade_visual_capture.gd`

1. Add a contract that rejects `TextureRect.STRETCH_SCALE` for the wide clean save strip and requires keep-aspect or NinePatch behavior.
2. Run `tests/base_upgrade_result_contract_test.tscn` and confirm the new assertion fails.
3. Replace stretch behavior with the smallest compatible keep-aspect/NinePatch implementation while preserving click regions and text overlays.
4. Add or strengthen a contract preventing full brown hover fills on compact save controls.
5. Re-run the contract and capture the main menu with the real Windows renderer.

## Task 3: Guarantee equipment semantic integrity across acquisition paths

**Files:**
- Modify: `tests/equipment_tool_shop_contract_test.gd`
- Modify: `tests/forge_backpack_contract_test.gd`
- Modify: `tests/demo_content_contract_test.gd`
- Potentially modify: `run_system/core/run_manager.gd`
- Potentially modify: `run_system/ui/buildings/market_screen.gd`
- Potentially modify: `run_system/ui/shop_scene.gd`
- Potentially modify: reward/drop pool owners discovered by the audit

1. Enumerate every equipment base-selection path and classify it as ordinary, set-specific, or cursed-specific.
2. Add RED contracts that ordinary market/shop/forge/reward paths exclude bases with non-empty `set_id`.
3. Add a runtime assertion that materializing any set base yields rarity `set`, exactly three positive affixes, and its original `set_id`.
4. Add a contract that set/cursed instances cannot enter common/uncommon/rare bulk dismantle operations.
5. Apply the smallest centralized filter or materialization fix; preserve legacy save parsing.
6. Run equipment, forge, shop, demo-content, and inventory ownership tests.

## Task 4: Close forge lifecycle and interaction-state gaps

**Files:**
- Modify: `tests/building_upgrade_runtime_test.gd`
- Modify: `tests/forge_backpack_contract_test.gd`
- Potentially modify: `run_system/ui/home_base_scene.gd`
- Potentially modify: `run_system/ui/window/forge_window.gd`

1. Add a runtime test that opens the forge dual-window composition, closes windows in both orders, and asserts `ForgeBackdrop` is removed as soon as `ForgeWindow` exits.
2. Confirm RED if the backdrop survives or intercepts input.
3. Make backdrop ownership/lifecycle explicit and idempotent.
4. Contract-check forge compact tabs so hover does not introduce a full brown block.
5. Contract-check that the dedicated dismantle action and larger bulk rows remain wired and that set/cursed gear stays protected.
6. Re-run forge and building runtime tests.

## Task 5: Perform a focused UI consistency audit

**Files:**
- Inspect/modify only when a defect is reproduced: `run_system/ui/**/*.gd`
- Inspect: `run_system/ui/theme/wasteland_theme.gd`
- Modify: the narrow owning contract for each reproduced issue

1. Search compact controls for hover styles that replace an icon with a brown rectangle.
2. Distinguish intentional selected/accent orange states from hover-only states.
3. For each reproduced defect, add a narrow contract and change hover to one of: <=10% brightness lift, outline, or 1.03–1.05 scale.
4. Audit wide plaques/bars for inappropriate `STRETCH_SCALE`; retain scale only where the source art is explicitly designed to be stretched or replace with NinePatch/keep-aspect.
5. Re-run affected contracts after every localized change.

## Task 6: Verify all key runtime compositions visually

**Files:**
- Reuse/modify: `tests/*visual_capture.gd`
- Output only: `tmp/*.png`

1. Capture the main menu, home base, map, battle, forge, clinic, market, and outpost using `--display-driver windows --rendering-method gl_compatibility`.
2. Inspect captures at original resolution for stretch, overlap, cropping, wrong z-order, empty-state imbalance, and stale backdrop layers.
3. Fix only defects visible in the capture and covered by a contract/runtime assertion.
4. Re-capture every corrected surface and retain the final evidence under `tmp/`.

## Task 7: Final verification and morning handoff

**Files:**
- Modify: `.planning/2026-07-16-mature-demo-overnight/task_plan.md`
- Modify: `.planning/2026-07-16-mature-demo-overnight/progress.md`
- Modify: `.planning/2026-07-16-mature-demo-overnight/findings.md`

1. Re-run the full headless contract/runtime suite.
2. Run Godot import and `scripts/smoke_test.ps1` with the verified Godot binary.
3. Run `git diff --check` and inspect the final scoped diff without reverting unrelated work.
4. Confirm no real save files were written or modified.
5. Mark all phases complete only if every fresh verification gate passes.
6. Report changed behavior, test evidence, screenshot paths, and deliberately deferred out-of-scope items.
