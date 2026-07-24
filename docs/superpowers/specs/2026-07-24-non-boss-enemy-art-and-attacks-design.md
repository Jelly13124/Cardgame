# Non-Boss Enemy Art and Attack Redesign

**Date:** 2026-07-24  
**Status:** Approved by owner through delegated recommendation  
**Scope:** All 17 non-boss enemy definitions and their four-frame attack sprites

## 1. Objective

Replace every non-boss enemy with an original, immediately readable character
that belongs to the same nuclear-wasteland sci-fi western as Cowboy Bill. Each
enemy must use an irreverent adult sci-fi television-cartoon visual language:
slightly wobbly dark outlines, awkward rubbery proportions, simple expressive
eyes, large flat color blocks, sparse interior lines, and minimal cel shading.

The redesign is driven by combat role, silhouette needs, and the shared world,
not by literal interpretation of the current English enemy name. Existing IDs,
combat numbers, encounter placement, and display names remain unchanged in this
pass so the art work does not silently become a balance or content migration.

Bosses are explicitly out of scope:

- `ash_warden`
- `junkyard_tyrant`
- `rust_titan`

## 2. Selected Approach

### Selected: role-first identity rebuild

All 17 non-boss enemy definitions receive distinct visual identities. Prompts
describe combat behavior, body category, silhouette, palette, and nuclear
wasteland provenance. They do not use the current display name as the creative
subject description.

Definitions that currently reuse another enemy's sprite receive their own
sprite folder and `sprite_id`:

- `chrome_warden`
- `hex_drone`
- `mortar_cart_siege`
- `riot_hound_alpha`
- `siege_breaker`

### Rejected alternatives

- **Restyle the existing bodies:** too much old silhouette and name-driven
  design would survive.
- **Reuse bodies with palette swaps:** fast, but fails encounter recognition
  and preserves the current logical art defects.
- **Rename and rebalance every enemy simultaneously:** creates unnecessary
  gameplay and localization risk. Naming can be revisited after the visual set
  is approved in-game.

## 3. Character Construction Rules

### Required

- Original simple flat 2D American-comic sci-fi western TV-cartoon art.
- Broad adult sci-fi comedy animation language without copying any existing
  character, costume, prop, location, crop, or exact design.
- Nuclear-wasteland evidence in every identity through one or two large,
  readable cues: civil-defense salvage, faded decontamination gear, reactor
  glass, cracked ceramic containment, improvised dosimeters, warning-orange
  rubber, toxic leaks, shelter hardware, or irradiated anatomy.
- Enemies face left.
- One readable silhouette and one dominant color family per identity.
- One or two small cyan, toxic-green, or warm-orange accents at most.
- Full-body sprite fits within a `256x256` transparent frame with safe margins.
- Flat fills plus at most one broad shadow per major form.
- Comedy comes from posture, expression, proportions, and malfunction—not from
  excessive props or visual noise.

### Body-category boundary

Allowed categories:

1. fully non-human alien mutant with a coherent original anatomy;
2. complete animal or wasteland creature;
3. simple salvage robot or autonomous device;
4. non-humanoid parasite, ooze, insect, plant, or energy organism.

Forbidden:

- half-human/half-animal bodies such as a human-bodied pig person;
- handsome human raiders or generic armored soldiers;
- literal image generation from the current enemy name;
- detailed mechs, realistic military armor, or polished fantasy-card monsters;
- grotesque body horror, gore, excessive limbs, or arbitrary mutations;
- painterly rendering, hatching, grunge, scratch fields, and dense panels.

## 4. Roster Identity Briefs

The internal ID is listed only for asset routing. The creative prompt must use
the role brief, not the ID or English display name.

| Enemy ID | Combat read | New identity brief | Dominant palette | Restrained attack beat |
|---|---|---|---|---|
| `acid_spitter` | light ranged damage plus burn | complete squat radiation amphibian with one translucent pressure throat and three planted feet; no clothes | plum skin, mustard belly, toxic-green throat | throat compresses; one compact glob appears only in hit frame |
| `armored_patrol` | elite guard, breakable block, debuff | autonomous fallout-shelter door robot on two short rubber treads, one broad padded faceplate, one nervous lens | faded navy, warning orange, pale cyan | body braces; faceplate bumps left once; treads stay fixed |
| `chrome_hound` | evasive animal attacker | complete four-legged nuclear desert dog with sail-like ears, narrow chest, oversized paws, and anxious comedy eyes | dusty violet, cream, cyan collar light | ears fold; one short bite; head returns |
| `chrome_warden` | reflective elite defender | tall retro decontamination booth robot with a narrow body, two offset legs, one curved reflective panel, and a tiny alarm eye | pale teal, charcoal, coral | panel angles back; one short padded-arm strike; no body charge |
| `ember_wisp` | tiny burn minion | floating reactor-moth larva with one soft heat bladder and two stubby fins; no mechanical orb body | ember orange, soot purple, cream eyes | bladder squeezes; one small flame puff in hit frame only |
| `hex_drone` | curse support and weak attack | hovering broken television parasite with two bent antennas, dangling plug-legs, and an expressive static face | bone white, petrol blue, toxic magenta accent | screen squints; one short cyan static pulse; body barely recoils |
| `mortar_cart` | telegraphed area damage and block | low complete bunker-tick creature carrying a single cracked concrete pressure sac, not a vehicle | brick red, concrete blue-grey, toxic yellow | sac compresses; one upward pressure pop; feet remain planted |
| `mortar_cart_siege` | stronger area damage and vulnerability | squat autonomous civil-defense siren on three unequal legs with a wide soft speaker mouth | mustard, faded turquoise, black rubber | siren winds back; one brief mouth pulse; legs do not step |
| `riot_hound` | weak-inflicting animal attacker | complete hairless wasteland jackal with a long neck, huge drooping ears, and toxic saliva pouch | rust red, pale peach, acid green | neck draws back; one compact snap; no leap |
| `riot_hound_alpha` | sturdier self-buffing animal | complete broad radiation hyena with low shoulders, one ceramic back ridge, and a different head mass from the jackal | indigo, bone, hot orange | ridge tightens; one short shoulder-and-jaw bump; paws stay fixed |
| `rust_brute` | heavy guard and frail punch | lanky non-animal alien salvage mechanic with a soft asymmetric head, tired uneven eyes, thin limbs, and one floppy shock glove | sickly yellow, dusty teal, orange glove | glove pulls to ribs; one short jab; elbow remains bent |
| `scrap_rat` | repeated small melee minion | complete four-legged tunnel rodent with a long soft nose, enormous rear feet, and one loose shelter tag | mauve, tan, cyan tag | nose pulls back; one tiny bite; no repeated hit pose |
| `scrap_shard` | single-hit minion | palm-sized reactor-glass mite with a squat six-point shell and two tiny feet; clearly a creature, not a floating UI icon | dark teal, cyan glass, warm orange eye | shell compresses; one short dart left; returns immediately |
| `siege_breaker` | elite telegraphed area impact | rolling decontamination drum robot with one huge soft rubber ram pad and three tiny stabilizer feet | oxblood, faded cream, toxic cyan | drum compresses; ram pad bumps once; no full-screen lunge |
| `slag_walker` | block, vulnerability, medium melee | contained alien ooze walking inside a cracked ceramic toilet-shaped survival shell; one expressive face in the ooze | lavender ceramic, dark olive ooze, cyan | ooze pulls inward; one short hose-like slap; shell stays fixed |
| `trash_robot` | basic mixed attacker and blocker | crooked retro refuse-bin robot with one off-center lens, two noodle grabbers, and one loose lid | desaturated blue, mustard, coral | lid closes for wind-up; one short grabber poke; wheels stay fixed |
| `wasteland_killer` | escalating repeated turns | complete radioactive cactus-mantis organism with a narrow body, two hook forelimbs, and large worried eyes | petrol green, dusty pink, yellow eyes | one hook draws back and makes one small slice; no trail |

## 5. Attack Animation Contract

Every standard enemy uses exactly four attack frames:

1. **Rest:** production idle image; neutral readable silhouette.
2. **Wind-up:** one local body part moves; feet, wheels, treads, or base remain
   fixed.
3. **Single hit:** exactly one bite, jab, bump, spit, pulse, poke, or slice.
4. **Recovery:** already withdrawing toward the rest pose.

Amplitude limits:

- grounded body translation: at most 6% of frame width;
- attacking hand, jaw, tool, or ram travel: normally at most 20% of body width;
- head movement: normally at most half a head width;
- no jump, charge across the frame, repeated hit, multi-swing, or second impact;
- no motion trail, dust cloud, slash arc, or impact star;
- one compact projectile or pulse is allowed only where the combat read would
  otherwise be impossible, and only in frame 3;
- all four frames share one foot/base baseline and one global scale;
- frame 4 must visually connect back to frame 1.

Runtime hit flash, shake, numbers, audio, and combat-feedback FX supply impact.
The sprite animation must not duplicate those effects.

## 6. Asset and Data Contract

For every enemy definition:

- production frames:
  `battle_scene/assets/images/enemies/{sprite_id}/attack/{sprite_id}_attack_0.png`
  through `_3.png`;
- each frame is `256x256` RGBA PNG;
- frame 0 is the static rest frame used when no attack is playing;
- source generation uses an exact `2x2` sheet on flat `#FF00FF`;
- chroma removal, frame splitting, shared scale, and baseline alignment use the
  deterministic sprite processor;
- generated sources, prompt, metadata, transparent sheet, and GIF remain under
  `tmp/imagegen/enemies/{enemy_id}/`;
- no art path is hardcoded in a scene;
- only the five currently reused definitions require `sprite_id` JSON edits;
- bosses and gameplay numbers are untouched.

## 7. Execution Batches

Work is divided into disjoint asset groups so parallel agents never edit the
same files:

- **Batch A — creatures:** `acid_spitter`, `chrome_hound`, `riot_hound`,
  `riot_hound_alpha`, `scrap_rat`
- **Batch B — machines:** `armored_patrol`, `chrome_warden`, `hex_drone`,
  `mortar_cart_siege`, `trash_robot`
- **Batch C — odd organisms:** `ember_wisp`, `mortar_cart`, `scrap_shard`,
  `slag_walker`
- **Batch D — heavy silhouettes:** `rust_brute`, `siege_breaker`,
  `wasteland_killer`

Each batch generates and normalizes one enemy at a time. A failed identity does
not block unrelated identities. Agents must not alter shared animation code,
Boss assets, balance data, translations, UI, cards, relics, or combat FX.

## 8. Validation and Acceptance

### Per enemy

- four unique frame hashes;
- `256x256` RGBA;
- transparent corners and no magenta fringe;
- no frame touches the cell edge;
- shared baseline and stable body scale;
- enemy faces left;
- frame sequence reads rest → wind-up → one hit → recovery;
- no idle/body wobble outside the intended local attack;
- runtime animation returns to frame 0 and stops;
- silhouette remains readable over
  `wasteland_battlefield_quiet_v6.png`.

### Whole roster

- 17 definitions resolve to 17 unique `sprite_id` folders;
- no duplicate frame-0 hashes;
- contact sheet shows distinct silhouette, scale, and dominant palette;
- all four-frame GIFs are reviewed at game scale;
- no boss file changes;
- `python scripts/check_missing_art.py` passes;
- Godot asset import succeeds;
- project smoke test passes.

The owner delegated subjective choices to the recommended direction for this
overnight pass. When a generated result violates a hard rule, it is rejected
and regenerated. When two compliant variants differ only subjectively, the
root agent chooses the one with clearer in-battle silhouette and stronger
separation from neighboring enemies.

## 9. Non-Goals

- Boss redesign.
- Enemy renaming or localization changes.
- Balance changes.
- New enemy behaviors or animation code.
- Idle loops, hurt animations, death animations, or elaborate VFX.
- Changes to Cowboy Bill, cards, relics, UI, backgrounds, or combat feedback.
