# CONVENTIONS
This document provides style guides and internal code formatting standards.

## Code Style
- **GDScript Typing**: Variables and parameters should have static types where applicable (`func my_func(val: int) -> void:`).
- **Naming**: `snake_case` for variables, function names, and file names. `PascalCase` for classes and nodes.
- **Privacy Designators**: Use a leading underscore (`_`) for functions, variables, and signals intended to be private or internal to the class/script.

## Patterns
- **Behavior Injection via Components**: Logic such as `BattleScene` does not manage `Deck` processing internally. Instead, it instantiates a `DeckManager` class, explicitly injecting `CardFactory` and node dependencies sequentially.
- **State Machine Nodes**: UI Nodes like `DraggableObject` use named enums (`DraggableState.IDLE`, `HOVERING`, `HOLDING`, `MOVING`) transitioning strictly via explicit `change_state()` rules instead of arbitrary variable overrides.
- **Hard-Coded vs Configured**: Values are extracted from dictionary objects populated during JSON parsing (`card_info.get("attack")`).

## Error Handling
- Engine-level prints (`push_error` / `print`) used to gracefully acknowledge edge cases (e.g. attempting to attack an invalid `hovered_unit`).
- Input is explicitly overridden (`get_viewport().set_input_as_handled()`) after a critical action fires (like commencing an attack sequence) to block overlapping subsequent UI triggers.
