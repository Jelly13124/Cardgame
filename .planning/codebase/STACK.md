# STACK
This document outlines the core technology stack and dependencies for the Cardgame project.

## Core Technology
- **Engine**: Godot Engine 4.x
- **Language**: GDScript 
- **Configuration Format**: JSON
- **Environment**: Target platforms supported natively by Godot (PC, potentially Web/Mobile).

## Frameworks & Addons
- **Card-Framework Addon**: A custom reusable Godot addon (`addons/card-framework`) handling the base physics, dragging logic, hand layout, container math, and hovering animations.
  - `draggable_object.gd`: Foundation state machine for mouse interactions.
  - `card_container.gd`: Baseline for grid layouts, hands, and drop zones.

## Dependencies & Configuration
- **Card Data Configuration**: `c:\Users\Jerry\Desktop\Cardgame\battle_scene\card_info\` contains extensive JSON files organizing cards into player/enemy and units/spells.
- **Project Settings**: Managed centrally through standard `project.godot`.
- no 3rd party package managers (like npm/pip) are utilized; engine handles all dependencies locally.
