# INTEGRATIONS
This document outlines external services, internal persistence systems, and API boundaries within the application.

## External Services & APIs
- Currently, **none**. The game operates entirely locally without REST APIs, cloud databases, authentication systems (OAuth), or dedicated multiplayer servers.

## Internal Data & File Systems
- **Run State**: `run_manager.gd` stores persistent state in memory during a rogue-lite "run".
- **Asset Integrations**: Basic load/import flows for PNGs (Rick and Morty style vectors) to be applied as `TextureRect` images in game. JSON parsing directly integrates flat file structures into `Dictionaries` via engine native `JSON.parse_string()`.
