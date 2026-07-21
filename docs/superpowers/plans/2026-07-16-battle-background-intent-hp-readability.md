# Battle Background, Intent, and HP Readability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a quieter 1080p battlefield, STS2 category-based enemy intents with hover-only detail, and larger health bars whose numerals no longer overpower the bar art.

**Architecture:** Keep battle rules and scene anchors unchanged. Refactor `enemy_entity.gd` so one intent group owns a horizontal list of small category cells and one shared tooltip, while `CharacterHUD` continues to own all HP rendering with revised size constants. Replace the battle background through the existing scene texture resource, using a generated presentation-only PNG.

**Tech Stack:** Godot 4.6, GDScript, built-in ImageGen, PNG assets, existing global `Tooltip`, Godot headless contract tests, Windows/OpenGL runtime capture.

## Global Constraints

- Use option B: Bleed, Weak, Frail, and Vulnerable all use one generic red debuff/down-arrow category icon; concrete status and stacks appear only in the hover tooltip.
- Preserve enemy JSON, action selection, combat arithmetic, status application, encounter balance, combatant positions, cards, energy, block arithmetic, and top-bar behavior.
- The new battlefield is 1920x1080, opaque, pale dusty beige/warm gray, and keeps approximately 80% of the center quiet.
- HP sizes are exactly player `184x28`, normal `160x26`, elite `184x28`, and boss `216x30`.
- HP numerals use Kreon Bold at 13–15 px with a two-pixel outline.
- Do not add persistent intent words or status names.
- Work in the existing dirty workspace without staging, committing, pushing, resetting, or cleaning unrelated user changes.

---

## File structure

- Create `battle_scene/assets/images/backgrounds/wasteland_battlefield_quiet_v3.png`: low-presence battlefield art.
- Create `battle_scene/assets/images/ui/intent_debuff.png`: generic red debuff/down-arrow category icon.
- Modify `battle_scene/battle_scene.tscn`: point `BattleBackground` at the new texture.
- Modify `battle_scene/enemy_entity.gd`: build and update a multi-cell intent group with one hover tooltip.
- Modify `battle_scene/player.gd`: set the player HP tier to `184x28`.
- Modify `battle_scene/ui/character_hud.gd`: reduce HP numeral scale to the approved clamp.
- Modify `tests/ui_sts2_hud_contract_test.gd`: contract coverage for the new background, HP tiers, and category intent behavior.
- Modify `tests/ui_sts2_hud_visual_capture.gd`: deterministic partial-HP and attack-plus-debuff capture.

---

### Task 1: Lock the new contracts with failing tests

**Files:**
- Modify: `tests/ui_sts2_hud_contract_test.gd`
- Test: `tests/ui_sts2_hud_contract_test.tscn`

**Interfaces:**
- Consumes: `ENEMY_ENTITY.create(enemy_id: String) -> Node`, `EnemyEntity._health_bar_size() -> Vector2i`, and named intent child nodes.
- Produces: a contract requiring `IntentCells`, `IntentAttack`, `IntentDebuff`, and numeric-only `IntentValue` labels.

- [ ] **Step 1: Change the battle-background and HP expectations**

Replace the current background and tier checks with:

```gdscript
_expect(
	background_path.ends_with("/wasteland_battlefield_quiet_v3.png"),
	"battle uses the quiet negative-space background (got %s)" % background_path
)
_expect(player_hud.bar_width == 184, "player health bar is the 184 px hero tier")
_expect(player_hud.bar_height == 28, "player health bar is 28 px tall")
_expect(
	hp_label != null and hp_label.get_theme_font_size("font_size") <= 15,
	"HP numerals remain at or below 15 px"
)
_expect(normal_enemy._health_bar_size() == Vector2i(160, 26), "normal enemies use 160x26 bars")
_expect(elite_enemy._health_bar_size() == Vector2i(184, 28), "elites use 184x28 bars")
_expect(boss_enemy._health_bar_size() == Vector2i(216, 30), "bosses use 216x30 bars")
```

- [ ] **Step 2: Add an attack-plus-debuff intent contract**

Add this async helper and call it from `_run()` after `_test_battle_energy_and_end_turn()`:

```gdscript
func _test_category_intents() -> void:
	var enemy := ENEMY_ENTITY.create("acid_spitter")
	add_child(enemy)
	await get_tree().process_frame
	var cells := enemy.find_child("IntentCells", true, false) as HBoxContainer
	_expect(cells != null, "enemy exposes a horizontal IntentCells group")
	_expect(enemy.find_child("IntentAttack", true, false) != null, "attack_status shows attack intent")
	_expect(enemy.find_child("IntentDebuff", true, false) != null, "attack_status shows generic debuff intent")
	var values := enemy.find_children("IntentValue", "Label", true, false)
	for value in values:
		_expect(str(value.text).is_valid_int(), "always-visible intent labels contain numbers only")
	var visible_text := ""
	for label in enemy.find_children("*", "Label", true, false):
		visible_text += " " + str(label.text)
	_expect("Bleed" not in visible_text and "流血" not in visible_text, "Bleed name is hover-only")
	_expect("Bleed" in str(enemy.get("_intent_tooltip")) or "流血" in str(enemy.get("_intent_tooltip")), "tooltip retains concrete Bleed detail")
	enemy.queue_free()
	await get_tree().process_frame
```

- [ ] **Step 3: Run the contract and verify RED**

Run:

```powershell
& 'tmp\godot_runner\Godot_v4.6-stable_win64_console.exe' --headless --path . res://tests/ui_sts2_hud_contract_test.tscn
```

Expected: nonzero exit with failures for the old background path, old HP tiers, `IntentCells`, and `IntentDebuff`.

---

### Task 2: Implement STS2 category-based multi-intents

**Files:**
- Create: `battle_scene/assets/images/ui/intent_debuff.png`
- Modify: `battle_scene/enemy_entity.gd`
- Test: `tests/ui_sts2_hud_contract_test.gd`

**Interfaces:**
- Consumes: `peek_next_action() -> Dictionary`, `_compute_display_attack(base_amount: int) -> int`, and `_build_intent_tooltip(next: Dictionary) -> String`.
- Produces: `_set_intent_cells(specs: Array[Dictionary]) -> void`, `_add_intent_cell(kind: String, texture: Texture2D, value: String, color: Color) -> Control`, named nodes `IntentCells`, `IntentAttack`, `IntentDebuff`, and `IntentValue`.

- [ ] **Step 1: Generate and normalize the generic debuff icon**

Use built-in ImageGen with this exact visual brief:

```text
Single game UI intent icon, one bold red downward arrow with a slightly crooked hand-inked silhouette, dark charcoal comic outline, tiny pale edge highlight, clean 2D American-comic style, readable at 30 pixels, centered, no text, no letters, no numbers, no circle, no badge, no panel, no drop shadow, solid chroma-green background #00FF00, square canvas.
```

Remove only connected edge chroma-green pixels, trim transparent padding without cutting the outline, center on a square canvas, and save as `battle_scene/assets/images/ui/intent_debuff.png`.

- [ ] **Step 2: Replace the one-icon/one-label badge with a horizontal cell host**

In `_build_intent_badge()`, keep `_intent_bg` and all existing tooltip signals, but replace `_intent_icon` and `_intent_label` construction with:

```gdscript
_intent_cells = HBoxContainer.new()
_intent_cells.name = "IntentCells"
_intent_cells.alignment = BoxContainer.ALIGNMENT_CENTER
_intent_cells.add_theme_constant_override("separation", 7)
_intent_cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
_intent_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
_intent_bg.add_child(_intent_cells)
```

Declare:

```gdscript
const INTENT_ICON_DEBUFF = preload("res://battle_scene/assets/images/ui/intent_debuff.png")
const INTENT_CELL_ICON_SIZE := Vector2(34.0, 34.0)
var _intent_cells: HBoxContainer
```

Remove `_intent_icon` and `_intent_label` fields and their construction.

- [ ] **Step 3: Add a named intent-cell builder**

Add:

```gdscript
func _add_intent_cell(kind: String, texture: Texture2D, value: String, color: Color) -> Control:
	var cell := HBoxContainer.new()
	cell.name = "Intent%s" % kind
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", 2)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = INTENT_CELL_ICON_SIZE
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	if value != "":
		var label := Label.new()
		label.name = "IntentValue"
		label.text = value
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(label)
	_intent_cells.add_child(cell)
	return cell
```

- [ ] **Step 4: Rebuild category cells from the next action**

Replace the display portion of `_update_intent_display()` with a clear-and-rebuild switch:

```gdscript
if not _intent_cells:
	return
for child in _intent_cells.get_children():
	child.queue_free()
var next := peek_next_action()
var action_type := str(next.get("type", ""))
match action_type:
	"attack", "attack_ramp", "attack_all":
		_add_intent_cell("Attack", INTENT_ICON_ATTACK, str(_compute_display_attack(int(next.get("amount", 0)))), Color("#ffc69e"))
	"attack_status":
		_add_intent_cell("Attack", INTENT_ICON_ATTACK, str(_compute_display_attack(int(next.get("amount", 0)))), Color("#ffc69e"))
		_add_intent_cell("Debuff", INTENT_ICON_DEBUFF, "", Color.WHITE)
	"block", "breakable_block", "reflective_plating":
		_add_intent_cell("Block", INTENT_ICON_BLOCK, str(int(next.get("amount", 0))), Color("#a6dbff"))
	"heal", "buff":
		var amount := int(next.get("amount", 0))
		_add_intent_cell("Buff", INTENT_ICON_BUFF, str(amount) if amount > 0 else "", Color("#b8ff9e"))
	"telegraph":
		_add_intent_cell("Charge", INTENT_ICON_CHARGE, "", Color("#ffdb6b"))
	_:
		_add_intent_cell("Buff", INTENT_ICON_BUFF, "", Color("#b8ff9e"))
_intent_tooltip = _build_intent_tooltip(next)
```

Do not append interruptibility punctuation or any status/action words. Keep interruptibility explanation in `_build_intent_tooltip()`.

- [ ] **Step 5: Run the category-intent contract**

Run the contract command from Task 1. Expected: all intent assertions pass; background and HP assertions may still fail until Tasks 3–4.

---

### Task 3: Enlarge HP tiers and restore numeral hierarchy

**Files:**
- Modify: `battle_scene/player.gd`
- Modify: `battle_scene/enemy_entity.gd`
- Modify: `battle_scene/ui/character_hud.gd`
- Test: `tests/ui_sts2_hud_contract_test.gd`

**Interfaces:**
- Consumes: `CharacterHUD.bar_width`, `CharacterHUD.bar_height`, and `_health_bar_size() -> Vector2i`.
- Produces: the exact four approved size tiers and a 13–15 px HP numeral clamp.

- [ ] **Step 1: Change HP size constants**

Use:

```gdscript
# player.gd
const PLAYER_HUD_SIZE := Vector2i(184, 28)

# enemy_entity.gd
const NORMAL_HUD_SIZE := Vector2i(160, 26)
const ELITE_HUD_SIZE := Vector2i(184, 28)
const BOSS_HUD_SIZE := Vector2i(216, 30)
```

- [ ] **Step 2: Reduce HP numeral scaling**

In `character_hud.gd`, replace the HP font-size expression with:

```gdscript
_hp_label.add_theme_font_size_override(
	"font_size", clampi(int(round(float(bar_height) * 0.52)), 13, 15)
)
```

Keep the generated track/fill textures, two-pixel outline, delayed-loss animation, fill inset, and block badge unchanged.

- [ ] **Step 3: Run the HUD contract**

Run the Task 1 command. Expected: HP and intent assertions pass; only the missing/new background may remain red.

---

### Task 4: Generate and integrate the low-presence battlefield

**Files:**
- Create: `battle_scene/assets/images/backgrounds/wasteland_battlefield_quiet_v3.png`
- Modify: `battle_scene/battle_scene.tscn`
- Test: `tests/ui_sts2_hud_contract_test.gd`

**Interfaces:**
- Consumes: the existing `BattleBackground` `TextureRect` and its viewport scaling.
- Produces: one opaque 1920x1080 background with no runtime text or controls baked into the raster.

- [ ] **Step 1: Generate the background with ImageGen**

Use this exact prompt:

```text
1920x1080 production background for a 2D American-comic roguelike card battle. Extremely understated dusty parchment wasteland, pale warm beige and warm gray, low saturation and low contrast. Approximately 80 percent of the central image is calm negative space for characters and combat UI. Only very faint flat mesa and dune silhouettes near the upper-middle horizon, softened by dust haze. Sparse tiny stones and short dry brush limited to the lowest 12 to 15 percent and far left/right edges. Clean restrained hand-inked style with thin faded lines, no focal landmark. No characters, enemies, buildings, pipes, utility poles, giant cactus, skulls, text, UI, cards, bright sun, dramatic clouds, glow, heavy black outlines, or dense ground cracks. Opaque full-frame image.
```

Save the generated result at the exact asset path above without transparency processing.

- [ ] **Step 2: Point the battle scene at the new asset**

Change the `ext_resource` background path in `battle_scene/battle_scene.tscn` to:

```text
res://battle_scene/assets/images/backgrounds/wasteland_battlefield_quiet_v3.png
```

- [ ] **Step 3: Import and run the contract**

Run:

```powershell
& 'tmp\godot_runner\Godot_v4.6-stable_win64_console.exe' --headless --editor --path . --quit
& 'tmp\godot_runner\Godot_v4.6-stable_win64_console.exe' --headless --path . res://tests/ui_sts2_hud_contract_test.tscn
```

Expected: `[OK] STS2 HUD contract passed` and exit code 0.

---

### Task 5: Runtime capture and regression verification

**Files:**
- Modify: `tests/ui_sts2_hud_visual_capture.gd`
- Inspect: `tmp/ui-battle-runtime.png`

**Interfaces:**
- Consumes: the battle scene, player damage/block APIs, and a deterministic attack-plus-debuff enemy setup.
- Produces: a real 1920x1080 Windows/OpenGL screenshot proving the complete composition.

- [ ] **Step 1: Make the capture deterministic**

Keep the existing player damage and block setup. Before rendering, find the first enemy; if the active encounter does not expose an `attack_status` action, replace its `action_pattern` with a presentation-only capture pattern and refresh the intent:

```gdscript
var enemies := scene.find_children("*", "EnemyEntity", true, false)
if not enemies.is_empty():
	var enemy: Node = enemies[0]
	enemy.set("action_pattern", [{"type": "attack_status", "amount": 4, "status": "bleed", "stacks": 2}])
	enemy.set("_action_index", 0)
	enemy.call("update_intent_display")
```

This mutation exists only in the capture scene and does not change runtime encounter data.

- [ ] **Step 2: Capture the real battle**

Run:

```powershell
& 'tmp\godot_runner\Godot_v4.6-stable_win64_console.exe' --path . --display-driver windows --rendering-method gl_compatibility res://tests/ui_sts2_hud_visual_capture.tscn
```

Expected: `tmp/ui-battle-runtime.png` is updated at 1920x1080.

- [ ] **Step 3: Inspect the capture**

Verify all of the following from the raster:

- the center background has no competing focal point;
- player and enemy silhouettes remain distinct;
- player HP is partial and the red bar is visually heavier than its 14–15 px text;
- the selected enemy shows sword plus damage and a separate generic red down-arrow;
- no `Bleed`, `流血`, `Weak`, `虚弱`, or other intent word is visible;
- cards, energy, end-turn control, and pile icons remain in their existing positions.

- [ ] **Step 4: Run the full regression gate**

Run every `tests/*test.tscn` with the verified Godot console runner, then:

```powershell
git diff --check
git status --short -- battle_scene tests docs/superpowers
```

Expected: all test scenes exit 0, `git diff --check` prints nothing, and status lists only intentional changes plus pre-existing user work.
