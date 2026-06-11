# Full-screen Character/Deck Pages + Map Click Pass-through Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop map node-clicks from falling through the Character/Deck pages (误触), and make both pages read as full-screen pseudo-scenes with a consistent top-right ✕ (and ESC) to exit.

**Architecture:** Keep both pages as full-screen `Control` overlays (pseudo-scenes — the Deck page opens mid-battle, so a real scene change is impossible). Gate `map_scene`'s global `_input` while a page is mounted (the actual pass-through fix). Restyle the Deck page from dim-popup to opaque full-screen. Give both pages a shared top-right ✕ from a new `wasteland_theme.close_x_button()` helper, plus ESC-to-close.

**Tech Stack:** Godot 4.6, GDScript, `wasteland_theme.gd`.

**Verification note:** No unit-test harness — the gate per task is:
1. `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` → `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`
2. CSV edits → reimport first: `"C:/Program Files/Godot/Godot.exe" --headless --path . --import`.
3. Runtime checks via the godot MCP (`run_project` background → `run_script` / `take_screenshot` → `stop_project`). Do NOT stage `*.import`/`*.uid`/`*.translation` sidecars.

**Confirmed facts (verified against source):**
- `map_scene.gd` `_input(event)` early-returns on `if _is_relic_choice_open or _node_click_pending:`. The Character page is added as child node `"EquipmentPanel"`, the Deck page as `"RunDeckViewerModal"` (both children of `map_scene`).
- `equipment_panel.gd` (`class_name EquipmentPanel`): full-screen opaque already; exit is a `"返回地图"` text button (`tr("UI_EQUIP_BACK_TO_MAP")`, lines ~91-96) → `queue_free`.
- `run_deck_viewer_modal.gd` (`class_name RunDeckViewerModal`): dim backdrop `Color(0,0,0,0.78)` + `CenterContainer` → `PanelContainer(1180×740)` → `margin` → `vbox`; inline header `"X"` button → `queue_free`. Also opened in battle via `battle_ui_manager.show_run_deck_viewer()` and from the rest stop.
- `battle_top_bar.gd` `_input` reacts to ESC ONLY when `settings_layer.visible` (to hide settings). ESC does NOT open settings. → A page's own ESC-to-close cannot conflict with battle settings.
- `wasteland_theme.gd` exposes `button_textured(state)`, `TEXT_MAIN`. `class_name` is banned for NEW custom classes (the two pages' pre-existing `class_name` is left untouched).

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `run_system/ui/theme/wasteland_theme.gd` | Add shared `close_x_button()` factory | **Modify** |
| `run_system/ui/map_scene.gd` | Gate `_input` while a page is open (core fix) | **Modify** |
| `run_system/ui/run_deck_viewer_modal.gd` | Popup → opaque full-screen, corner ✕, ESC | **Modify** |
| `run_system/ui/equipment_panel.gd` | Text button → corner ✕, ESC | **Modify** |
| `assets/translations/ui_equipment.csv` | Drop orphaned `UI_EQUIP_BACK_TO_MAP` | **Modify** |

---

### Task 1: Shared top-right ✕ button helper

**Files:**
- Modify: `run_system/ui/theme/wasteland_theme.gd`

- [ ] **Step 1: Add the factory**

In `run_system/ui/theme/wasteland_theme.gd`, in the "Textured (PNG-based) builders" section (after `button_textured(...)`), add:

```gdscript
## A square ✕ close button for the full-screen pages (character / run-deck).
## The caller anchors it to the page's top-right corner and connects `pressed`.
static func close_x_button() -> Button:
	var b := Button.new()
	b.text = "✕"
	b.custom_minimum_size = Vector2(48, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", TEXT_MAIN)
	b.add_theme_stylebox_override("normal", button_textured("normal"))
	b.add_theme_stylebox_override("hover", button_textured("hover"))
	b.add_theme_stylebox_override("pressed", button_textured("pressed"))
	return b
```

- [ ] **Step 2: Smoke test**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`

- [ ] **Step 3: Commit**

```bash
git add run_system/ui/theme/wasteland_theme.gd
git commit -m "feat(ui): shared close_x_button() theme helper for full-screen pages"
```

---

### Task 2: Gate map `_input` while a page is open (the core 误触 fix)

**Files:**
- Modify: `run_system/ui/map_scene.gd`

- [ ] **Step 1: Extend the `_input` guard**

In `run_system/ui/map_scene.gd`, find the early-return at the top of `_input(event)`:

```gdscript
	if _is_relic_choice_open or _node_click_pending:
		return
```

Replace it with:

```gdscript
	if _is_relic_choice_open or _node_click_pending or _is_page_open():
		return
```

- [ ] **Step 2: Add the helper**

Add this method to `map_scene.gd` (e.g. directly after `_input`):

```gdscript
## True while a full-screen page (character / run-deck) is mounted over the map.
## map_scene resolves node clicks in the GLOBAL _input(), which fires regardless
## of the opaque page painted on top — without this gate, clicks pass through to
## map nodes (the 误触 bug).
func _is_page_open() -> bool:
	return get_node_or_null("EquipmentPanel") != null \
		or get_node_or_null("RunDeckViewerModal") != null
```

- [ ] **Step 3: Smoke test**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: the two `[OK]` lines.

- [ ] **Step 4: Runtime check — clicks no longer pass through**

Launch via godot MCP (`run_project` background). Run a `run_script` that: starts a run, generates a map, changes to `map_scene.tscn`, waits a beat, opens the Character page (`_open_equipment_panel`), records `RunManager.current_node_id`, then feeds a synthetic left-click `InputEventMouseButton` at a known node's screen position through `get_viewport().push_input(...)`, waits, and returns whether `current_node_id` changed. Expected: **unchanged** (no node consumed the click). Example script body:

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
	var rm = scene_tree.root.get_node_or_null("/root/RunManager")
	rm.start_new_run("cowboy_bill")
	if rm.map_data.is_empty(): rm.generate_map(12, 4)
	scene_tree.change_scene_to_file("res://run_system/ui/map_scene.tscn")
	await scene_tree.create_timer(0.4).timeout
	var map = scene_tree.current_scene
	map._open_equipment_panel()           # mount the Character page
	await scene_tree.create_timer(0.2).timeout
	var before = rm.current_node_id
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(300, 300)        # somewhere over the map
	scene_tree.root.push_input(ev)
	await scene_tree.create_timer(0.5).timeout
	return {"page_open": map._is_page_open(), "node_unchanged": rm.current_node_id == before}
```

Expected result: `{"page_open": true, "node_unchanged": true}`. (Before this task it could change / trigger a transition.) `stop_project` when done.

- [ ] **Step 5: Commit**

```bash
git add run_system/ui/map_scene.gd
git commit -m "fix(ui): map ignores node clicks while a full-screen page is open (no pass-through)"
```

---

### Task 3: Deck page → opaque full-screen + corner ✕ + ESC

**Files:**
- Modify: `run_system/ui/run_deck_viewer_modal.gd`

- [ ] **Step 1: Make the backdrop opaque and drop the centred-panel framing**

In `_build()`, replace this block:

```gdscript
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	panel.custom_minimum_size = Vector2(1180, 740)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 24)
	panel.add_child(margin)
```

with:

```gdscript
	# Opaque full-screen page (pseudo-scene). Map _input is gated separately so
	# clicks can't fall through; in battle the STOP overlay blocks card input.
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.035, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 48)
	add_child(margin)
```

(The existing `var vbox := VBoxContainer.new()` … `margin.add_child(vbox)` lines stay — `vbox` is still parented to `margin`, which is now full-rect.)

- [ ] **Step 2: Remove the inline header "X" (corner ✕ replaces it)**

In `_build()`, replace this block:

```gdscript
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.pressed.connect(queue_free)
	header.add_child(close_btn)
```

with:

```gdscript
	header.add_child(title)
```

- [ ] **Step 3: Mount the corner ✕ at the end of `_build()`**

At the very end of `_build()` (after the final `_rebuild.call()` line), add:

```gdscript
	_add_close_x()
```

Then add these two methods after `_build()`:

```gdscript
## Top-right ✕ — same effect as the second-press toggle (queue_free).
func _add_close_x() -> void:
	var x := T.close_x_button()
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -64.0
	x.offset_right = -16.0
	x.offset_top = 16.0
	x.offset_bottom = 64.0
	x.pressed.connect(queue_free)
	add_child(x)


## ESC closes the page. Battle's top-bar only consumes ESC when its settings menu
## is already visible, so this never conflicts; the map has no ESC handler.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
```

- [ ] **Step 4: Smoke test**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: the two `[OK]` lines.

- [ ] **Step 5: Runtime check (map + battle)**

Via godot MCP: (a) on the map, open the Deck page (`_open_run_deck_viewer`), `take_screenshot` — confirm it fills the screen opaque (no map showing through), with a top-right ✕. (b) Enter a battle (set `current_encounter`, change to `battle_scene.tscn`), open the deck page via `main.ui_manager.show_run_deck_viewer()`, screenshot — same full-screen look over the battle. Confirm clicking the ✕ frees it (`get_node_or_null("RunDeckViewerModal")` becomes null).

- [ ] **Step 6: Commit**

```bash
git add run_system/ui/run_deck_viewer_modal.gd
git commit -m "feat(ui): deck/gem page is a full-screen pseudo-scene with a top-right close (X/ESC)"
```

---

### Task 4: Character page → corner ✕ + ESC + key cleanup

**Files:**
- Modify: `run_system/ui/equipment_panel.gd`
- Modify: `assets/translations/ui_equipment.csv`

- [ ] **Step 1: Replace the "返回地图" header button with the corner ✕**

In `equipment_panel.gd` `_build()`, find and DELETE these lines (the header spacer + back button):

```gdscript
	header.add_child(_spacer())
	var close_btn := Button.new()
	close_btn.text = tr("UI_EQUIP_BACK_TO_MAP")
	close_btn.custom_minimum_size = Vector2(170, 44)
	T.apply_button_theme(close_btn)
	close_btn.pressed.connect(queue_free)
	header.add_child(close_btn)
```

(The header keeps title + vitals; they left-align, which is fine.)

- [ ] **Step 2: Mount the corner ✕ at the end of `_build()` + ESC**

At the very end of `_build()`, add:

```gdscript
	_add_close_x()
```

Then add these two methods after `_build()`:

```gdscript
## Top-right ✕ — returns to the map (queue_free), same as the old back button.
func _add_close_x() -> void:
	var x := T.close_x_button()
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -64.0
	x.offset_right = -16.0
	x.offset_top = 16.0
	x.offset_bottom = 64.0
	x.pressed.connect(queue_free)
	add_child(x)


## ESC also closes the character page (map has no competing ESC handler).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
```

- [ ] **Step 3: Remove the now-orphaned translation key**

`UI_EQUIP_BACK_TO_MAP` is no longer referenced by any `.gd` (grep to confirm zero `.gd` hits). Delete its row from `assets/translations/ui_equipment.csv` (the row begins `UI_EQUIP_BACK_TO_MAP,`).

- [ ] **Step 4: Reimport + smoke**

Run: `"C:/Program Files/Godot/Godot.exe" --headless --path . --import` (reimport the edited CSV), then
`GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: the two `[OK]` lines.

- [ ] **Step 5: Runtime check**

Via godot MCP: on the map, open the Character page (`_open_equipment_panel`), `take_screenshot` — confirm the top-right ✕ shows (no "返回地图" text button). Click the ✕ → page frees. Open it again and press ESC → page frees.

- [ ] **Step 6: Commit**

```bash
git add run_system/ui/equipment_panel.gd assets/translations/ui_equipment.csv
git commit -m "feat(ui): character page uses the shared top-right close (X/ESC); drop back-to-map key"
```

---

### Task 5: Final integrated verification

**Files:** none (verification only)

- [ ] **Step 1: End-to-end runtime pass**

Via godot MCP, in one session: map → open Character page → click over a map node → confirm NO node activates (`current_node_id` unchanged) AND the page is still up; close with ✕; open Deck page → confirm full-screen opaque + top-right ✕; close with ESC. Enter a battle → open Deck page via the top-bar D button path (`main.ui_manager.show_run_deck_viewer()`) → confirm full-screen over battle + ✕/ESC close. Capture one screenshot of each page.

- [ ] **Step 2: Final smoke**

Run: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`
Expected: the two `[OK]` lines.

- [ ] **Step 3: Confirm no sidecars staged across the branch**

Run: `git status --porcelain` — expect a clean tree (all committed); no `*.import`/`*.uid`/`*.translation` staged in any task commit.

---

## Self-Review

**Spec coverage:**
- ① Block map input while a page is open → Task 2 (`_is_page_open` guard). ✅
- ② Deck page popup → full-screen opaque + top-right X → Task 3. ✅
- ③ Character page text button → top-right X → Task 4. ✅
- ④ Shared close-X helper → Task 1 (`close_x_button`), used in Tasks 3 & 4. ✅
- ⑤ ESC closes → Tasks 3 & 4 `_input`; verified no battle-settings conflict (battle ESC only hides an already-open settings menu). ✅
- Orphaned `UI_EQUIP_BACK_TO_MAP` cleanup → Task 4 Step 3. ✅
- Pseudo-scene (no real `.tscn`) preserved; `class_name` untouched; perf out of scope. ✅

**Placeholder scan:** No TBD/TODO; every code step has complete code. The only lookup deferred to execution is the exact CSV row line (Task 4 Step 3) — resolved by a stated grep/prefix, not a guess. ✅

**Type consistency:** `close_x_button()` (Task 1) is called identically in Tasks 3 & 4; `_add_close_x()` / `_input(event)` defined per page with matching signatures; `_is_page_open()` referenced in the Task 2 guard and defined in the same task; named children `"EquipmentPanel"` / `"RunDeckViewerModal"` match the existing `_open_*` toggles. ✅
