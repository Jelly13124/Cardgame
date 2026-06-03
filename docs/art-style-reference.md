# Art Style Reference

**Canonical style name:** Offbeat Adult Sci-Fi Cartoon Wasteland  
**Active style source:** this written style contract. Do not use old project reference images as global style references.  
**Character identity note:** `docs/art/cowboy-bill-character-sheet-reference.png` may be used only to preserve Cowboy Bill's identity markers, not as the global art style.
**Approved in-game exemplars:** `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png`, `battle_scene/assets/images/backgrounds/wasteland_battlefield.png`, `run_system/assets/images/map/wasteland_route_map_pixel_bg.png`, and the current playable card illustrations in `battle_scene/assets/images/cards/player/*.png`.

This file defines the locked art direction. The target is original adult sci-fi western cartoon game art: clean flat 2D animation shapes, thick dark outlines, strange desert sci-fi props, absurd salvage-tech silhouettes, simple cel shading, and bright toxic accent colors. The project is not pixel art and should not use gritty rendered concept-art texture.

Do not copy named show characters, logos, exact scene layouts, or franchise-specific props. The goal is an original game world with the same broad production language: graphic TV-animation clarity, weird sci-fi comedy, and readable game silhouettes.

## Core Look

- **Medium:** flat 2D TV-animation-like game art with clean black or very dark outlines, large simple shape blocks, sparse interior contour lines, and smooth cel shading.
- **Resolution policy:** asset dimensions such as 128x128, 192x192, 256x256, 512x320, or 1920x1080 are technical output sizes only. They never imply pixel art.
- **Shape language:** exaggerated sci-fi western silhouettes, rubbery props, odd alien desert forms, chunky salvage devices, crooked antennas, bulbous lenses, patched cloth, simple boots, oversized hats, awkward gadgets, and readable one-glance poses.
- **Linework:** confident dark cartoon outlines with minimal interior line clutter. Avoid sketchy concept-art hatching, comic-book crosshatching, tiny scratches, and realistic hard-surface line density.
- **Shading:** two-to-three value cel shading with broad shadow shapes. Avoid painterly rendering, photoreal lighting, gritty texture, noisy grunge, dithering, and dense material detail.
- **Materials:** simplified dusty leather, brass, dented robot metal, patched cloth, rubber hoses, glass lenses, toxic sludge, glowing sci-fi canisters, and flat alien terrain.
- **Palette:** dusty tan and warm brown base colors, muted red cloth, grey-green metal, pale desert sand, sickly toxic green, cyan plasma, warm orange glows, and off-white UI/negative space where needed.
- **Accent color:** use one or two bright high-contrast accents per asset. Toxic green, cyan, and orange are the primary glow accents.
- **Background policy:** scene backgrounds are full-scene PNGs with no UI, text, labels, or characters baked in. Sprites, card objects, icons, and FX use transparent PNGs or solid `#FF00FF` cleanup backgrounds.
- **Card illustration policy:** player card art is a `512x320` landscape illustration PNG. The image is art only: no cost badge, no title label, no rarity text, no type label, no description box, no speech bubble, and no card frame baked into the illustration.
- **UI icon policy:** UI components and combat intent icons must be as simple as possible. Prefer one clear silhouette and one main color: red sword for attack, blue shield for block, green arrow/glow for buff, orange warning mark for charge. Do not add character faces, skulls, props, texture, or extra salvage detail unless the icon's gameplay meaning requires it.

## Approved Exemplars

These files are the current production look. New art should match their flatness, line weight, color handling, and low-noise finish:

- **Cowboy Bill runtime style:** `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png`
- **Battle background style:** `battle_scene/assets/images/backgrounds/wasteland_battlefield.png`
- **Route map background style:** `run_system/assets/images/map/wasteland_route_map_pixel_bg.png`
- **Playable card illustration style:** `battle_scene/assets/images/cards/player/strike.png`, `battle_scene/assets/images/cards/player/charged_shot.png`, `battle_scene/assets/images/cards/player/deflector.png`, and the rest of `battle_scene/assets/images/cards/player/*.png`

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
- Reinterpret Bill into the active Offbeat Adult Sci-Fi Cartoon Wasteland style: flatter shapes, cleaner outlines, less rendered metal, fewer tiny scratches, and stronger animation-read poses.
- The approved Bill implementation is `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png` plus the current 8-frame `idle/` and `attack/` runtime folders.
- Combat hero frames face right.

### Enemies And Other Characters

- Enemies, NPCs, equipment, relics, cards, and UI icons must share the active flat adult sci-fi cartoon language.
- Enemies should be original junk-tech western robots, mutants, drones, creatures, or wasteland devices. They must not be direct copies of named show characters or existing franchise designs.
- Enemies face left in combat.
- Prioritize funny-gross silhouettes, bulging lenses/eyes, odd proportions, simple body masses, bright toxic accents, and clear gameplay readability.

## UI Rules

UI icons are readability tools first and illustrations second.

- Combat intent icons must stay extremely minimal and readable at 24x24 to 34x34.
- Attack intent uses a simple red sword silhouette.
- Block intent uses a simple blue shield silhouette.
- Avoid ornate frames, skull motifs, tiny bolts, dense linework, or themed props in small UI icons.
- If a UI asset becomes less readable when styled, simplify it before adding project-world detail.

## Prompt Anchor

Use this prompt anchor for generated character, enemy, relic, card, UI icon, FX, map, and battle background assets:

```text
original Offbeat Adult Sci-Fi Cartoon Wasteland game art,
matching the approved in-game exemplars in battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png, battle_scene/assets/images/backgrounds/wasteland_battlefield.png, and run_system/assets/images/map/wasteland_route_map_pixel_bg.png,
flat 2D adult sci-fi TV-animation look, thick clean dark cartoon outlines, large simple shape blocks, sparse interior lines, broad two-to-three value cel shading,
weird sci-fi western wasteland, rubbery alien desert shapes, absurd salvage-tech silhouettes, dusty leather, brass, dented grey-green robot metal, patched red cloth, hoses, antennas, odd gadgets,
bright toxic green, cyan, and warm orange glow accents used sparingly,
clean game-ready edges, readable silhouettes, low texture noise,
no text, no labels, no UI frame, no logo, no named show characters, no franchise-specific props, no exact scene copies
```

For combat unit sheets, add:

```text
side view full body, shared baseline, consistent scale, hero faces right or enemy faces left,
for Cowboy Bill and hero combat sprites use 8 idle frames plus 8 attack frames when generated,
idle is a seamless subtle loop, attack is a one-shot readable wind-up / fire / recoil / recovery sequence,
contained inside each frame with safe margins
```

For scene backgrounds, add:

```text
16:9 scene-ready game background, no characters, no UI, no text,
wide low-detail center area for gameplay readability, sparse props only at the edges,
flat smooth color fills, simple cel shadows, clean black outlines,
no pixel art, no retro tiles, no dithering, no painterly rendering, no gritty texture, no dense tiny rocks, no clutter
```

For card illustrations, keep the same style but do not force side-view/full-body if the card art is an object, weapon, or action scene. Card art must be `512x320`, landscape, production-cropped for the current Godot card art slot, and must not include card frames, cost badges, titles, labels, speech bubbles, rarity text, type text, description boxes, or UI elements.

## Avoid

- Any old visual reference image as a global style source.
- Direct copies of named characters, logos, exact show-specific designs, or franchise-specific props.
- Pixel art, retro tiles, chunky pixels, dithering, and pixelated texture clusters.
- Realistic military hard-surface rendering, photorealistic lighting, glossy concept-art mechs, and high-detail painterly surfaces.
- Dense scratches, noisy grunge, comic-book hatching, tiny repeated debris, or over-rendering that hides the clear cartoon silhouette.
- UI text baked into art, card frames baked into card art, or characters baked into battle/map backgrounds.
