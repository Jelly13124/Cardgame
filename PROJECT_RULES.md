# Project Rules & Guidelines

## 1. Project Structure
- **Maintain a Clear Directory Hierarchy:** Keep assets, scripts, scenes, and configurations separated into their respective domains (e.g., `assets/images/cards/player/units/`, `card_info/`, etc.).
- **Consistent Naming Conventions:** Use snake_case for files and folders. Keep names descriptive and modular.

## 2. Code Architecture
- **Extendable Code:** Write code with scalability in mind. Base classes (e.g., `Card`, `CardContainer`) should be designed so that new unit types, spells, or abilities can easily inherit and extend functionality without hardcoding.
- **Data-Driven Design:** Rely on JSON configuration files (`card_info/`) for unit stats, descriptions, and abilities rather than hardcoding values into GDScript.

## 3. Art Direction
- **Rick and Morty Style:** All visual assets, UI elements, and character designs must strictly adhere to the "Rick and Morty" art style. This includes 2D flat cartoon animation aesthetics, wacky sci-fi concepts, thick outlines, and vibrant colors.
