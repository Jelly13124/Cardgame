# TESTING
Current test processes and CI structure validation.

## Manual Testing
- Primarily relies directly on the Godot Editor play function.
- Debug hooks are incorporated directly into persistent singletons (`RunManager`).
- For example, if running a debug build, processing specific keystrokes (`F9` state printout, `F10` gaining 100 gold resources, `F11` taking instant combat damage).

## Automated Test Limitations
- Advanced testing frameworks (e.g. GUT) are currently not configured. No test runners operate natively against component functionality outside of runtime execution visually testing the output (such as font scaling adjustments via `_crisp_text`).

## Mocks & Coverage
- Currently absent. Test logic assumes live assets are passed locally into `CardManager` directly within a running `Main` scene. Coverage metrics are not tracked by the CI pipeline for this codebase.
