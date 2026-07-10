# Equipment, Tools, Shop, and Top Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复通用装备拖拽预览、角色窗口工具槽和商店崩溃，统一 15 件通用装备命名，并替换顶部栏卡组图标。

**Architecture:** `EquipmentIcon` 成为装备贴图解析的唯一入口，Character/Stash/Forge 只消费该接口。工具槽继续复用 `BackpackCell`，而 `RunManager` 只增加一个精确落格 API；商店工具保持无稀有度模型。PNG 仅做确定性的边缘连通残片清理。

**Tech Stack:** Godot 4.6、GDScript、JSON、CSV、Python catalog generator、PNG alpha post-processing。

## Global Constraints

- 不改变装备 ID、稀有度、词条、掉落权重、工具效果或商店价格。
- 通用装备系列固定为 `拾荒者 / 游骑兵 / 军官`，不新增 `set_id` 或套装效果。
- 工具没有稀有度；商店统一使用 `TOOL_ACCENT`。
- 顶部栏继续保持一个工具格和 48×48 无框卡组按钮。
- 15 张装备 PNG 保持各文件现有画布尺寸与透明通道，主体造型/颜色/方向不变。
- 保留工作区既有改动，不提交无关文件或 `.import` / `.uid`。

---

### Task 1: Add failing UI and interaction regression tests

**Files:**
- Create: `tests/equipment_tool_shop_contract_test.gd`
- Create: `tests/equipment_tool_shop_contract_test.tscn`

**Interfaces:**
- Consumes: current `EquipmentIcon`, `RunManager`, `CharacterWindow`, `ShopScene`, `RunTopBar` behavior.
- Produces: one headless contract scene that fails on every reported regression before production edits.

- [ ] **Step 1: Write the failing test**

The test must assert all of the following with real project objects:

```gdscript
var shell := EQUIPMENT_ICON.resolve_equipment_texture("", "hands", "common")
_expect(shell != null, "empty sprite resolves hands_common shell art")

rm.tool_inventory.assign(["med_kit"])
rm.backpack[3] = null
_expect(rm.unequip_tool_to_backpack(0, 3), "tool can unequip to exact empty cell")
_expect(rm.backpack[3] == {"kind": "tool", "id": "med_kit"}, "exact target receives tool")

var stall := shop._build_tool_stall({"tool_id": "med_kit", "price": 40})
_expect(stall != null, "tool stall builds without rarity")

_expect(_button_icon_path(topbar, "UI_BATTLE_VIEW_RUN_DECK").ends_with("/iconb_deck_stack.png"),
    "deck button uses the new stack icon")
```

It must also instantiate `CharacterWindow` in `map` mode, find named `ToolSlot0`, and assert that the empty slot accepts only a backpack tool and the filled slot emits `src == "tool_slot"`.

- [ ] **Step 2: Run test to verify it fails for the expected missing interfaces**

Run:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/equipment_tool_shop_contract_test.tscn
```

Expected: non-zero exit with missing `resolve_equipment_texture`, missing `unequip_tool_to_backpack`, missing/nondraggable `ToolSlot0`, shop `rarity` access, and old deck icon assertions.

- [ ] **Step 3: Commit the red contract test**

```powershell
git add tests/equipment_tool_shop_contract_test.gd tests/equipment_tool_shop_contract_test.tscn
git commit --only -m "test: cover equipment and tool UI regressions" -- tests/equipment_tool_shop_contract_test.gd tests/equipment_tool_shop_contract_test.tscn
```

### Task 2: Centralize equipment texture resolution and rename generic shells

**Files:**
- Modify: `run_system/ui/equipment_icon.gd`
- Modify: `run_system/ui/window/character_window.gd`
- Modify: `run_system/ui/window/stash_window.gd`
- Modify: `run_system/ui/window/forge_window.gd`
- Modify: `run_system/data/equipment/gear_{head,chest,weapon,hands,accessory}_{common,uncommon,rare}.json`
- Modify: `assets/translations/content_equipment.csv`

**Interfaces:**
- Produces: `static func resolve_equipment_texture(sprite_path: String, slot: String, rarity: String) -> Texture2D`.
- Consumes: JSON `sprite`, `slot`, and effective instance rarity.

- [ ] **Step 1: Implement the minimum shared resolver**

```gdscript
static func resolve_equipment_texture(sprite_path: String, slot: String, rarity: String) -> Texture2D:
    var candidates: Array[String] = []
    if sprite_path != "":
        candidates.append("res://battle_scene/assets/images/" + sprite_path)
    candidates.append("%s%s_%s.png" % [SHELL_ICON_DIR, slot, rarity])
    for path in candidates:
        if ResourceLoader.exists(path):
            var tex := load(path) as Texture2D
            if tex:
                return tex
        if FileAccess.file_exists(path):
            var image := Image.load_from_file(path)
            if image:
                return ImageTexture.create_from_image(image)
    return null
```

`set_equipment()` and all three drag-preview call sites must invoke this function; no window keeps its own explicit-sprite-only resolver.

- [ ] **Step 2: Apply the approved 15 names**

Use exactly these series: common `Scavenger / 拾荒者`, uncommon `Ranger / 游骑兵`, rare `Officer / 军官`; use the exact item names from `docs/superpowers/specs/2026-07-10-equipment-tools-shop-ui-design.md` in JSON and translation CSV.

- [ ] **Step 3: Run the contract test**

Expected: equipment texture/name assertions pass; tool/shop/deck assertions may still fail.

- [ ] **Step 4: Commit the focused equipment change**

```powershell
git add run_system/ui/equipment_icon.gd run_system/ui/window/character_window.gd run_system/ui/window/stash_window.gd run_system/ui/window/forge_window.gd run_system/data/equipment assets/translations/content_equipment.csv
git commit --only -m "fix: unify generic equipment visuals and names" -- run_system/ui/equipment_icon.gd run_system/ui/window/character_window.gd run_system/ui/window/stash_window.gd run_system/ui/window/forge_window.gd run_system/data/equipment assets/translations/content_equipment.csv
```

### Task 3: Make the wrench tool slot a bidirectional BackpackCell

**Files:**
- Modify: `run_system/core/run_manager.gd`
- Modify: `run_system/ui/window/character_window.gd`

**Interfaces:**
- Produces: `func unequip_tool_to_backpack(tool_index: int, backpack_index: int) -> bool`.
- Produces: named `ToolSlot%d` cells with backpack-tool input and `tool_slot` output.

- [ ] **Step 1: Implement exact destination semantics**

```gdscript
func unequip_tool_to_backpack(tool_index: int, backpack_index: int) -> bool:
    _ensure_backpack()
    if tool_index < 0 or tool_index >= tool_inventory.size():
        return false
    if backpack_index < 0 or backpack_index >= effective_backpack_size():
        return false
    if backpack[backpack_index] != null:
        return false
    backpack[backpack_index] = {"kind": "tool", "id": tool_inventory[tool_index]}
    tool_inventory.remove_at(tool_index)
    backpack_changed.emit()
    tools_changed.emit()
    return true
```

- [ ] **Step 2: Wrap empty and filled tool visuals in BackpackCell**

Empty cells accept only `src == "backpack" && kind == "tool"`; filled cells publish `{"src":"tool_slot","index":index,"tool_id":tool_id}`. `_wire_backpack_drop()` accepts `tool_slot` only when the destination cell is empty and calls `unequip_tool_to_backpack()`.

Remove the extra orange ring from `_make_tool_board()`. Filled tool cells use the real icon and a 2px cyan `T.ACCENT_NEON_BLUE` border. Battle mode remains locked; left-click continues to call the first-free APIs.

- [ ] **Step 3: Run the contract and character layout tests**

Expected: tool exact-target, drag payload, accepted-kind, and existing 7×3 layout assertions pass.

- [ ] **Step 4: Commit tool interaction**

```powershell
git add run_system/core/run_manager.gd run_system/ui/window/character_window.gd
git commit --only -m "fix: support bidirectional tool slot dragging" -- run_system/core/run_manager.gd run_system/ui/window/character_window.gd
```

### Task 4: Fix tool shop construction and replace the deck icon

**Files:**
- Modify: `run_system/ui/shop_scene.gd`
- Modify: `run_system/ui/run_top_bar.gd`
- Modify: `tests/ui_sts2_hud_contract_test.gd`

**Interfaces:**
- Produces: `TOOL_ACCENT` fixed color; tools remain `{tool_id, price}`.
- Consumes: `res://run_system/assets/images/ui_kit_lightline/iconb_deck_stack.png`.

- [ ] **Step 1: Remove tool rarity reads**

```gdscript
const TOOL_ACCENT := Color(0.38, 0.80, 0.93)
```

Use `TOOL_ACCENT` for missing-icon glyph and tool description. Do not add a `rarity` key to stock entries.

- [ ] **Step 2: Route the deck button to the existing lightline icon**

Add `DECK_ICON_PATH` and load it defensively for the deck button while keeping its tooltip, click signal, size, and empty styleboxes unchanged.

- [ ] **Step 3: Run the shop/UI contracts and direct shop boot repeatedly**

```powershell
1..3 | ForEach-Object { & 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://run_system/ui/shop_scene.tscn --quit-after 3 }
```

Expected: each run exits zero with three tool stalls and no `rarity` or null-child error.

- [ ] **Step 4: Commit the shop and top-bar fix**

```powershell
git add run_system/ui/shop_scene.gd run_system/ui/run_top_bar.gd tests/ui_sts2_hud_contract_test.gd
git commit --only -m "fix: stabilize tool shop and update deck icon" -- run_system/ui/shop_scene.gd run_system/ui/run_top_bar.gd tests/ui_sts2_hud_contract_test.gd
```

### Task 5: Clean equipment edge debris and verify the complete UI batch

**Files:**
- Modify: `battle_scene/assets/images/ui/equipment/*.png` only when an edge-connected non-primary component exists.
- Generated: `docs/catalog_html/equipment.html`
- Generated: `docs/catalog_html/index.html`

**Interfaces:**
- Consumes: existing RGBA equipment art with per-file canvas dimensions.
- Produces: identical main connected component with edge-only foreign components cleared.

- [ ] **Step 1: Prove the current edge artifact check fails**

Analyze alpha-connected components and assert that `hands_common.png` and `hands_rare.png` contain non-primary components touching the canvas edge.

- [ ] **Step 2: Remove only edge-connected non-primary components**

Use an 8-neighbor alpha mask, retain the largest subject component and all non-edge components, and zero RGBA only for smaller components touching x/y canvas bounds. Verify every output keeps its original dimensions/RGBA mode and the main component pixel count is unchanged.

- [ ] **Step 3: Regenerate catalogs and run all relevant tests**

```powershell
python scripts/gen_catalog_html.py
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/equipment_tool_shop_contract_test.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/character_window_layout_contract_test.tscn
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --scene res://tests/ui_sts2_hud_contract_test.tscn
```

- [ ] **Step 4: Capture and inspect character/top-bar visuals**

Run both visual capture scenes, inspect `tmp/character-window-runtime.png` and `tmp/ui-sts2-hud-runtime.png`, and confirm no doubled glove edge, no double wrench frame, correct real tool icon, and correct deck icon.

- [ ] **Step 5: Commit assets and generated catalog output**

Stage only actually changed equipment PNGs plus generator-owned catalog files.
