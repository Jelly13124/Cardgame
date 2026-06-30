# Task Plan — CardFramework (废土拾荒) 进度

**Goal:** 持续把 Steam demo(废土拾荒 · roguelite deckbuilder · Godot 4.6)打磨到工业级。
**Branch:** `overnight-0615`(已 push + fast-forward 合并进 `main` 到 `a04f0e9`)。
**Last updated:** 2026-06-30(审计会话)。`overnight-0615` 领先 `main` **7 个 commit**(发现工具 + dead-code 清理 + 诅咒进游戏 + 文档同步,均待定推不推)。

## 本会话 Phases(全部 complete)

| # | Phase | Status | Commit |
|---|---|---|---|
| 1 | 美术交付验收 + 接线(诅咒卡/槽位/货币/卡背/tool_belt) | ✅ MCP | 07c7837 |
| 2 | 卡牌插画缩小 + 货币层级 + 铁匠铺密度 | ✅ MCP | 3dcaa08 / c783062 |
| 3 | 铁匠铺改造(只按稀有度配色 + 单词条锁定重铸 + 递增成本) | ✅ MCP | c2e98f8 |
| 4 | 音效(铁匠铺/购买/受伤 原创合成 + BGM 降量) | ✅ | ed18e01 / 4ea26b8 / 995238e |
| 5 | 装备 5 档稀有度(common/uncommon/rare/set/cursed) | ✅ MCP | b24265e |
| 6 | 事件 UI 重做 + 5 张配图 Gemini 重生成 | ✅ MCP | 846c9e8 / 40d0497 |
| 7 | 关键词 tooltip 增强(悬停卡牌弹全部术语) | ✅ MCP | 100c584 |
| 8 | 发现机制(discover effect + DiscoverModal + 0费 + 3 卡) | ✅ MCP | 2dd0d6a..e726c1c |
| 9 | 发现工具(blood_kit / munitions_crate / field_kit) | ✅ smoke | 79b3bee |

## 2026-06-30 审计会话(complete)

| # | Phase | Status | Commit |
|---|---|---|---|
| A | Dead code 审计+删除(孤立 upgrade_panel.gd + 14 处零调用函数 + battle_top_bar 整块死 settings overlay) | ✅ import+smoke | 70444e7 |
| B | Dead doc:删 2 份真死(open-art-backlog / asset-spec-sts2-port)+ 归档 5 份使命完成的 → docs/archive/ | ✅ | 132728d / 34a23da |
| C | 诅咒卡进游戏:3 个贪婪陷阱事件注入 cowardice/panic/leaking_wealth(torn_coin_pouch / deserter_charm / adrenaline_shot) | ✅ import+smoke | d022714 |
| D | 文档同步:PRD/PROJECT_STRUCTURE/data-files(装备5档+affix / curse / discover / 33 effect清单 / 删除已删符号引用) | ✅ | 2062fd7 |

## 待办 / Follow-up (open)

- [ ] **发现工具 free 语义**:确认"本场 0 费"(现状,cost_override)OK,还是改成严格"本回合 0 费"(回合末恢复)——**用户待定**。
- [ ] **发现卡 + 发现工具真图**:目前占位(curse_placeholder / 复用工具图)。要写 Codex asset-spec。
- [ ] **discover tools (79b3bee) 推 + 合并 main**?——用户待定。
- [ ] **装备掉落**:set/cursed 专门掉落渠道(首版套装件按 base 稀有度掉、然后渲染成 set 档)。
- [ ] 事件图 `hooded_stranger`/`fortune_shrine` 勉强搭氛围,可选重做。

## 决策记录

- **发现机制**:战斗内 + 加当前手牌(炉石核心);候选按卡类型或主题 tag 筛(bleed 内置 effect 检测);`free` = 本场战斗 0 费(cost_override)。
- **DiscoverModal** 全新(暗化遮罩 + 三张大卡居中),**不套** loot/reward 奖励骨架。
- **装备 5 档**:`set` = 有 `set_id` 的件(绿,3词条+套装效果);`cursed` = 诅咒(红,3正面+1诅咒)。
- **中文命名(用户)**:uncommon=**稀有**、rare=**罕见**(改了 UI_FORGE/MARKET_RARITY_*)。
- **git**:默认不推;用户明确要才 push + merge main。

## 关键约定(踩过的坑,见 findings.md)

- MCP 验证**不碰会 `save_progress()` 的真实存档**(无写前备份,会覆盖用户仓库)。只读 / 备份 / 空 slot。
- `battle_scene` 等**非-autoload 脚本**改动要 `--import` 验证(smoke 不编译它们,只编译 boot 路径)。
- 脚本(`.gd`)实例化用 `.new()`;PackedScene(`.tscn`)才用 `.instantiate()`。
