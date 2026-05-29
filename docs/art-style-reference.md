# Art Style Reference

**Canonical style name:** Hardcore Wasteland Sprite Art
**Approved reference:** `docs/art/hardcore-128-pixel-wasteland-reference.png`, chosen by the project owner on 2026-05-19. (Filename predates the ADR-0011 rename and is kept as-is.)
**Ground truth:** `battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_portrait.png` + `heroes/cowboy_bill/attack/cowboy_bill_attack_0.png` — Cowboy Bill is the canonical character and the single source of truth for fidelity. **When this doc's wording conflicts with how Bill actually looks, Bill's sprite wins.**

![Hardcore Wasteland Sprite Art reference](art/hardcore-128-pixel-wasteland-reference.png)

This is the source of truth for visual direction. New art should look like it belongs in the same world as Cowboy Bill: a detailed, fully-rendered wasteland sprite with strong silhouettes, bold dark outlines, rusty salvaged materials, and one sparse neon accent. See ADR-0011 for why this is "Sprite Art," not pixel art.

## Core Look

- **Native resolution:** combat characters and enemies are authored at 128×128 (192×192 for bosses) unless a spec marks a larger scale. This is the in-game **display/detail budget** — NOT a lo-fi pixel-art aesthetic.
- **Medium:** a polished, fully-rendered illustrated sprite (like Cowboy Bill, the Junkyard Tyrant boss, and the `strike` card) — not flat, not chunky pixel art, not minimalist.
- **Shape language:** readable, compact, and tough. Silhouettes may be stylized, but they should feel hardcore and battle-ready rather than soft toy-like.
- **Linework:** bold dark outlines that read at gameplay size. Avoid thin realistic hairlines and avoid pure minimalist line art.
- **Shading:** rich, controlled shading with a clear highlight / mid / shadow read. Avoid flat fills and avoid noisy dithering that muddies the silhouette.
- **Materials:** rusted scrap metal, worn leather, patched cloth, bolts, dents, tubes, tape, cracked glass, oil stains, and salvaged weapon parts.
- **Palette:** warm wasteland base: leather brown, rust orange, dusty tan, muted olive, dark steel, faded brass, and desaturated charcoal.
- **Accent color:** one small high-contrast glowing accent per character or item, such as toxic green, cyan, amber, or a red sensor light.
- **Mood:** harsh, tactical, and scrapyard-hardened. The designs can stay readable and appealing, but they should not become cute mascot art.

## Character Reference Rules

### Cowboy Bill

- Robot cowboy hero.
- Exactly **one** large central camera eye. No second eye, no paired human eyes.
- Oversized battered cowboy hat, red bandana, patched duster or poncho, chunky boots, and a salvaged revolver or hand cannon.
- Faces right in combat.
- Should read as a gritty wasteland gunslinger, fully rendered with clear in-game readability.

### Trash Bot

- Small trash-collecting robot enemy.
- Compact trash-bin, compactor, or tracked junk body.
- Camera-eye face, tiny tank treads or scrap wheels, stubby grabber arms, dents, tape, bolts, and a small neon status light.
- Faces left in combat.
- Should feel like an original scrapyard enemy, not a copy of any existing robot character.

## Prompt Anchor

Use this prompt anchor for generated character, enemy, relic, card, and UI icon assets:

```text
hardcore wasteland sprite art, detailed fully-rendered game sprite, bold dark outlines, rich controlled shading with clear highlight-mid-shadow, warm rust / leather / brass / dark-steel / dusty-tan wasteland palette, salvaged scrap metal with bolts dents tubes and cracked glass, worn leather and patched cloth, one small glowing neon accent, authored at 128px native (192px bosses) for in-game readability, transparent background, match the Cowboy Bill reference fidelity, not lo-fi pixel art, not flat, not minimalist
```

For combat unit sheets, add:

```text
side view, full body, shared baseline, consistent scale, hero faces right or enemy faces left, 4 attack frames, attack frame 0 doubles as the static rest pose, no separate idle animation
```

For card illustrations, keep the same style but do not force side-view/full-body if the card art is an object, weapon, or action scene.

## Avoid

- Directly copying or imitating copyrighted characters or named IP styles.
- Clean futuristic sci-fi, glossy mechs, realistic military hardware, or hard-surface concept art.
- Flat or vector output, or cel-shaded output with no material texture.
- Lo-fi 16×16 or 32×32 sprites, or anything that throws away the detail budget.
- Dense noise or over-rendering that makes the silhouette unreadable.
- Pure minimalist line art without wasteland material texture.
- Cute mascot proportions that undermine the hardcore wasteland tone.
