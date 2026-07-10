# Tool Confirmation and Inventory Sync Design

**Date:** 2026-07-10  
**Status:** Awaiting user review

## Goal

Make tools behave like deliberate one-use combat consumables: equipping and
unequipping must update immediately, while combat use requires an explicit
confirmation before effects resolve and the tool is consumed.

## Scope

- Fix the character-window tool slot remaining visually filled after unequip.
- Preserve direct backpack-to-tool-slot replacement and return the displaced tool
  to the incoming tool's backpack cell.
- Add a compact in-battle confirmation surface before every tool use.
- Update save slot 1 to 5,000 Caps and 5,000 Scrap for testing, without changing
  any other profile fields.

Enemy-target selection is unchanged: enemy-targeted tools continue to resolve on
the first valid enemy. Redesigning targeting is outside this change.

## Inventory State Flow

`RunManager` is the source of truth. Unequip becomes one atomic mutation:

1. Validate the equipped-tool index and find the destination backpack cell.
2. Copy the equipped tool id into that backpack cell.
3. Remove the tool from `tool_inventory`.
4. Emit `backpack_changed` and `tools_changed` only after both collections match.

The character window also subscribes to `tools_changed`. This covers tool
consumption, replacement, and any future tool-only mutation even when the
backpack does not change.

## Combat Confirmation UX

Clicking a populated top-bar tool does not immediately execute it. The battle
scene opens one centered, custom lightline confirmation overlay:

- restrained dark scrim over the battle;
- compact panel that leaves the battlefield recognizable;
- tool icon, localized name, and localized effect description;
- primary `使用` / `Use` action;
- secondary `取消` / `Cancel` action;
- Escape or clicking the dark scrim closes it without consuming the tool.

Only one confirmation may exist at a time. While it is open, pointer input to the
battle is blocked. Confirmation revalidates the tool index and tool id before
resolving, so a stale request cannot consume a different tool.

On confirmation, the existing effect pipeline runs once, then
`RunManager.consume_tool(index)` removes the consumable. Cancellation performs no
game-state mutation.

## Error Handling

- Invalid or stale tool requests close safely without consuming anything.
- Enemy-targeted tools with no valid enemy keep the existing error feedback and
  remain unconsumed.
- Repeated clicks while a confirmation is open do not stack overlays or execute
  the tool twice.
- Unequip fails without mutation when the backpack has no valid destination.

## Save Slot 1 Test Funds

Target file:
`user://slot_1/meta.json` (`CardFramework` application data directory).

Before editing, create a timestamped sibling backup. Parse the JSON, set only:

```json
{
  "caps": 5000,
  "scrap": 5000
}
```

Write valid formatted JSON back and verify all other keys retain their previous
values.

## Verification

- Regression test: unequip immediately removes the tool-slot visual and adds one
  backpack tool without requiring another drag.
- Regression test: tool replacement remains atomic.
- Combat test: opening confirmation does not consume the tool.
- Combat test: cancel leaves inventory and combat state unchanged.
- Combat test: confirm resolves once and consumes exactly one tool.
- Combat test: duplicate requests create only one confirmation.
- Existing equipment/tool, character-window, and STS2 HUD contracts pass.
- Headless smoke gate reports no script, parse, or schema errors.
- Save slot 1 backup exists; re-read profile reports 5,000 Caps and 5,000 Scrap.
