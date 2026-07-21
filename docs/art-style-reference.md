# Art Style Reference

**Canonical style name:** Original 2D American-Comic Sci-Fi Western

**Active style source:** this written style contract. Do not use old project reference images as global style references.

**Character identity note:** `docs/art/cowboy-bill-character-sheet-reference.png` may be used only to preserve Cowboy Bill's identity markers, not as the global art style.
**Approved in-game exemplars:** `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png`, `battle_scene/assets/images/backgrounds/wasteland_battlefield.png`, `run_system/assets/images/map/wasteland_route_map_pixel_bg.png`, the controlled-detail card sample `battle_scene/assets/images/cards/player/strike.png`, and the persistent UI screen style anchor `docs/art/previews/base_building_forge_ui_dismantle_simple_comic_20260707.png`. Other current player card illustrations are legacy assets awaiting the same style pass and are not style references.

This file defines the locked art direction. The target is original sci-fi western game art in a Rick-and-Morty-style adult sci-fi TV-cartoon visual language: confident wobbly 2D outlines, rubbery anatomy, off-kilter proportions, funny-gross silhouettes, flat cel colors, controlled medium-low detail, and bright toxic accent colors. Use a few purposeful dents, seams, patches, crooked joints, cables, and alien marks so the world feels weird rather than sterile. Never copy franchise characters, props, locations, or exact designs. The project is not pixel art, clean corporate vector art, preschool illustration, or gritty rendered concept art.

Do not copy named characters, logos, exact scene layouts, or franchise-specific props. The goal is an original game world built around graphic American-comic clarity, offbeat sci-fi humor, western melancholy, and readable game silhouettes.

## Core Look

- **Medium:** flat 2D TV-animation-like game art with clean black or very dark outlines, large simple shape blocks, sparse interior contour lines, and smooth cel shading.
- **Resolution policy:** asset dimensions such as 128x128, 192x192, 256x256, 512x320, or 1920x1080 are technical output sizes only. They never imply pixel art.
- **Shape language:** exaggerated sci-fi western silhouettes, rubbery props, odd alien desert forms, lumpy creatures, crooked antennas, bulbous eyes/lenses, patched cloth, simple boots, oversized hats, awkward gadgets, and readable one-glance poses.
- **Linework:** confident, slightly irregular dark cartoon outlines with minimal interior line clutter. Every interior line must explain a major form; otherwise remove it. Avoid sketchy concept-art hatching, comic-book crosshatching, tiny scratches, dense panel seams, and realistic hard-surface line density.
- **Shading:** two-to-three value cel shading with broad shadow shapes. Flat fill plus one broad shadow is preferred. Avoid painterly rendering, photoreal lighting, material gradients, gritty texture, noisy grunge, dithering, and dense detail.
- **Materials:** simplified dusty leather, patched cloth, flat alien skin, brass accents, rubber hoses, glass lenses, toxic sludge, glowing sci-fi canisters, and occasional small scrap-metal props.
- **Palette:** dusty tan and warm brown base colors, muted red cloth, grey-green metal, pale desert sand, sickly toxic green, cyan plasma, warm orange glows, and off-white UI/negative space where needed.
- **Accent color:** use one or two bright high-contrast accents per asset. Toxic green, cyan, and orange are the primary glow accents.
- **Background policy:** scene backgrounds are full-scene PNGs with no UI, text, labels, or characters baked in. Sprites, card objects, icons, and FX use transparent PNGs or solid `#FF00FF` cleanup backgrounds.
- **Card illustration policy:** player card art is a `512x320` landscape illustration PNG. Each card uses one primary action, one clear subject and at most one target, with three-to-seven large flat background shapes, sparse ground/alien marks, and at most a small paired action cue such as muzzle flash plus impact star. Add a few purposeful dents, seams, patches, crooked joints, cables, or expressive eye marks; do not add texture noise. No dense rocks, dust/debris clouds, scratch fields, rivet fields, hatching, material texture, cinematic concept-art lighting, or realistic mechanical panel detail. The image is art only: no cost badge, no title label, no rarity text, no type label, no description box, no speech bubble, and no card frame baked into the illustration.
- **UI icon policy:** UI components and combat intent icons must be as simple as possible. Prefer one clear silhouette and one main color: red sword for attack, blue shield for block, green arrow/glow for buff, orange warning mark for charge. Do not add character faces, skulls, props, texture, or extra salvage detail unless the icon's gameplay meaning requires it.
- **UI screen policy:** persistent UI screens follow `docs/art/previews/base_building_forge_ui_dismantle_simple_comic_20260707.png`: simple line-art 2D American comic / TV-animation UI, lightweight borders, flat panel fills, sparse icon silhouettes, clear button hierarchy, and minimal texture. Avoid thick rendered metal frames, bulky armored corners, rivet fields, heavy bevels, dense scratches, dark fantasy ornament, and Diablo-like material rendering.

## Approved Exemplars

These files are the current production look. New art should match their flatness, line weight, color handling, and low-noise finish:

- **Cowboy Bill runtime style:** `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png`
- **Battle background style:** `battle_scene/assets/images/backgrounds/wasteland_battlefield.png`
- **Route map background style:** `run_system/assets/images/map/wasteland_route_map_pixel_bg.png`
- **Playable card illustration style:** `battle_scene/assets/images/cards/player/strike.png` is the approved controlled-detail sample. It is the midpoint: stranger and richer than clean minimal vector art, much flatter and quieter than the remaining legacy rendered card set.
- **Persistent UI screen style:** `docs/art/previews/base_building_forge_ui_dismantle_simple_comic_20260707.png`

The old Cowboy Bill character sheet is identity documentation only. It is useful for checking Bill's one orange eye, hat/star, red scarf, patched duster, boots, revolver, and gadget motifs. It must not pull new assets back toward rendered concept-sheet detail.

## Background Rules

Map and battle backgrounds must be simple, graphic, and readable behind UI.

- **No pixel art:** no chunky pixels, retro tile seams, dithered pixel shading, pixelated rock clusters, or 16-bit map language.
- **No clutter:** keep the playable/readable center low-detail. Put props at edges and corners only.
- **No gritty rendering:** avoid detailed cracks, tiny repeated stones, dense trash piles, heavy texture overlays, and realistic ruined-building detail.
- **Roads and paths:** use broad, smooth, flat-color path shapes. The current route map uses a horizontal path across the middle, not a vertical or diagonal main road.
- **Battle arena:** leave a wide empty center ground plane for combat silhouettes, card FX, and UI readability.
- **Props:** use a few weird cartoon props only: crooked pipes, simple cactus silhouettes, slime puddles, odd antennas, small sci-fi shacks, portal-green glow, and simple alien mesas.

## Character Rules

### Cowboy Bill

- Robot cowboy hero, exactly one large orange camera eye. No second eye, no paired human eyes.
- Cylindrical robot head, oversized cowboy hat with star badge, red scarf, patched duster or poncho, large boots, belt pouches, skull belt badge, and salvaged revolver.
- Preserve the identity markers from `docs/art/cowboy-bill-character-sheet-reference.png`: single orange eye, hat/star, red scarf, patched duster, chunky boots, revolver, plasma/acid/shield gadget language, and sci-fi western silhouette.
- Reinterpret Bill into the active original 2D American-comic style: flatter shapes, cleaner outlines, less rendered metal, fewer tiny scratches, and stronger animation-read poses.
- The approved Bill implementation is `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png` plus the current 8-frame `idle/` and `attack/` runtime folders.
- Combat hero frames face right.

### Enemies And Other Characters

- Enemies, NPCs, equipment, relics, cards, and UI icons must share the active flat sci-fi cartoon language.
- Enemies should read as weird sci-fi cartoon wasteland mutants, aliens, odd creatures, comedy goons, or simple salvage-tech machines. Mechanical enemies are allowed, but they must match Cowboy Bill's flat cartoon robot language: big readable shapes, thick outlines, sparse panel detail, warm brass/brown/grey materials, and one or two bright glow accents.
- Enemies face left in combat.
- Prioritize funny-gross silhouettes, bulging lenses/eyes, odd proportions, simple body masses, bright toxic accents, and clear gameplay readability.
- Avoid turning enemies into detailed mechs: no heavy rivet fields, chrome armor stacks, dense panel seams, realistic military shields, or high-detail rendered metal. If an enemy is mechanical, keep it closer to Cowboy Bill's simple toy-like salvage robot styling than realistic hard-surface armor.
- **Review gate:** enemy art direction must be approved from a single sample sheet before batching. Do not run unattended overnight enemy generation. If a generated enemy reads as a mech/armored robot instead of a weird cartoon creature or goon, reject it and regenerate before replacing runtime assets.
- **Animation amplitude:** combat attacks should be restrained by default. Keep feet planted and body movement small.
- **Enemy attack frame rule:** normal enemy attacks use **4 frames by default**: rest/wind-up, single hit, recoil, return/rest. The attack may strike exactly once. Reject sheets where the weapon, fist, bite, projectile, or hit pose repeats across multiple frames as multiple attacks. No extra sparks, slash trails, dust bursts, or detached effects unless explicitly requested.
- Bosses and elites may use more frames only when the extra frames describe one continuous attack, not repeated hits.

## UI Rules

UI icons are readability tools first and illustrations second.

- Combat intent icons must stay extremely minimal and readable at 24x24 to 34x34.
- Attack intent uses a simple red sword silhouette.
- Block intent uses a simple blue shield silhouette.
- Avoid ornate frames, skull motifs, tiny bolts, dense linework, or themed props in small UI icons.
- If a UI asset becomes less readable when styled, simplify it before adding project-world detail.
- Full UI screens and concept screens should prioritize simple line drawings, flat color blocks, light frame lines, and readable button/list rhythm. Use the forge dismantle concept anchor above as the default for future base-building screens.
- Every in-run screen uses the same persistent `run_top_bar.gd`. Scene art, panels,
  titles, cards, and interaction targets begin below its complete 132 px height.
  Scene art may continue behind the transparent relic shelf from 80 px; never
  replace the top bar with a page-specific imitation or hide/cover it for a full-screen page.
- Card previews render with no surrounding frame in their normal state. A close-fitting outline may appear only as a hover/focus/selection interaction highlight and must disappear when that state ends. Permanent decorative glows and large empty holders are prohibited.
- Do not turn UI screens into heavy rendered metal props. Keep salvage-tech flavor in small accents, silhouettes, and color choices instead of thick borders, rivet fields, bevel stacks, scratches, or dark fantasy ornament.

## Prompt Anchor

Use this prompt anchor for generated character, enemy, relic, card, UI icon, FX, map, and battle background assets:

```text
original simple flat 2D American-comic sci-fi western TV-cartoon game art,
matching the approved in-game exemplars in battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png, battle_scene/assets/images/backgrounds/wasteland_battlefield.png, and run_system/assets/images/map/wasteland_route_map_pixel_bg.png,
Rick-and-Morty-style adult sci-fi TV-animation visual language without copied designs, confident wobbly dark cartoon outlines, rubbery anatomy, off-kilter proportions, large flat shape blocks, controlled purposeful interior lines, broad two-to-three-value cel shading,
weird sci-fi western wasteland, rubbery alien desert shapes, funny-gross mutants, odd comedy goons, dusty leather, patched cloth, flat alien skin, sparse brass/scrap accents, hoses, antennas, odd gadgets,
bright toxic green, cyan, and warm orange glow accents used sparingly,
clean game-ready edges, immediately readable silhouettes, controlled medium-low detail with a few purposeful dents, seams, patches, crooked joints or cables, no corporate vector smoothness, no preschool minimalism, no texture noise, no hatching, no scratch fields, no dense mechanical panel lines,
no text, no labels, no UI frame, no logo, no copied franchise characters or props, no exact scene copies
```

For combat unit sheets, add:

```text
side view full body, shared baseline, consistent scale, hero faces right or enemy faces left,
for Cowboy Bill and hero combat sprites use 8 idle frames plus 8 attack frames when generated,
for standard enemies use 4 attack frames by default,
enemy 4-frame attack structure: rest or wind-up -> one hit -> recoil -> return/rest,
the attack must hit exactly once; no repeated strikes, no repeated hit poses, no multi-swing loops,
enemy hit feedback is runtime flash/shake only; do not generate separate hurt-frame animations,
idle is a seamless subtle loop, attack is a one-shot readable wind-up / fire / recoil / recovery sequence,
enemy attacks must stay small-amplitude unless the design explicitly calls for a boss-scale move,
feet planted and body motion restrained; weapon/hand/FX movement carries the action,
contained inside each frame with safe margins
```

For scene backgrounds, add:

```text
16:9 scene-ready game background, no characters, no UI, no text,
wide low-detail center area for gameplay readability, sparse props only at the edges,
flat smooth color fills, simple cel shadows, clean black outlines,
no pixel art, no retro tiles, no dithering, no painterly rendering, no gritty texture, no dense tiny rocks, no clutter
```

For card illustrations, keep the same style but do not force side-view/full-body if the card art is an object, weapon, or action scene. Use one primary action, one subject and at most one target; use three-to-seven broad background shapes, sparse alien marks, and only small action FX. Add a few purposeful dents, seams, patches, crooked joints, cables, or expressive eye details. Card art must be `512x320`, landscape, production-cropped for the current Godot card art slot, and must not include dense debris, hatching, scratch fields, realistic panel detail, card frames, cost badges, titles, labels, speech bubbles, rarity text, type text, description boxes, or UI elements.

## Avoid

- Any old visual reference image as a global style source.
- Direct copies of named characters, logos, exact show-specific designs, or franchise-specific props.
- Pixel art, retro tiles, chunky pixels, dithering, and pixelated texture clusters.
- Realistic military hard-surface rendering, photorealistic lighting, glossy concept-art mechs, dense robot armor, and high-detail painterly surfaces.
- Dense scratches, noisy grunge, comic-book hatching, tiny repeated debris, or over-rendering that hides the clear cartoon silhouette.
- UI text baked into art, card frames baked into card art, or characters baked into battle/map backgrounds.
