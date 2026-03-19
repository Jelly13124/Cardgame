# Overview
This project is a fast-paced, sci-fi rogue-lite card battler set in a "Rick and Morty" inspired universe. Players navigate a series of increasingly difficult encounters across multiple floors, building a powerful deck of units and spells. Unlike traditional card games, this product emphasizes tactical positioning on a grid-based battlefield and meta-progression where players use salvaged "Core" parts to build their permanent base once a "Run" ends.

# Core Features

### 1. Grid-Based Tactical Combat
*   **What it does**: Units are deployed into specific "Battle Rows" (lanes) where they engage in reciprocal combat.
*   **Why it's important**: Adds a layer of strategy beyond just "playing the best card"; players must decide where to protect their Hero and which lanes to sacrifice.
*   **How it works**: Cards have `attack` and `health` stats; if no unit blocks an enemy, damage is routed directly to the Hero unit.

### 2. Rogue-lite "Run" Progression
*   **What it does**: Tracks health, gold, and "Core" resources across multiple floors in a single life cycle.
*   **Why it's important**: Creates the "one more turn" gameplay loop common in the genre.
*   **How it works**: The `RunManager` handles state persistence during a run. Death resets deck progress but triggers the "Base-Building" recovery logic.

### 3. Rick and Morty Aesthetic (Vibe Match)
*   **What it does**: Enforces a strict art style of flat 2D cartoons, wacky sci-fi names (e.g., "Robot Leader"), and vibrant, high-contrast colors.
*   **Why it's important**: Differentiates the product from generic fantasy card games and targets a specific fan demographic.
*   **How it works**: Global project rules dictate thick outlines, vector-style textures, and crazy sci-fi JSON item definitions.

### 4. High-Definition "Crisp Text" Inspection
*   **What it does**: Allows users to right-click any card to see a high-resolution, sharp information view.
*   **Why it's important**: Solves the common Godot issue of blurry fonts when scaling 2D nodes.
*   **How it works**: Recursively counter-scales the UI via a custom `_crisp_text` function, rendering fonts at 2.5x native size for pixel-perfect clarity.

# User Experience

### User Personas
*   **The Strategist**: Enjoys the math of reciprocal combat and optimizing deck synergies.
*   **The Casual Fan**: Drawn in by the Rick and Morty art style and silly unit descriptions.
*   **The Completionist**: Motivated by the meta-progression and unlocking all base-building structures.

### Key User Flows
*   **Main Menu** -> **Hero Select** -> **Battle Start** -> **Row Deployment** -> **Victory/Defeat** -> **Base Upgrade**.

### UI/UX Considerations
*   **Tactile Interaction**: Drag-and-drop cards must feel weighty; targeting arrows provide immediate feedback on where damage will land.
*   **Visual Hierarchy**: Health and Attack are kept at the card edges for immediate readability at a glance during chaotic board states.

# Technical Architecture

### System Components
*   **Card Framework (Addon)**: Handles the heavy lifting of physics-based dragging, hand fanning, and slot containers.
*   **Run Manager (Singleton)**: The source of truth for gold, health, and permanent deck modifications.
*   **Battle Scene**: Orchestrates round logic, energy management, and enemy AI phases.

### Data Models
*   **Card JSONs**: Flat data files containing name, cost, type (unit/spell/hero), and description.
*   **Keyword Scripts**: Modular GDScripts (Taunt, Shield) that can be attached to any unit.

# Development Roadmap

### Phase 1: Core Combat & UI (Current)
*   **Scope**: Finalize the Hero death condition, reciprocal combat math, and "Crisp Text" quality. Implement basic unit variety (Drones, Robot Leaders).

### Phase 2: Run & Progression
*   **Scope**: Implement the "Floor" transition system. Add rewards after combat (drafting new cards). Hook up the Gold/Core resource gain logic.

### Phase 3: Base-Building & Meta-Progression
*   **Scope**: Create the persistent "Hub" scene. Implement the retention logic where a percentage of "Core" resources are kept after death to build stat-boosting structures.

# Logical Dependency Chain
1.  **Battle Engine Foundation**: (Complete) Moving, attacking, and dying.
2.  **Hero Integration**: (Complete) Removing the Mothership and centering gameplay on Hero survival.
3.  **Deck & Run Persistence**: (Active) Drafting cards and tracking health between matches.
4.  **Meta-Game Loop**: (Next) The Hub/Base scene that utilizes salvaged resources.

# Risks and Mitigations
*   **Risk**: Complex font scaling causing layout issues.
    *   *Mitigation*: Use the `_crisp_text` deferred size system to lock UI boundaries.
*   **Risk**: Card game balance with rogue-lite random rewards.
    *   *Mitigation*: Data-driven JSON approach allows for quick balancing without recompiling the project.

# Appendix
*   **Asset Paths**: Card art is stored in `battle_scene/assets/images/cards/`.
*   **Keywords**: Supports `Battlecry`, `Deathrattle`, `Taunt`, `Shield`, `One-Time`.
