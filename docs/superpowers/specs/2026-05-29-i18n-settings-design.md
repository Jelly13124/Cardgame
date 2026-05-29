# Design — i18n + Settings System (English ↔ 简体中文)

**Date:** 2026-05-29
**Status:** Approved (brainstorming)
**Goal:** Add a Settings system whose headline feature is a language toggle, with a complete Simplified-Chinese translation of all UI and content, switchable at runtime and persisted across runs.

## Context

The project has **no i18n today** — no `TranslationServer` use, no locale/translation/font config in `project.godot`, and ~400 translatable strings: ~150 `.text = "…"` across ~15 UI `.gd` files, ~20 baked strings in 4 `.tscn` files, and ~230 content strings in JSON (60 card files, 13 enemies, 10 relics, 21 equipment, 8 base-upgrades, 2 heroes). An **in-battle settings overlay already exists** (`battle_scene/ui/battle_top_bar.gd` `_build_settings_menu()` — paused CanvasLayer, Resume / Return to Map, ESC-close); the home base (boot scene `run_system/ui/home_base_scene.gd`) has no settings entry. There is **no font file** in the project, so Chinese would render as tofu (□) without one — already resolved (see Font below).

## Decisions (locked during brainstorming)

- **Scope:** Settings = Language + Display (fullscreen toggle) + Audio placeholder (master-volume slider bound to the master audio bus).
- **Translation completeness:** Full — UI + all content this pass.
- **Font:** Noto Sans CJK SC, already downloaded to `assets/fonts/NotoSansCJKsc-Regular.otf` (16 MB, SIL OFL, commercial-OK).
- **Default + switching:** Default English; changing language persists, calls `TranslationServer.set_locale`, and reloads the current scene.

## Architecture

### 1. Mechanism — Godot built-in `tr()` + TranslationServer + CSV
Use Godot's native localization. `TranslationServer.set_locale("zh"/"en")` flips the whole UI. Translation source is **CSV** (`keys,en,zh`), auto-imported by Godot into `.translation` resources and registered via `project.godot [internationalization] locale/translations`.

Chosen over a custom dictionary autoload because it auto-translates the ~20 baked `.tscn` `Control.text` strings, flips locale in one call, integrates with `NOTIFICATION_TRANSLATION_CHANGED`, keeps translations in editable CSV, and adds the least custom code.

### 2. Key scheme
- **UI keys** — semantic, namespaced: `UI_END_ROUND`, `UI_PROCEED`, `SETTINGS_LANGUAGE`, `SETTINGS_FULLSCREEN`, `SETTINGS_VOLUME`. Formatted strings use Godot `{n}` placeholders resolved with `String.format`, e.g. `MAP_SCAVENGED_GOLD = "Scavenged {n} gold." / "捡到 {n} 金币。"` used as `tr("MAP_SCAVENGED_GOLD").format({"n": gold})`.
- **Content keys** — derived from the existing stable id: `CARD_<id>_TITLE`, `CARD_<id>_DESC`, `ENEMY_<id>_NAME`, `RELIC_<id>_TITLE`, `RELIC_<id>_DESC`, `EQUIP_<id>_NAME`, `EQUIP_<id>_DESC`, `SET_<id>_NAME`, `UPGRADE_<id>_NAME`, `UPGRADE_<id>_DESC`, `HERO_<id>_NAME`, `HERO_<id>_DESC`.
- Content JSON stays **English (source of truth)**. Display goes through `Settings.t(key, english_fallback)`: returns the translation, or the English fallback if the key is missing/untranslated. A missing zh value therefore degrades to English — never to a raw key, never a crash.

### 3. Font — one global setting
Set `project.godot [gui] theme/custom_font = "res://assets/fonts/NotoSansCJKsc-Regular.otf"`. Every `Control` inherits it. Noto Sans CJK includes proportional Latin, so English renders cleanly too — no second font needed. (Future optimization: subset the font to glyphs actually used once translations exist; out of scope now.)

### 4. Persistence — new `Settings` autoload
`run_system/core/settings.gd`, registered in `project.godot [autoload]` **before the main scene** so locale applies on the first frame. Stores `user://settings.json`: `{ "language": "en"|"zh", "fullscreen": bool, "master_volume": float }`.
- `_ready()`: load → `TranslationServer.set_locale(language)`, apply window mode, apply master-bus volume.
- API: `set_language(loc)`, `set_fullscreen(on)`, `set_master_volume(v)` — each persists then applies.
- `Settings.t(key, fallback)`: the content-translation helper (lives on this autoload; referenced directly per the autoload exception to the no-`class_name` rule). Returns `tr(key)` unless it came back equal to `key` (untranslated), in which case returns `fallback`.
- Independent autoload (no dependency on RunManager/MetaProgress).

### 5. Settings UI (Language + Display + Audio)
- **Entry points:** (a) extend the existing battle-top-bar settings overlay; (b) **add a settings entry on the home base** (boot scene) — the primary, safe-to-reload place to switch language.
- **Controls:** Language toggle (中文 / English); Fullscreen toggle; Master-volume slider (bound to master audio bus — functional placeholder even before SFX exist).
- **Apply semantics:** Language → `Settings.set_language` + `get_tree().reload_current_scene()`. Fullscreen / volume apply live (no reload). In the battle overlay the language control is labelled `(重启战斗 / restarts battle)` because reload restarts the current battle; the home base is the intended place to switch.

### 6. Translation glossary (consistency contract for parallel translators)
A canonical term table all translators MUST follow, so parallel agents stay consistent:

| EN | 中文 | EN | 中文 |
|---|---|---|---|
| Block | 格挡 | Strength | 力量 |
| Constitution | 体质 | Intelligence | 智力 |
| Luck | 幸运 | Charm | 魅力 |
| Vulnerable | 易伤 | Weak | 虚弱 |
| Poison | 中毒 | Burn | 灼烧 |
| Shock | 感电 | Energy | 能量 |
| Draw (cards) | 抽牌 | Exhaust | 消耗 |
| Retain | 保留 | Damage | 伤害 |
| Heal | 治疗 | Gold | 金币 |
| Relic | 遗物 | Equipment | 装备 |
| Card | 卡牌 | Deck | 牌组 |
| Enemy | 敌人 | Boss | 首领 |
| Elite | 精英 | Rest | 休整 |
| Merchant | 商人 | Treasure | 宝箱 |
| Core (currency) | 核心 | Ascension | 进阶 |
| Attack | 攻击 | Skill | 技能 |
| Ability | 能力 | Upgrade | 强化 |

Proper-name guidance (translate meaningfully, keep flavor): Cowboy Bill → 牛仔比尔; Rust Titan → 锈蚀泰坦; Ash Warden → 灰烬守望者; Junkyard Tyrant → 废料场暴君; Chrome Hound → 铬犬; Acid Spitter → 喷酸者; Slag Walker → 熔渣行者. Tone: terse, punchy, game-appropriate — match the English's brevity; keep `[b]…[/b]` BBCode and `{n}` placeholders intact.

### 7. Parallel-safe file ownership (critical for multi-agent execution)
To let many agents run concurrently with **zero write conflicts**, every file has exactly one owner and translations are split into **multiple CSVs** (Godot loads a list of translation files):
- `assets/translations/ui_<area>.csv` — one per UI area (battle, map, loot, shop, home_base, equipment, hero_select, common).
- `assets/translations/content_<type>.csv` — one per content type (cards, enemies, relics, equipment, upgrades, heroes).
- Each agent edits only its own `.gd`/`.tscn`/`.json`-display code **and** its own CSV. No two agents touch the same file. Shared files (`project.godot`, `settings.gd` incl. the `Settings.t` helper) are written only in Phase 1.

### 8. Phasing
1. **Foundation (sequential, executed and smoke-verified by Claude during setup):** font global config; `Settings` autoload + `Locale.t`; CSV scaffolding + `locale/translations` registration; Settings UI (language/fullscreen/volume) on battle overlay + home base; the glossary committed into this spec. Gates everything.
2. **UI strings (parallel by area):** replace `.text = "English"` with `tr("UI_KEY")`; convert `.tscn` baked text to keys; populate the area's `ui_*.csv` (en + zh).
3. **Content (parallel by type):** add `CONTENT_*` rows (en from JSON + zh) to the type's `content_*.csv`; route display through `Settings.t(key, english_fallback)`.
4. **Verification:** headless smoke (`GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`); a key-audit script that flags any CSV key missing a zh value and any remaining hardcoded UI string; a final consistency pass against the glossary.

## Risk control (overnight, unattended)
- Smoke gate after Phase 1 and at Phase 4; Phase 1 is human-verified before fan-out.
- CSV is additive (en column = current strings); imperfect zh never breaks English.
- Content falls back to English → a missing/wrong zh value never breaks display or crashes.
- File-ownership partitioning → no concurrent-write corruption.
- Biggest residual risk is translation quality/consistency → mitigated by the glossary; user reviews in the morning.

## Acceptance criteria
- A Settings menu reachable from the home base and the in-battle overlay, offering Language (中文/English), Fullscreen, and Master Volume.
- Switching to 中文 renders Chinese correctly (font present, no tofu) across menus, battle, map, loot, shop, cards, enemies, relics, equipment; switching back to English restores English.
- Language choice persists across app restarts (`user://settings.json`).
- Every UI string and every content title/description has both an `en` and a `zh` CSV entry; the key-audit script reports zero missing zh values and zero remaining hardcoded UI strings.
- `bash scripts/smoke_test.sh` ends `[OK] DataValidator: all schemas passed.` with a clean boot.

## Out of scope (YAGNI)
Additional languages beyond en/zh; per-SFX audio (only master-bus volume now); font subsetting; translating dev/debug or addon strings.
