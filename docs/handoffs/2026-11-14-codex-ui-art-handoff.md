# Codex handoff: one art style for the whole game (2026-11-14)

The game currently mixes several art styles:

- the enemy roster redrawn on 2026-11-10 (commit `e8aa358`);
- painterly AI scenes with rendered light: events, rest site, forge, and the act 2 and
  act 3 battle backgrounds;
- glossy, bevelled "mobile game" item icons: relics, equipment, status icons;
- dense, gritty comic illustration: shop, shopkeeper, main menu, home buildings;
- generic dark-teal UI panels.

**The user's decision is that every image in the game moves to the style of the
2026-11-10 enemy roster.** This applies whether the image was AI-generated or not. This
brief defines that style precisely. It then lists the new UI and map art, and every
existing image that must be redrawn to match.

The audit behind this brief is `docs/reviews/2026-11-14-ui-audit.md`. Its screenshots are
in `.superpowers/ui-audit-2026-11-14/`, which is git-ignored and exists only locally.

This brief replaces:

- the open items in `docs/art/node-map-art-brief.md`;
- the event and UI items in `docs/handoffs/2026-11-10-codex-art-handoff.md`.

The hit-effect brief (`2026-11-14-codex-hit-vfx-handoff.md`) stays separate and still
applies. Its flipbooks follow the style rules below as well.

## Rules for this work

- **Art only.** Create PNG files. Do not edit `.gd`, `.tscn`, `.json`, `.import` or
  translation files. Claude wires every file in.
- **Original art.** STS2 and DICEOMANCER are references for screen structure only. Do not
  trace, copy, recolour or closely imitate any asset from either game.
- **Work in two steps.** First deliver only the style tile (Step 1) and stop. Start the
  full set only after the user approves the tile.
- **No text in images.** The game draws all words, numbers and prices, so leave every
  label area plain. The only exception is the existing title logo, which you must not
  touch.
- **Exact size and format.** Each file must have the exact pixel size and format listed.
  An RGBA file must have a fully transparent background, with no matte, halo or magenta
  fringe.
- **Replacing files.** A *drop-in* or *redraw* file overwrites the file at the same path.
  Git keeps the old version, so nothing is lost. Never delete or rename any other file.

## Style bible: the 2026-11-10 enemy style

### The anchor

Open these files and match them. Where this text and the files disagree, follow the files.

- **Primary anchor:** the 20 enemies at
  `battle_scene/assets/images/enemies/*/attack/*_attack_0.png`. The best references are
  `rust_brute`, `trash_robot`, `wasteland_killer`, `scrap_rat` and `mortar_cart`.
- **Hero:** `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_portrait.png`.
- **Backgrounds:**
  - the act 1 battle background
    `battle_scene/assets/images/backgrounds/wasteland_battlefield_act1_v1.png`;
  - the home base background `run_system/assets/images/home/home_base_empty_bg.png`.
- **Cards:** `hot_streak`, `lucky_streak`, `reload`, `strike`, `defend` and `brace` in
  `battle_scene/assets/images/cards/player/`.

### What makes it that style

1. **One confident cartoon outline.**
   - Every shape has a confident, slightly irregular outline in warm near-black `#1a100a`.
     It reads as hand-drawn but steady, with no sketchy doubled strokes, no brush texture
     and no hatching.
   - The outline is about 2% of the subject's height: 5 px on a 256 px character, 3 px
     on a 128 px icon and 2 px on a 64 px icon.
   - Inner lines (folds, seams, panel edges) are about half the outline weight. Keep them
     few.
2. **Two flat tones per material.**
   - Each material is a flat base colour plus one hard-edged shadow shape, as in cel
     shading. The light comes from the top left, so shadows fall to the lower right.
   - Highlights are rare. When used, a highlight is a small flat shape, never a gradient
     or a shine.
   - No gradients, airbrush, glow or bloom. The only exceptions are deliberate effects:
     fire, sparks, plasma and screen glows.
3. **Big, chunky, simple shapes.**
   - Silhouettes must read at half size.
   - Proportions are stocky and slightly cartoon-like, with big hands, boots and heads.
   - Each object has at most about five details. Patches, stitches, seams, a few dents and
     a crooked joint or cable are the house motifs; use them sparingly. Never draw a rivet
     field.
4. **No surface texture.** That means no grain, noise, scratches, dirt speckle, rust-streak
   texture, wood-grain hatching or photographic material. Show wear with one or two flat
   patches or chips, never with texture.
5. **Muted, earthy colour with small bright accents.** Large areas are desaturated rust,
   khaki, ochre, olive, brown and gunmetal. Saturated colour is only for small accents:
   glowing eyes, energy, toxic slime, the caps orange.
6. **Backgrounds follow the same rules, only quieter.**
   - The outline is thinner, about 3 px at 1920×1080. It is drawn in a dark tone of the
     local colour rather than near-black.
   - Fills are two-tone as everywhere else, with lower contrast and fewer details than the
     characters.
   - A sky may use two or three flat colour bands, or one very soft gradient as in the
     act 1 background.

### What counts as off-style

Do not draw in any of these looks.

| Off-style look | Where it appears now |
|---|---|
| Painterly rendering: volumetric light beams, soft shading, atmospheric haze, blurry depth | Event illustrations, act 2 and act 3 battle backgrounds, forge background |
| Glossy icons: bevels, metallic gradients, specular shines, baked-in drop shadows | Relics, equipment, status icons |
| Dense gritty comic: heavy texture, scratch marks, dozens of small props | Shop background, shopkeeper, main menu background, home buildings, rest-site campfire, some cards |
| Saturated "magic" backgrounds: purple, magenta or teal skies behind the subject | Several cards |

### Palette

These colours are sampled from the enemy roster. Nearby tints and shades are fine.

| Role | Hex |
|---|---|
| Outline | `#1a100a` |
| Rust dark (coats, shadows) | `#602020` |
| Rust | `#a8432c` |
| Brown (leather, wood) | `#604030` |
| Brown shade | `#403020` |
| Khaki (cloth, paper) | `#b09070` |
| Khaki light / parchment | `#e8d6b0` |
| Ochre (caps orange, brass, hazard paint) | `#d09a2a` |
| Olive (army metal, canvas) | `#707050` |
| Gunmetal | `#505458` |
| Skin, warm | `#f0a060` |
| Accent: toxic green | `#9ccc3c` |
| Accent: energy cyan | `#4fd8e0` |
| Accent: danger red | `#c8382c` |
| Accent: block blue | `#5a8fb0` |

Card art backgrounds use the desert-dusk palette of the in-style cards: an ochre sky and
rust buttes. Use a dark night variant only when the card's subject needs it. Do not use
purple, magenta or teal skies.

### Three UI materials, drawn in that style

Every UI surface is a real object from the world, made of one of three materials. Draw
each with the same outline and two-tone fills as the enemies. Do not use generic
dark-teal slabs.

| Material | What it looks like | Used for |
|---|---|---|
| **Paper** | Light khaki parchment with a slightly torn edge, one flat shadow band, and a nail or tape at the top. | Map, legend, tooltips, event text, reward list, bounty posters, result screen, tutorial tips |
| **Scrap metal** | A plate painted rust, ochre or olive, with a flat chipped patch at one corner and at most two to four bolts drawn as simple outlined dots. No rivet fields, bulky corner plates or bevels. | Buttons, battle HUD (energy, piles, end turn), top bar, relic price tags, slots |
| **Canvas** | Olive or khaki canvas with a stitched seam, or a saddle blanket with a simple flat geometric border. | Shop rug, deck and pile viewer backdrop, rest-site choice cards |

### Icons

All icons belong to one family:

- Each icon is a single object in the enemy style, with an outline, two tones and at
  most one accent colour.
- The background is transparent. Do not put a badge behind the icon unless the table
  asks for one.
- The canvas is 128×128 RGBA. The subject fills the central 104×104, with a transparent
  margin around it.
- Every icon must stay readable at 40 px.
- **Exception:** map node icons are flat cream (`#e8d6b0`) silhouettes with an outline,
  because they sit on a dark octagon.
- Small UI and intent icons follow the project rule in `docs/art-style-reference.md`: one
  clear silhouette and one main colour, no faces, no skulls (except the elite and boss map
  icons, where the skull is the meaning) and no tiny salvage decoration.

## Step 1: Style tile (deliver this first, then stop)

**File:** `docs/art/previews/ui-v2-style-tile.png`, 1920×1080 RGB.

Draw one composed sheet that shows:

- **Map:** a corner of the parchment map with three nodes (available, visited and
  unreachable), one boss node and the player token.
- **Buttons:** a primary and a secondary button, each in its normal and hover states.
- **Panel:** a paper panel holding an empty reward row.
- **Battle HUD:** the energy orb, a draw-pile icon and the end-turn button.
- **Icons:** six from the icon list: heart, caps, deck, map, settings and close.
- **Shop:** a paper price tag and one corner of the shop rug.
- **Redraws:** one sample each from the redraw list, placed beside the file it replaces:
  a relic (`repair_kit`), an equipment piece (`warden_helm`) and a card (`double_tap`).
- **Style check:** a copy of one roster enemy (`rust_brute`), so the match can be judged
  at a glance.

Leave label areas blank, as they will be in the game. Then hand the tile back for review.

## Step 2: Full set (only after the tile is approved)

There are two kinds of files below:

- **Drop-in** files replace a file at the same path and size. The game picks them up with
  no code change, so they must keep the exact size and the nine-slice margins given.
- **New** files go under `run_system/assets/images/ui_v2/`. Claude wires them in.

Nine-slice margins are written as left/top/right/bottom, in pixels. Inside a margin,
keep corners and edge details. The centre area between the margins gets stretched, so
keep it plain.

### A. Map (drop-in; the code already looks for these paths)

Folder: `run_system/assets/images/map/`.

The reference is the user's own map: warm parchment, dark octagonal nodes with cream
icons, thin dashed paths, a player token, and an orange walked path. The code draws the
paths; you draw only the files below.

| File | Size | What it is |
|---|---|---|
| `route_parchment.png` | 3730×1000 RGB | The whole act on one sheet of field-map parchment. It shows under the top bar and scrolls sideways. Add small vignettes in the enemy style (thin outline, flat two-tone fills, pale and low contrast) only in the top and bottom 130 px and the left and right 200 px: dry scrub, rock buttes, a leaning telegraph pole, a half-buried pipe, a broken windmill, a skull. The band y 130–870 stays plain paper: one flat colour with a few soft fold-crease bands. **No paths, nodes, roads or text.** Keep it pale. |
| `node_octagon_available.png` | 96×96 RGBA | Octagon base for a node you can pick now. Dark brown fill (around `#3a2f27`), a thick cream rim, a clean outline. Leave the centre flat, because the code draws the icon on top. |
| `node_octagon_visited.png` | 96×96 RGBA | The same octagon with a darker fill (around `#211a15`) and a thin dull rim. |
| `node_octagon_unreachable.png` | 96×96 RGBA | The same octagon as a light warm-grey wash with a thin rim (the code also fades it to 45%). |
| `node_octagon_boss.png` | 144×144 RGBA | A larger octagon with a heavier rim and rust spikes or bolts around the rim. |
| `nodes/enemy.png` | 128×128 RGBA | Replaces the existing file at the same size. Revolver silhouette. Cream silhouette in the icon family. |
| `nodes/elite.png` | 128×128 RGBA | Replaces the existing file. Horned skull. |
| `nodes/rest.png` | 128×128 RGBA | Replaces the existing file. Campfire. |
| `nodes/merchant.png` | 128×128 RGBA | Replaces the existing file. Sack with a bottle cap on it. |
| `nodes/treasure.png` | 128×128 RGBA | Replaces the existing file. Strongbox. |
| `nodes/unknown.png` | 128×128 RGBA | Replaces the existing file. Question mark. |
| `nodes/relic.png` | 128×128 RGBA | Replaces the existing file. Crystal shard. |
| `nodes/boss.png` | 128×128 RGBA | Replaces the existing file. Crowned skull. |
| `start_flag.png` | 64×64 RGBA | Small orange cloth flag on a thin pole. The pole's foot sits at the bottom centre. |
| `legend_card.png` | 360×420 RGBA | Torn parchment card with an outline border and a nail at the top. Leave the inside plain. |

Map, new file (`run_system/assets/images/ui_v2/map/`):

| File | Size | What it is |
|---|---|---|
| `player_token.png` | 128×128 RGBA | A game-piece token of Cowboy Bill: his hat and poncho silhouette on a round wooden base, like a board-game pawn. The base's centre sits at the canvas centre plus 40 px down. |

### B. Shared UI kit (drop-in; restyles every panel and button at once)

Folder: `run_system/assets/images/ui/kit/`. Keep each file's exact size and nine-slice
margins, because the theme code applies those margins.

| File | Size | Nine-slice L/T/R/B | What it is |
|---|---|---|---|
| `button_primary_base.png` | 320×96 RGBA | 20/16/20/16 | Main action button (Depart, Proceed, End turn style). Rust-red painted scrap plate, a bolt dot in two corners, one flat chipped patch, a dark ink rim. Plain centre. |
| `button_primary_outline.png` | 320×96 RGBA | 20/16/20/16 | Only the rim of the same shape as a soft warm-white glow line, transparent elsewhere. The code shows it on hover. |
| `button_secondary_base.png` | 320×96 RGBA | 20/16/20/16 | Secondary button: a gunmetal plate with a thin brass rim. |
| `button_secondary_outline.png` | 320×96 RGBA | 20/16/20/16 | Rim glow for the secondary button, drawn the same way as the primary outline. |
| `panel_hard_9slice.png` | 96×96 RGBA | 24/24/24/24 | Paper panel: parchment with a torn edge and an outline border. This is the default for dialogs, reward lists and tutorials. |
| `panel_soft_9slice.png` | 96×96 RGBA | 24/24/24/24 | Quieter panel: darker, worn canvas with a stitched border, for backgrounds behind lists. |
| `tooltip_panel_9slice.png` | 320×96 RGBA | 55/43/91/32 | Small torn field-note paper. The right edge is slightly curled, which is why the right margin is wider. |
| `tooltip_shadow_9slice.png` | 320×96 RGBA | 55/43/91/32 | The same silhouette filled flat black at full alpha (the code fades it). |
| `banner_long.png` | 652×162 RGBA | — | Title banner: a nailed wooden plank or a painted tin sign with ragged ends. Plain centre for the title. Used on the reward, shop, rest, result and map screens. |
| `banner_short.png` | 360×96 RGBA | — | A short version of the same banner. |
| `divider.png` | 256×8 RGBA | 8/0/8/0 | An ink line drawn as rope or barbed wire, transparent background. |
| `corner.png` | 32×32 RGBA | — | A single nail head for panel corners. |
| `input_9slice.png` | 192×64 RGBA | 20/16/20/16 | Text field: a recessed paper strip with an outline border. |
| `dropdown_9slice.png` | 192×64 RGBA | 20/16/20/16 | Dropdown: the same strip with a raised tin edge. |
| `dropdown_arrow.png` | 32×32 RGBA | — | Small ink chevron. |
| `checkbox_unchecked.png` | 32×32 RGBA | — | Small tin square. |
| `checkbox_checked.png` | 32×32 RGBA | — | The tin square with an ink check mark. |
| `checkbox_unchecked_disabled.png` | 32×32 RGBA | — | Greyed version of the unchecked box. |
| `checkbox_checked_disabled.png` | 32×32 RGBA | — | Greyed version of the checked box. |

### C. Battle HUD

Drop-in files in `battle_scene/assets/images/ui/combat/`:

| File | Size | What it is |
|---|---|---|
| `hp_frame.png` | 250×16 RGBA | HP bar frame: a thin tin channel with an ink rim. Transparent inside. |
| `hp_track.png` | 250×16 RGBA | The empty track: dark recessed fill. |
| `hp_fill.png` | 250×16 RGBA | The current-HP fill: flat danger red with a one-tone highlight along the top. The code crops it horizontally. |
| `hp_loss.png` | 250×16 RGBA | The recent-loss fill: pale bone-white with the same shape. |
| `intents/attack_1.png` | 64×64 RGBA | Small attack (under 5 damage): a short simple red sword. The project rule is that attack intents are red swords; the three sizes differ in blade length and width only. |
| `intents/attack_2.png` | 64×64 RGBA | Medium attack (5–19): a longer, broader red sword. |
| `intents/attack_3.png` | 64×64 RGBA | Big attack (20 or more): a big heavy red sword with one small flat spark. |
| `intents/block.png` | 64×64 RGBA | A simple blue shield silhouette. |
| `intents/buff.png` | 64×64 RGBA | A simple green upward arrow. |
| `intents/debuff.png` | 64×64 RGBA | A purple downward arrow with one drip. |
| `intents/card_debuff.png` | 64×64 RGBA | A card with a crack through it. |
| `intents/charge.png` | 64×64 RGBA | A simple orange warning mark (exclamation in a triangle, drawn as a shape). |
| `intents/death_blow.png` | 64×64 RGBA | A red crosshair over a cracked heart. |
| `intents/escape.png` | 64×64 RGBA | A running boot with dust. |
| `intents/heal.png` | 64×64 RGBA | A syringe with a plus sign. |
| `intents/multi.png` | 64×64 RGBA | Three small bullets in a row. |
| `intents/sleep.png` | 64×64 RGBA | A "Zz" drawn as a shape, not as font text. |
| `intents/status.png` | 64×64 RGBA | A junk card with a bent corner. |
| `intents/stun.png` | 64×64 RGBA | Circling stars. |
| `intents/summon.png` | 64×64 RGBA | A radio antenna sending waves. |
| `intents/unknown.png` | 64×64 RGBA | Question mark. |

New files in `run_system/assets/images/ui_v2/hud/`. Each one is drawn at twice its display
size.

| File | Size | What it is |
|---|---|---|
| `energy_orb_back.png` | 256×256 RGBA | Back plate: a round brass housing with a dark recessed centre and four bolt dots. |
| `energy_orb_gear.png` | 256×256 RGBA | A thin toothed gear ring that sits over the housing rim. The code rotates it, so it must be radially even and centred. |
| `energy_orb_glow.png` | 256×256 RGBA | An inner ring of warm ochre light: soft and additive-friendly, bright near the ring and transparent elsewhere. It rotates the opposite way to the gear. |
| `energy_orb_glass.png` | 256×256 RGBA | Front cap: a slightly domed glass lens over a bottle cap, with one highlight at the top left. Keep the middle 110 px fairly clear, because the energy number sits there. |
| `end_turn_base.png` | 440×180 RGBA | Big round-cornered rust tin plate with two bolt dots and a hand-painted look, larger and heavier than `button_primary_base.png`. Plain centre for the label. |
| `end_turn_outline.png` | 440×180 RGBA | Rim-only glow line for the same shape. |
| `end_turn_glow.png` | 440×180 RGBA | A soft additive warm glow around the plate (one of the allowed glow effects). The code pulses it when the player has no plays left. |
| `pile_draw.png` | 160×160 RGBA | Draw pile: a small stack of face-down cards tied with twine, seen at a slight angle. |
| `pile_discard.png` | 160×160 RGBA | Discard pile: a messy fanned stack of face-up cards, with blank faces. |
| `pile_exhaust.png` | 160×160 RGBA | Exhaust pile: a small smoking ash heap with a burnt card corner. |
| `pile_count_badge.png` | 72×72 RGBA | A round tin badge with an ink rim for the pile count. Plain centre. |
| `enemy_nameplate.png` | 320×56 RGBA | A small painted tin nameplate for an enemy name. Nine-slice 24/12/24/12. Plain centre. |
| `intent_number_badge.png` | 64×40 RGBA | An optional little paper tag behind the intent damage number. Plain centre. |

### D. Icon set

New files in `run_system/assets/images/ui_v2/icons/`. All are 128×128 RGBA in the icon
family.

| File | Subject |
|---|---|
| `heart.png` | HP heart: a cream heart with a red accent fill and a stitched patch. |
| `caps.png` | Bottle cap (the currency): flat side view with crimped edge, caps-orange accent. |
| `xp.png` | A sheriff star with a small arrow. |
| `floor.png` | A boot print or milestone marker. |
| `deck.png` | A stack of cards seen from the side. |
| `map.png` | A folded field map. |
| `settings.png` | A gear with a wrench. |
| `timer.png` | A pocket watch. |
| `language.png` | A globe drawn like a wanted-poster stamp. |
| `close.png` | An ink X, thick and slightly rough. |
| `back.png` | A left arrow painted on a tin scrap. |
| `sort.png` | Two stacked arrows (up and down). |
| `card_reward.png` | A fan of three blank cards with a star on the front one. |
| `relic_slot_empty.png` | An empty dashed circle, for an empty relic shelf slot. |
| `tool_slot_empty.png` | An empty dashed square with a small wrench, for an empty tool slot. |
| `block.png` | A simple shield, block-blue accent. |
| `bounty.png` | A pinned wanted poster. |
| `lock.png` | A rusty padlock. |
| `remove_card.png` | A card being cut by scissors. |

### E. Rewards, card choice and result

New files in `run_system/assets/images/ui_v2/rewards/`.

| File | Size | What it is |
|---|---|---|
| `reward_panel.png` | 560×700 RGBA | A tall sheet of worn parchment nailed at the top two corners, with a torn bottom edge and a faint dust stain. The rows sit on it, so keep the area from x 40–520 and y 120–640 plain. |
| `reward_row.png` | 804×172 RGBA | One reward row (shown at 402×86): a paper strip with an outline border and a slightly darker left pocket where the 56 px icon sits. Nine-slice 120/40/40/40. |
| `reward_row_outline.png` | 804×172 RGBA | Rim-only hover glow for the row. |
| `proceed_base.png` | 540×216 RGBA | Proceed button (shown at 270×108): a tin arrow sign pointing right, painted rust red, with two bolt dots. Plain centre for the label. |
| `proceed_outline.png` | 540×216 RGBA | Rim-only glow for the proceed sign. |
| `banner_victory.png` | 1300×320 RGBA | Victory banner: a wide plank sign with bottle caps nailed at both ends and a little warm sunburst behind it. Plain centre. |
| `banner_defeat.png` | 1300×320 RGBA | Defeat banner: the same plank, cracked and hanging at a slight tilt from one broken chain. Plain centre. |

### F. Shop

| File | Size | What it is |
|---|---|---|
| `run_system/assets/images/ui_v2/shop/shop_background.png` | 1920×1080 RGB | A **quiet** merchant tent interior: canvas walls, one hanging lamp, a few crates and the counter edge at the bottom. Keep x 1450–1920 and y 300–1080 open for the shopkeeper sprite. Keep x 80–1400 and y 200–1000 calm, because the goods rug lies there. Much less clutter and contrast than the current `shop_interior_bg.png`, in the enemy style. |
| `run_system/assets/images/ui_v2/shop/shop_rug.png` | 1400×820 RGBA | A saddle-blanket rug laid flat, with a woven geometric border in rust, ochre and teal and a plain centre. The goods sit on it in two rows. |
| `run_system/assets/images/ui_v2/shop/price_tag.png` | 160×64 RGBA | A paper price tag hanging on a string from the top left. Plain area for a cap icon and a number. |
| `run_system/assets/images/ui_v2/shop/price_tag_sale.png` | 160×64 RGBA | The same tag with a small red "slash" stamp shape. Do not write any word on it. |
| `run_system/assets/images/ui_v2/shop/price_tag_unaffordable.png` | 160×64 RGBA | The same tag, greyed and crumpled. |
| `run_system/assets/images/ui_v2/shop/relic_stand.png` | 160×160 RGBA | A small tin plate or wooden stand that a relic or tool sits on. |
| `run_system/assets/images/ui_v2/shop/remove_service.png` | 300×360 RGBA | The card-removal service as an object: an old paper shredder or a burn barrel with a card going in. The top 70% is the object; the bottom 30% stays plain for the price. |

### G. Rest site

| File | Size | What it is |
|---|---|---|
| `run_system/assets/images/ui_v2/rest/rest_background.png` | 1920×1080 RGB | Night camp in the wastes. Cowboy Bill sits on a crate at left-centre beside a small campfire. Behind him: dark buttes and a starry sky. Keep the top-centre band (x 520–1400, y 200–900) dark and plain, because the two choices and their description sit there. The fire glow is drawn as flat colour shapes, not rendered light. |
| `run_system/assets/images/ui_v2/rest/choice_rest.png` | 512×340 RGBA | Choice card art: a bedroll and a steaming tin cup, drawn on a canvas card with an outline border. |
| `run_system/assets/images/ui_v2/rest/choice_forge.png` | 512×340 RGBA | Choice card art: an anvil with a glowing card on it, on the same canvas card. |
| `run_system/assets/images/ui_v2/rest/choice_outline.png` | 512×348 RGBA | Rim-only hover glow for a choice card. |

### H. Event screen

| File | Size | What it is |
|---|---|---|
| `run_system/assets/images/ui_v2/events/option_9slice.png` | 568×110 RGBA | Event option: a strip of paper with an outline border and a small nail at the left. Nine-slice 60/30/40/30. Plain centre. |
| `run_system/assets/images/ui_v2/events/option_outline.png` | 568×110 RGBA | Rim-only hover glow for the option, with the same margins. |
| `run_system/assets/images/ui_v2/events/option_locked.png` | 568×110 RGBA | The same strip, greyed, with a padlock at the left. |
| `run_system/assets/images/ui_v2/events/art_frame.png` | 1072×816 RGBA | A frame for the 1024×768 event illustration: a photograph pinned to a wooden board, with tape at the corners. Transparent in the 1024×768 middle. |

### I. Backgrounds and illustrations

These are larger pieces, so do them after A–H.

| File(s) | Size | What it is |
|---|---|---|
| `battle_scene/assets/images/backgrounds/wasteland_battlefield_act2_city_1920.png` | 2016×1176 RGB | Act 2 battle background, a ruined city in rust and grey. It has 48 px of extra bleed on every side, because the screen shake moves it. Compose it like `wasteland_battlefield_act1_v1.png`: a calm sky, a clear floor plane at y 650–760 (bleed included) where the characters stand, and no strong detail behind the hand area at the bottom. |
| `battle_scene/assets/images/backgrounds/wasteland_battlefield_act3_radiation_1920.png` | 2016×1176 RGB | Act 3 battle background, an irradiated zone with sickly green glow. Same rules as act 2. |
| `run_system/assets/images/events/backdrops/act_{1,2,3}.png` | 1920×1080 RGB | Replace the current files. These are very quiet flat backdrops in the enemy style: one horizon line, two or three soft shapes, and nothing in x 1100–1860 where the text column sits. |
| `run_system/assets/images/events/<event>_1024x768.png` | 1024×768 RGB | Redraw all event illustrations in the enemy style, keeping each scene's subject. The events are: `adrenaline_shot`, `buried_cache`, `caravan_checkpoint`, `collapsed_overpass`, `cursed_safe`, `deserter_charm`, `fortune_shrine`, `hooded_stranger`, `mutant_bazaar`, `rad_storm`, `stranded_trader` and `torn_coin_pouch`. Add the two second-page images, `cursed_safe_open` and `rad_storm_bunker`. That makes 14 images. Each scene is described in `assets/translations/ui_events.csv`, under `EVENT_<ID>_TITLE` and `EVENT_<ID>_PAGE_INITIAL`. |

### J. Redraw existing art in the enemy style (overwrite in place)

Each file below is in the game now but drawn in an off-style look. Redraw it in the
enemy style. Keep the same subject, the same silhouette idea and the same path, size and
format, so the game picks it up with no code change. Keep each item recognisable: a
player who knows the old icon should still recognise the new one.

| Files | Count | Size | Notes |
|---|---|---|---|
| `run_system/assets/images/relics/*.png` | 30 | 128×128 RGBA | Remove the glossy bevels, metallic gradients and shines. Draw each relic as one chunky object, like a prop held by an enemy. |
| `battle_scene/assets/images/equipment/*.png` | 15 | 256×256 RGBA | Remove the heavy metal rendering. Each piece should look as if it came off one of the roster enemies. |
| `battle_scene/assets/images/ui/equipment/*.png` | 15 | 256×256 RGBA | Empty equipment-slot ghosts. Use flat khaki silhouettes at low contrast, with a thin outline. |
| `battle_scene/assets/images/ui/status/*.png` | 19 | 64×64 RGBA | Status icons. Flat, with a 2 px outline and one accent colour each. Each must read at 32 px. |
| `battle_scene/assets/images/ui/attributes/*.png` | 5 | 64×64 RGBA | The five attribute icons, drawn in the same family as the status icons. |
| `run_system/assets/images/home/currency/*.png` | 3 | 128×128 RGBA | Currency icons. The caps icon must match `ui_v2/icons/caps.png`. |
| `run_system/assets/images/home/buildings_runtime/*.png` | 18 | Keep each file's current size | Six buildings, each with three files: normal, `_hover` and `_pressed`. Redraw the normal file. The hover and pressed files are the same drawing, with the hover a little brighter and the pressed a little darker and shifted down 2 px. These are much simpler than the current gritty versions, each with about five details. |
| `run_system/assets/images/home/buildings/*.png` | 5 | 128×128 RGBA | Small building icons matching the redrawn buildings. Leave `buildings_preview.png` alone. |
| `run_system/assets/images/shop/shopkeeper.png` | 1 | 768×1024 RGBA | The robot merchant, redrawn as a roster-style character: stocky, a big hat and poncho, one lantern, a few trinkets. It currently carries dozens of props; cut that to about five. |
| `run_system/assets/images/buildings/forge_bg.png` | 1 | 1920×1080 RGB | The forge interior, redrawn as a flat, quiet background in the act 1 style. |
| `run_system/assets/images/ui/start_screen/bottlecap_hunter_start_background_1920.png` | 1 | 1920×1080 RGBA | The main-menu saloon. Keep the composition (the robot cowboy at a poker table, a bar behind him), but use the enemy style with far fewer props. Keep x 80–760 and y 80–860 calm, because the logo and menu sit there. |

**Cards.** Most of the 51 card illustrations are already close to the anchor. Redraw only
the off-style ones below. Each is a 512×320 RGB file in
`battle_scene/assets/images/cards/player/`.

| Card file | Problem |
|---|---|
| `all_in.png` | Dark and rendered; the subject is hard to read. |
| `bone_breaker.png` | Gritty texture and too much detail. |
| `cowardice.png` | Nearly empty: a hat on the ground against a purple field. Give it a clear subject. |
| `curse_placeholder.png` | Dark painterly placeholder. Draw a proper curse card: a cracked, smoking bottle cap on a dark ground. |
| `dissect.png` | Gritty texture and too much detail. |
| `double_tap.png` | Gritty texture and too much detail. |
| `incinerate.png` | Gritty texture and too much detail. |
| `limit_break.png` | Gritty texture and too much detail. |
| `load_up.png` | Gritty texture and too much detail. |
| `preemptive_strike.png` | Gritty texture and too much detail. |
| `recoil_shot.png` | Gritty texture and too much detail. |
| `adrenaline.png` | The subject is a tiny speck in a big sky. Make the injector fill the frame. |
| `purge.png` | Shows a green alien who is not in the game, on a teal sky. Use Cowboy Bill or a roster enemy instead. |
| `weak_strike.png` | The same alien on a purple sky. Use Cowboy Bill or a roster enemy instead. |

For every card, keep the subject in the middle 70% of the frame. The card shell covers
the edges.

**Keep as they are:** all 20 enemies, all hero art, the act 1 battle background, the home
base background, the title logo, and every card not named above.

### Order of work

After the style tile is approved, deliver in this order and hand back after each group:

1. A (map) and B (shared UI kit). Their files are drop-ins, so they show up in the game at once.
2. C (battle HUD) and D (icons).
3. The relics, equipment, status, attribute and currency icons from J.
4. E (rewards), F (shop) and G (rest site), with the shopkeeper from J.
5. The cards from J.
6. H (events) and I (backgrounds), with the forge, main menu and buildings from J.

## Check before handing back

- Each file exists at the exact path, size and format listed.
- On every RGBA file, the transparent edges show no halo or matte when laid over both a
  black and a white background.
- On every nine-slice file, the corners stay intact when stretched to three times its
  size.
- Every icon stays readable when scaled down to 40 px.
- None of the images contains text.
- Every new or redrawn image looks at home next to `rust_brute_attack_0.png`. Check the outline
  weight, the two-tone fills, the absence of texture and gloss, and the palette.
- `python tools/check_missing_art.py` still reports 0 missing.
- For each section (A–J), add a contact sheet showing all of that section's files on a
  mid-grey background. Save it as `docs/art/previews/ui-v2-<section letter>.png`. Do not
  put contact sheets in the game's asset folders, because Godot would import them.
