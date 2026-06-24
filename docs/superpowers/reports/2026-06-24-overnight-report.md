# Overnight Report — Demo Polish (2026-06-24)

**Branch:** `overnight-0615` · **Spec:** `docs/superpowers/specs/2026-06-24-demo-polish-overnight-design.md`
**Mode:** `/goal` autonomous. Smoke-gated every phase. **Not pushed** (per the usual workflow).
**Verification:** headless smoke + `--import` after every phase (+ content-balance and
gdscript-reviewer subagent passes). **No windowed run** — the owner was at the office / the
godot MCP was on gopeak, so nothing visual was eyeballed. Visual + audio taste checks are
left for the owner (see Follow-ups).

## What shipped (8 commits)

| Commit | Phase | Summary |
|---|---|---|
| `a535088` | spec | design + execution plan |
| `316dc36` | P0 Audio | real menu track (*Wild West - Desert Wind*, Pixabay) + procedural BGM regenerated ~50–60s with seamless loop points + new shop/event slots + **all SFX → Kenney CC0**; READMEs record licensing |
| `183fa46` | P1 Economy | **99 gold start** + per-kill gold drops (elites ×2) + shop price retune (~400 gold/act now) |
| `b2a2ef2` | P2 Wishlist | dead label → real `OS.shell_open` button on **win AND defeat** + teaser |
| `82f5d47` | P3 Onboarding | rules panel teaches Tools/Relics/Equipment/Crit/Base + defines Luck & Charm; base "?" entry |
| `f21f39a` | P4 Juice | damage-scaled **screen shake** + all-hit sprite feedback (removed ≥10 gate) + death thud + energy pop |
| `64bde7b` | P5 Content | **3 elites** (was 1, now random per node) + 2 Bill cards (wildfire AoE-Burn, lucky_streak crit) + more events; balance pass tuned siege_breaker 22→20 |
| `b9ef9cb` | P6 Settings | **Battle Speed** toggle (1×/1.5×/2×) + legacy-save migration + demo doc fix |

All phases pass `[OK] DataValidator` + `[OK] Headless boot clean`. Catalog regenerated
(52 cards / 19 enemies). PRD updated (Phase 9 + Known Issues).

## Decisions honored (from the pre-run forks)
- Economy = **full** fix (99 + per-kill + price), not just 99-start.
- Demo stays **2 acts** → so content work focused on elite variety + Bill build paths.
- New enemies **reuse existing sprites** (chrome_hound, mortar_cart) + new movesets.
- Wishlist points at a **placeholder URL + TODO** (no App ID yet).
- Audio: menu = real track; battle/boss/map/home/shop/event = the owner-preferred procedural
  style, just **longer + seamless**; SFX = **Kenney CC0**.

## Deferred (need windowed visual verification or owner input)
- **Combat juice tail**: enemy idle-breathe (sprite display-scale is set post-setup → unsafe to
  base-capture blind), full enemy death sprite-fade (node-lifecycle timing), block/status number
  pops. All low-risk once they can be eyeballed.
- **Resolution dropdown** — skipped: the project uses `window/stretch/mode="viewport"`, so the
  window already scales; a dropdown is nice-to-have, not load-bearing.
- **Act-2-exclusive enemies** — the 3-elite variety + per-act stat/pool scaling partly cover the
  "act 2 = act 1 reskin" complaint; bespoke act-2 enemies would need new art (Codex).
- **BGM not in scope tonight** beyond the menu track + procedural rework (owner picks taste).

## Owner follow-ups
1. **Eyeball P4 juice + the reworked audio** in a windowed run — confirm shake/energy-pop feel and
   that the longer procedural BGM + Kenney SFX sound right (I could not listen).
2. **Real Steam App ID** → swap `STORE_URL` in `result_screen.gd` + `steam_appid.txt` (still `480`).
3. **Rotate the leaked PixelLab key** (PixelLab side).
4. If you want the deferred juice (idle-breathe / death-fade / number pops), say so and I'll do them
   with screenshot verification next time you're not at the office.

## How to verify locally
```bash
GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh   # data + boot
# then run the game windowed and check: menu music, a fight (shake/energy/SFX), the shop
# (99g, affordable), an elite (varies), result screen wishlist button, Settings → Battle Speed.
```
