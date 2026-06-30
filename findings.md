# Findings (技术发现 / 架构速查)

> 项目正式文档在 `docs/PRD.md`、`docs/PROJECT_STRUCTURE.md`、`docs/superpowers/specs|plans/`、
> `docs/catalog_html/`。这里只记这次会话沉淀的关键点。

## 发现机制(Discover)架构
- effect: `{type:"discover", pool, count, free}`。`combat_engine._apply_effect` 的 discover case:
  `await main.open_discover(pool, count, free)`。
- **工具和卡牌都走 `_apply_effect`**(battle_scene `use_tool`/`_resolve_tool` 与 `play_spell` 一样)→
  工具直接复用 discover(blood_kit/munitions_crate/field_kit)。
- `battle_scene.open_discover()`:`DISCOVER_POOL.roll()` → `DiscoverModal.new()` → `await modal.discovered` →
  `deck_manager.add_card_to_hand()`(已改为**返回卡实例**)→ `free` 时 `card.set_meta("cost_override", 0)`。
- `discover_pool.roll(pool, count, unlocked)`:pool = 卡 type(attack/skill/ability)**或** 主题 tag;
  `bleed` 内置 effect 检测(查 effects 含 apply_status bleed / apply_bleed_scaled,不用给每张牌打 tag)。
- **cost_override**:卡实例 meta,本场 0 费。`card_cost()` helper 让 `can_afford`/`spend_energy` 读它;
  `play_card.set_card_data` 显示时优先 `get_meta("cost_override")`。卡打出/弃掉/战斗结束 → 实例销毁 → 自动失效。
- DiscoverModal 是**纯代码脚本**(extends Control,无 .tscn);全屏用 `PRESET_TOP_LEFT` anchors + 显式 size。

## 装备 5 档稀有度
- `affix_pool.AFFIX_COUNT` = `{common1, uncommon2, rare3, set3, cursed3}`;`roll(rarity, cursed)` 给 cursed 档 +1 诅咒词条。
- `RunManager.make_equip_instance`:有 `set_id` → rarity="set";`cursed` → rarity="cursed"。
- 颜色:`equipment_icon.gd` `RARITY_COLORS`(亮,描边)+ `RARITY_BG_COLORS`(暗,底)。配色**只按稀有度**(去掉部位色)。
- 中文名:uncommon=稀有、rare=罕见(`UI_FORGE_RARITY_*` / `UI_MARKET_RARITY_*`)。

## 音效合成
- `scripts/gen_sfx.py`:numpy/scipy 波形(square/sine/triangle/noise)+ ADSR 包络,chiptune 风。
- 已生成:purchase/upgrade/forge_craft/forge_dismantle/forge_reforge/forge_curse/player_hurt/enemy_hurt。
- 重新生成:`python scripts/gen_sfx.py [name ...]`(无参 = 全部)。

## 事件配图
- 事件背景 `run_system/assets/images/events/<id>.png`,cover-fit + scrim。
- `scripts/gen_art_gemini.py <out> 16:9 "<prompt>"`(Imagen 4,key 在 gitignored `.gemini_key`)。
  内置 STYLE = 手绘卡通废土 + **no people / background plate only**(事件人物在叙事文字里)。

## 验证铁律(踩坑)
- **MCP 不碰会 `save_progress()` 的真实存档**(`meta_progress.save_progress` 无写前备份 → 覆盖即丢)。
  存档:`~/AppData/Roaming/Godot/app_userdata/CardFramework/slot_N/`。
- `battle_scene` 等**非-autoload 脚本**:`smoke_test.sh` 只走 boot 路径不编译它们;改动后跑
  `"<godot>" --headless --path . --import` 才能抓 parse error。
- 实例化:脚本 `.gd` → `.new()`;PackedScene `.tscn` → `.instantiate()`。
