# CONCERNS
This document outlines outstanding areas requiring polish, technical debt, and bugs.

## Technical Debt
- **Resolution Scaling (Crisp Text)**: Current approach bypasses Godot's built-in theme scaling methods by manually overriding and counter-sizing labels in real-time within `unit_card.gd`.
- **Global Positioning**: Calculation of manual layout target paths (e.g. fan spreading hand logic) uses static physical math algorithms based directly upon a Node's `global_position`, which presents issues when dynamic zoom factors or non-uniform scaling variables (like `Scale(1.2, 1.2)`) intersect with internal distance multipliers.

## Bugs & Edge Cases
- **Attack States**: If mouse events slip past the intended handled capture inside `DraggableObject` and overlap with targeting operations, invalid attack states can fail to disengage, corrupting targeting arrows.
- **Animation Sync**: Tween sequences inside `CardManager` sometimes decouple from script execution logic if a player spams input too quickly before the destination tween finishes resolving `DraggableState.MOVING`.
- **Card Sizing Overlaps**: Hand visual overlaps scale inappropriately if maximum bounds exceed the intended spread limit.

## Fragile Areas
- System expects precise Node paths for legacy compatibility `has_node("FrontFace/HealthCircle")` causing significant overhead or failure if generic structural refactoring is required.
- Hardcoded string matches on keywords such as `race == "robot"` or `type == "hero"`.
