# Spec — Shop / Base / Event UI overhaul + Gemini art (2026-06-23)

Overnight `/goal`. Autonomous; smoke-gated + MCP-verified per phase; committed per
phase (NOT pushed — owner reviews tomorrow). **BGM is out of scope for integration** —
I only curate candidate tracks for the owner to pick.

## Art pipeline (NEW)
The owner supplied a Gemini API key (stored in gitignored `.gemini_key`; key 1 was
suspended, key 2 works). `scripts/gen_art_gemini.py` calls **Imagen 4** to generate
opaque full-bleed background plates in a shared house style (hand-painted cartoon
wasteland). This REPLACES Codex for the backgrounds in this goal (ADR-0005 still holds
for transparent icons/frames — Imagen has no alpha). Generated PNGs ARE committed.

## Phases

### Phase 1 — Event localization completion (no art)
`event_modal.gd` already renders via `Settings.t("EVENT_<ID>_TITLE/DESC/OPT<n>_TEXT/
OPT<n>_RESULT…", english_fallback_from_json)`. The events CSV is missing a batch of zh
keys → those strings fall back to English. Audit all 8 events (`run_system/data/
random_events/*.json`), enumerate every key each event needs, and add complete zh to
`assets/translations/content_events.csv` (or wherever EVENT_ keys live). Fix the one
mojibake em-dash in `rad_storm`.

### Phase 2 — Event fullscreen pseudo-scene + per-event backgrounds
Today the event is a `0.78` black dim overlay — the map shows through. Change
`event_modal.gd` to a **fullscreen opaque pseudo-scene**: a per-event background image
(`run_system/assets/images/events/<id>.png`, cover-fit) that fully covers the map, a
dark readability scrim, then the existing title/desc/options panel on top. Fall back to
an opaque tinted ColorRect if the image is missing (warn-only). Generate 8 event
backgrounds (16:9) via Imagen, each matched to its event's mood.

### Phase 3 — Shop UI refactor + background
Generate a shop background (wasteland merchant's stall interior, 16:9). Refactor
`shop_scene.gd` framing to match the building-detail-page quality: the generated
background + scrim, a cleaner header/section/stall layout, consistent `wasteland_theme`
panels. Keep the cards/tools/relics/remove sections + all purchase logic intact.

### Phase 4 — Base UI backgrounds
`building_screen_base.gd` already looks for `run_system/assets/images/buildings/
<id>_bg.png` (falls back to a tint). Generate the 5 building backgrounds
(forge/clinic/market/outpost/warehouse) so each detail page gets real art. Generate a
home-base scene background if `home_base_scene.gd` supports one (else add the hook).

### Phase 5 — BGM candidates (curate only)
The current tracks are procedural-synth placeholders (`gen_audio.py`). Research
royalty-free (CC0 / CC-BY) music fitting a wasteland deckbuilder across the moods
(menu / map / battle / boss / shop / event). Produce a shortlist with source links +
notes (download a few CC0 ones into a `bgm_candidates/` folder if feasible) for the
owner to choose tomorrow. **Do NOT wire any track in.**

### Phase 6 — Verify + commit
Smoke after each code phase; MCP screenshots of the new event / shop / building pages;
keep docs/catalog in sync if content changed. Commit per phase `[goal PN]`, no push.

## Notes / limits
- Imagen quota: free-key daily caps — generate the ~15 needed plates, retry on 429.
- Backgrounds are opaque (no alpha) — fine for full-bleed plates; not for frames/icons.
- `.gemini_key` + `.gemini_art_tmp/` are gitignored — keys never committed.
