# Image Creation Rules

## Visual Standard
- **Art Style Only**: All images must follow the **Rick and Morty** cartoon style, but **MUST NOT** include any characters from the show (Rick, Morty, etc.).
    - Use the style's aesthetic (bold lines, colors, eyes) for YOUR original characters and machines.
    - Characteristics: Thick bold black outlines, vibrant but flat colors, expressive eyes (pupils usually dots or 'splats'), and exaggerated sci-fi proportions.
- **Composition**: Images must be **CLEAN** and contain ONLY the character or subject.
    - **NO CONTAINERS**: Do not include card frames, borders, UI elements, or laptop/phone frames.
    - **NO EXTRA LINES**: Ensure there are no background grids, measurement lines, or watermark-like artifacts.

## Subject Requirements
- **Race Consistency**: If the card description or JSON defines a specific race (e.g., Robot, Alien, Mutant), the generated art must clearly reflect that race's established tropes within the Rick and Morty universe.
- **Contextual Alignment**: The image must strictly follow the `description` field provided in the card's JSON metadata.

## File Format Standards
- **Preferred Format**: **PNG (.png)** is the project standard for all card assets. 
    - This ensures compatibility and allows for future transparency (alpha channel) support if we want to remove backgrounds.
- **Verification Procedure**: After generating an image, the assistant **MUST** verify the file signature (magic bytes). If the AI generates a JPEG or WebP but names it ".png", the assistant must correctly rename it or convert it to PNG to avoid Godot import errors.

## Prompting Guide
- **Mandatory Suffix**: Every image generation prompt MUST include: 
    `"Rick and Morty style, bold black outlines, vibrant colors, flat shading, high resolution, single subject, clean background, no text, no frames, png style transparency"`
- **Example Prompt**: `"Rick and Morty style, a robotic attack drone with glowing blue eyes and a mounted laser cannon, bold black outlines, vibrant colors, flat shading, single subject, no frames"`
