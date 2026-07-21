# Objective

Continue the visual/UI overhaul for the Godot game at `C:\Users\Jerry\Desktop\Cardgame`. The immediate focus is an attractive, lightweight shared Top Bar plus improved map and battle HUD concepts that match the project's approved 2D comic style before further implementation.

# Latest User Request

The user wants to open a new Codex session and continue from this handoff.

The latest unresolved visual feedback is:

- The first generated map/battle UI optimization concepts were not attractive enough.
- The battle energy display and draw/discard card counters were specifically rejected.
- The Top Bar shared by map and battle was specifically rejected as unattractive.
- A revised pair of concepts was generated after that feedback, but the user has not approved or rejected the revisions yet.

# Current State

## Completed and verified in code

- The runtime map remains horizontal and uses straight dotted route links. The curved route and multi-layer cyan glow were removed.
- Map node radius/icon size were reduced to improve readability.
- Both static `CardBackVisual` children were removed from `battle_scene.tscn`, including the unused old `card_back.png` scene resource.
- Draw/discard piles now use mirrored copies of the deck-book glyph `iconb_deck_stack.png`; pile cards stay hidden through `Pile.hide_cards`.
- Draw/discard counts are compact labels attached just above the 80 px deck-book glyphs, rather than large floating numerals.
- The current title screen uses the generated Bottlecap Hunter background/title/button components and the requested left-column layout.

## In progress / not approved

- The shared Top Bar has not been redesigned in code to match the latest concept direction.
- The battle energy meter and pile count presentation have not been changed to the latest revised concept.
- The revised map and battle concepts are image-generation outputs only. They have not been implemented and have not received user approval.

# Decisions and Constraints

- Project UI style is the approved UI07/lightweight direction. The older ultralight direction is abandoned.
- Use simple hand-drawn 2D comic UI with clean ink lines and restrained warm colors.
- Never use screw heads, rivets, bolts, thick metal framing, heavy bevels, or oversized decorative chrome.
- Large panels must stay visually light. Avoid framing every icon or readout in its own square plate.
- Do not stretch UI art. Preserve native aspect ratios for icons, card art, pile glyphs, title art, and controls.
- The map stays horizontal. Use a Slay-the-Spire-II-like information hierarchy with straight dotted paths; do not reintroduce curved route lines or glow tubes.
- Map and battle share one Top Bar design. Current desired direction: a single slim continuous charcoal strip, one fine warm hairline, integrated portrait, frameless cap/tool readouts, and a quiet right-side act/deck/settings/timer group.
- Battle energy should be compact and quiet, not a large ornate circular ring. The latest concept uses three small energy dots/capsules plus a small `3/3` label.
- Draw/discard counts should be small anchored badges attached to the cream card-fan icons, not large floating white numerals.
- Do not restore the old brown mechanical card back on battlefield piles.
- Existing unrelated dirty-worktree changes belong to the user or earlier work. Do not revert them.

# Files and Changes

Relevant code:

- `C:\Users\Jerry\Desktop\Cardgame\battle_scene\battle_scene.tscn`
  - Removed both `CardBackVisual` static nodes and the old card-back ext resource.
- `C:\Users\Jerry\Desktop\Cardgame\battle_scene\battle_scene.gd`
  - `_setup_pile_icon()` begins around line 608.
  - Forces hidden pile cards, removes any legacy visual defensively, and adds the card-fan glyph.
  - Count label vertical position is around line 657.
- `C:\Users\Jerry\Desktop\Cardgame\run_system\ui\map_renderer.gd`
  - `NODE_RADIUS = 32`, `NODE_ICON_SIZE = 64` near line 12.
  - Straight dotted routes are drawn by `_draw_dotted_trail()` around line 271.
  - Legend uses the lightweight UI style.
- `C:\Users\Jerry\Desktop\Cardgame\run_system\ui\run_top_bar.gd`
  - Current shared runtime Top Bar. It is still functionally correct but visually unresolved.
  - `MAIN_BAR_HEIGHT = 64` near line 23.
- `C:\Users\Jerry\Desktop\Cardgame\run_system\ui\main_menu.gd`
  - Current Bottlecap Hunter start-screen implementation.
- `C:\Users\Jerry\Desktop\Cardgame\run_system\assets\images\ui\start_screen\`
  - Untracked generated start-screen components used by `main_menu.gd`.

The worktree is broadly dirty: translations, card art, attribute icons, building screens, loot UI, pause UI, character/forge windows, and other files are modified. Do not assume all changes belong to this map/battle task and do not clean or revert them.

Generated concept images:

- Rejected first map concept:
  `C:\Users\Jerry\.codex\generated_images\019f3dd1-998b-7a23-ad7e-3f27769b65ed\exec-480a1a1b-33ff-43f1-b30e-584d30e2425d.png`
- Rejected first battle concept:
  `C:\Users\Jerry\.codex\generated_images\019f3dd1-998b-7a23-ad7e-3f27769b65ed\exec-3773e891-2c71-4907-ab8a-0e39ae04f158.png`
- Revised map concept, not yet approved:
  `C:\Users\Jerry\.codex\generated_images\019f3dd1-998b-7a23-ad7e-3f27769b65ed\exec-e3644b9b-e213-40f1-8934-0dfdc0edf5af.png`
- Revised battle concept, not yet approved:
  `C:\Users\Jerry\.codex\generated_images\019f3dd1-998b-7a23-ad7e-3f27769b65ed\exec-dd3d459e-74a0-4117-a748-595406efb84a.png`

# Verification

Completed verification evidence:

- Godot headless project parse exited with code `0` after the map/pile edits.
- `git diff --check` passed for the relevant UI and battle files.
- Godot MCP runtime launched the map and battle scenes without runtime errors.
- Actual map screenshot after straight-dot route change:
  `C:\Users\Jerry\Desktop\Cardgame\.mcp\screenshots\screenshot_1783635065_532.png`
- Actual battle screenshot after deleting old static card backs and moving counts:
  `C:\Users\Jerry\Desktop\Cardgame\.mcp\screenshots\screenshot_1783635244_038.png`
- Battle screenshot confirms the old brown mechanical card backs are absent; cream star card-fan glyphs are visible instead.

Not verified:

- No runtime implementation exists for the revised Top Bar/energy/count-badge concepts.
- The user has not accepted the revised generated concepts.

# Open Issues and Risks

- The shared Top Bar is the main unresolved visual system. Implementing map and battle independently would create inconsistency.
- The latest revised concepts may still be rejected. Do not treat them as final art direction without user confirmation.
- Image generation may produce visually good but non-implementable spacing or inaccurate Chinese text. Use concepts for layout/art direction, then implement deterministic text and sizing in Godot.
- `main_menu.gd` still contains a `TextureRect.STRETCH_SCALE` use for the save strip. This may conflict with the no-stretch rule if title-screen work resumes.
- Current screenshots use test/default run state and can show placeholder portrait or zero currency; judge layout, not save-state data.

# Next Action

Open the two revised concept images and ask the user to judge only these three shared components: the slim Top Bar, the compact battle energy readout, and the pile count badges. Do not implement them until the direction is accepted. If rejected, generate focused component variants rather than regenerating the entire map and battle backgrounds. Once accepted, update `run_top_bar.gd` first, then the battle energy/pile counters, and verify both map and battle with Godot MCP screenshots.
