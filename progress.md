# Progress Log

## Session 2026-06-30 — 大批打磨 + 发现机制 + 发现工具

起点:用户「美术做好了你看看」(Codex 交付美术验收)。一路展开成一整轮打磨。

### 完成 + 提交(`overnight-0615`,已 push + fast-forward 合并进 `main` 到 `a04f0e9`)

1. **美术验收接线**(07c7837):5 诅咒卡插画 `front_image`、5 槽位图标 `set_empty()`、`tool_belt`、3 货币图标(去掉烤入的数字)、卡背透明角。MCP 实拍验证货币/卡背/诅咒卡。
2. **卡牌插画缩小**(3dcaa08)+ 货币数字层级 + 铁匠铺仓库密度(c783062)。
3. **铁匠铺改造**(c2e98f8):配色只按稀有度、词条点选 + 单按钮锁定重铸、成本递增。MCP 验证(罕见 50→100、锁定金框、其余灰)。
4. **音效**:购买/铁匠铺先复用(ed18e01)→ 改成**原创合成 chiptune**(4ea26b8,`scripts/gen_sfx.py` numpy/scipy)→ 玩家/敌人受伤音 + BGM 默认 0.7→0.45(995238e)。
5. **装备 5 档稀有度**(b24265e):词条 common1/uncommon2/rare3/set3/cursed3+1诅咒;颜色灰/蓝/金/绿/红。MCP 验证 5 档颜色 + 去部位色。
6. **事件 UI 重做**(846c9e8,玻璃面板 + 横条选项卡)+ **5 张配图 Gemini 重生成**(40d0497,内容/画风全错的那几张)。MCP 验证 stranded_trader。
7. **关键词 tooltip 增强**(100c584):悬停整张卡弹全部术语(力量/眩晕/重放 + 5 属性,之前漏的补上);buried_cache 伪文字重生成。MCP 验证。
8. **发现机制**(2dd0d6a spec → 6b270ce plan → 6 task + 2 fix → e726c1c):discover effect + DiscoverModal(全新)+ cost_override 0费 + 3 示范卡。MCP 验证 modal 布局/候选筛选/0费。
9. **发现工具**(79b3bee):blood_kit(流血0费)/munitions_crate(攻击)/field_kit(技能)。工具走同一 `_apply_effect` → 直接复用 discover。smoke。

### 修复 / 教训
- **污染存档**:MCP 验证装备 5 档时 `stash.clear()` 塞测试装备 + reforge 触发 `save_progress()`,覆盖了用户真实仓库(`save_progress` 无写前备份)。已改存档加回误扣的 50 废料 + 留 5 件样品;记忆 `mcp-verify-no-save-pollution`。
- **DiscoverModal** `.instantiate()` → `.new()`(脚本不是 PackedScene);anchors+size 冲突 warning → TOP_LEFT。`--import` 比 `smoke` 更早抓到(battle_scene 不在 boot 路径)。

### Push + merge(用户明确指示)
- 推 `overnight-0615`(61 commit)+ `main` fast-forward 合并到 `a04f0e9` + 推 origin/main。
- `79b3bee`(发现工具)领先 main 1,**待用户定**推不推。

### 现状速查
- 事件:**12 个**(9 + 3 诅咒注入事件)。工具:11 个(8 原有 + 3 发现工具)。
- 验证方式:`GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` + godot MCP。

## Session 2026-06-30(下半) — 项目审计 + 诅咒进游戏 + 文档同步

用户:"审计 dead code + 过时 doc" → "成品图放进对话看 / 诅咒卡进游戏(事件特定) / 执行1、2 / dead doc"。

### 完成(均在 overnight-0615,未推)
- **Dead code**(70444e7):3 个只读 agent 并行审计(dead GDScript / 孤立 data+asset / 过时 doc)→ 我交叉核对。删孤立 `upgrade_panel.gd` + 14 处零调用函数(reforge 旧 API ×2、unlock_facility、battle_top_bar **整块死 settings overlay**、home_base/map 旧 _open_settings、is_drawing/inspect_card/get_status_badge_container/_refresh_badges_legacy/_build_legacy/_add_building_plaque_OLD)。`--import` 编译干净 + smoke 过。
- **Dead doc**:删 2 份真死(132728d)+ 归档 5 份(34a23da → docs/archive/)。
- **诅咒卡进游戏**(d022714):3 张到不了的诅咒各配一个"贪婪陷阱"事件 —— torn_coin_pouch(+100金+漏财)/ deserter_charm(回满血+怯懦)/ adrenaline_shot(+1力量+恐慌),选"拿"→ `add_curse` 永久进卡组(商店可移除)。事件扫目录自动进池 + 18 行 en/zh 翻译。`end_turn_in_hand` handler 已存在(battle_scene:666)。
- **文档同步**(2062fd7):PRD 装备整章重写(5档+rolled affix+set+cursed+forge)、Card Types 加 curse、effect 清单补全到 33、Phase 11 discover、删掉已删符号引用、shop 卖工具、slot 存档路径。

### 教训
- **agent 标的 high-confidence dead 单项仍要自己验证边界**:battle_top_bar `_build_settings_menu` 被标零调用没错,但它带一窝连锁死代码(`_show_settings` 已改走 PAUSE_PANEL,旧 settings_layer/_hide_settings/_on_return_map_pressed/_make_menu_button 全触达不到)——读全文件才发现是整块死,不是单函数。
- **装备 base `bonuses` 是 back-compat 兼容字段**:新掉落 `make_equip_instance` 随机 roll affixes **不读 bonuses**;只有旧存档裸字符串装备才从 bonuses 派生 affixes(`as_equip_instance`)。
- **事件本地化**:JSON 写英文 fallback,`Settings.t("EVENT_<ID>_TITLE/_DESC/_OPT<i>_TEXT/_OPT<i>_RESULT", fallback)`,翻译在 `ui_events.csv`(`keys,en,zh`),改完 `--import` 生成 .translation。

## Session 2026-07-01 — discover 实测修复 + push

用户实测发现界面截图,反馈 3 点 → 修复 + push main + clear。

### 完成(overnight-0615)
- **discover 青光 bug**(8c2052e):候选卡误显 `PlayableGlow`(能量够的"可打出"青脉冲)——它不是手牌不该亮。play_card 加 `suppress_playable_glow`,discover_modal 候选设 true。**这是用户说的"紫色"真凶,不是稀有度描边**(稀有度色按用户要求保留)。
- **discover 悬停关键词**(8c2052e):候选 `mouse_filter=IGNORE` + overlay 按钮只缩放 → 按钮补 `Tooltip.show(_build_keyword_glossary())` + 移出隐藏。
- **收敛发现载体**(8c2052e):删 3 张发现卡(scrap_scavenge/blood_recipe/armory_requisition:JSON + INITIAL_CARD_POOL + 翻译),discover **仅工具**触发。用户拍板。稀有度描边保留(用户选)。
- **文档/catalog**(36831c1 + 本次):PRD Phase 11 + PROJECT_STRUCTURE discover → tool-only;`gen_catalog_html.py` 重生成 cards.html(57 张)。

### 澄清(非改动)
- 用户以为"工具有空位自动进左上角栏" → 其实早改成**进背包 + 角色面板手动装备**(P5)。工具位保持 1(用户选)。

### 关键诊断(下次遇到可复用)
- 卡牌上的"可打出"高亮 = `PlayCard.PlayableGlow`(青色,`update_playable`→`visible=can_afford`),战斗中 `update_display` 每次调用。任何**非手牌复用 PlayCard** 的地方(discover/reward/查看)都要 `suppress_playable_glow=true`,否则青光乱亮。
- discover 候选 `mouse_filter=IGNORE`+overlay 按钮 → 卡自身 `_on_mouse_entered` 不触发,tooltip/hover 逻辑要从 overlay 驱动。
