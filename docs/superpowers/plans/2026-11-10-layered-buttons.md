# Layered Buttons Implementation Plan

**Goal:** Replace the rejected primary/secondary button treatment with original lightweight art and role-specific feedback.

**Architecture:** Keep native Button input and layout. Central theme definitions supply reusable face, shadow, outline and timing parameters to a shared visual controller. Text, icons and input targets remain independent from animated backgrounds.

**Tech Stack:** Godot 4.6.3, GDScript, original PNG nine-patches.

**Spec:** `docs/reviews/sts2-ui-reference.md`, section “按钮的图层与交互复核”; approved by the owner in this conversation.

## Constraints and review focus

- Work only in `feat/ui-refresh`; no merge or push. Preserve card presentation and the five frozen combat VFX files.
- Theme owns skin definitions; page content and persistent top-bar layout remain unchanged.
- Hover takes 0.05 seconds; release of focus takes 0.5 seconds Expo-Out. Primary visual scales 1.05/0.95; secondary 1.025/0.975.
- Disabled controls, keyboard focus, fast enter/exit, repeated skin application, and deletion during a tween must remain safe.
- Capture actual screens using isolated saves, and compare with the previous skin and original structural wireframes in TEMP.

## Tasks

- [x] Write failing contract tests for distinct art layers, role-specific states, fixed input bounds and disabled/focus transitions.
- [x] Generate and inspect original flat primary/secondary faces at 320×96; derive aligned transparent outline layers and document margins 20/16/20/16. Replace obsolete four-state art.
- [x] Add `ui/common/theme/button_feedback.gd`; implement `T.apply_action_button(button, role)` and migrate compatible theme entry points.
- [x] Remove conflicting local button chrome/scale feedback in main menu, base and the affected shared action consumers. Keep page geometry unchanged.
- [x] Run focused contracts and full `tools/run_tests.ps1` with the specified GODOT_BIN; inspect actual rendered screens and fix any layering or text-contrast problems.
- [x] Update asset specifications and TEMP review.html; verify frozen paths and main-directory status, then commit with the requested author identity.

This is a revision within phase 1. Stop after delivering its screenshots; phase 2 remains pending owner review.
