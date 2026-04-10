---
name: gen-card-art
description: Generate high-quality wasteland pixel art illustrations for cards using Nano. Standardizes JPG format and directory paths.
---

# Generate Card Art

## Overview
Generate beautiful, gritty, 16-bit wasteland pixel art illustrations for card fronts using **Nano Generate**. This skill ensures that all card illustrations remain consistent in style and format.

## Standard Requirements
- **Style**: Gritty Wasteland Punk / Cyberpunk Junk / 16-bit Pixel Art.
- **Tool**: `generate_image` (Nano).
- **Format**: **JPG** (Mandatory for card illustrations).
- **Resolution**: 1024x1024 (scaled down in-game) or 512x512.

---

## Workflow

### Step 1 — Generate the Image
Use the `generate_image` tool with the following prompt template:

**Prompt Structure:**
> "Pixel art illustration for a card game, vibrant 16-bit style. [DETAILED DESCRIPTION OF OBJECT/WEAPON/SCENE]. Post-apocalyptic wasteland junk art style. Gritty textures, detailed pixel work. Cinematic wasteland punk lighting."

### Step 2 — Handle Format Conversion
`generate_image` often outputs `.png`. You **MUST** convert or rename the file to `.jpg` for the project's card illustration standard.

Use the helper script:
```powershell
python "c:\Users\Jerry\Desktop\Cardgame\skills\gen-card-art\scripts\convert_to_jpg.py" --input "path/to/generated.png" --name "card_id_here"
```

### Step 3 — Placement
Move the resulting `.jpg` to the correct project directory:
- **Player Cards**: `battle_scene/assets/images/cards/player/`
- **Enemy Cards**: `battle_scene/assets/images/cards/enemy/`

### Step 4 — Update JSON
Update the card's JSON file to reference the new image:
```json
"front_image": "player/my_card_id.jpg"
```

---

## Technical Rules
1. **No PNGs for Card Art**: High-color illustrations are always JPG to distinguish from transparent characters.
2. **Backgrounds**: Card art should have an atmospheric wasteland background, not transparency.
3. **Naming**: Use lowercase underscores (e.g., `plasma_lance.jpg`).
