# ADR-0005: Claude owns code/JSON, Codex owns art assets

## Status
Accepted

## Date
2026-05-18

## Context
The project uses two AI collaborators alongside the human developer:
- **Claude** (this assistant) — has strong code/architecture/documentation capabilities and reasoning, weaker at producing pixel art.
- **Codex** — has strong image-generation pipelines (chroma-key cleanup, sprite sheet generation), weaker / slower at game architecture decisions.

Without explicit ownership boundaries, both ended up touching everything — Claude tried to specify exact PNG dimensions and color palettes; Codex tried to edit GDScript files. Both did each other's jobs badly.

## Decision
Strict ownership split, codified in `docs/codex-prompt-tactical-toolkit.md` Step 6 ("Don't touch") and in every new asset spec doc:

- **Claude owns:** all `.gd` files, `.tscn` files, `.json` data files, all documentation under `docs/`, all gameplay design.
- **Codex owns:** all PNG assets under `battle_scene/assets/images/` and `run_system/assets/images/`, including animation frame splits and `generated_sheet/` intermediates.
- **Contract layer:** Claude writes an `asset-spec-*.md` doc specifying exactly which PNGs Codex must produce (filename, path, dimensions, art prompt, neon accent color). Codex reads it and produces the PNGs.

Cross-boundary edits require explicit human approval.

## Alternatives Considered

### Alternative 1: Both AIs can edit anything, coordinate via git diffs
- **Pros:** Maximum flexibility. Either AI can fix whatever it sees.
- **Cons:** Codex doesn't understand GDScript semantics deeply — it would write code that parses but doesn't follow project conventions. Claude doesn't understand image-generation pipelines — it would write asset prompts missing the chroma-key step. Both produced messy results in early sessions.
- **Why rejected:** Quality dropped on both sides when boundaries blurred.

### Alternative 2: Single AI does everything
- **Pros:** No coordination overhead.
- **Cons:** Neither AI is good at both. Claude can't generate sprites at the required quality; Codex can't reason about effect dispatch architecture.
- **Why rejected:** Each tool's strength is real; ignoring it is wasteful.

### Alternative 3: Strict ownership + contract docs ← CHOSEN
- **Pros:** Each AI plays to its strength. The contract doc (`asset-spec-*.md`) makes hand-offs explicit and grep'able. Reduces cross-domain mistakes.
- **Cons:** Need to maintain the contract doc whenever asset requirements change. New asset categories require a new spec doc.
- **Why chosen:** Output quality jumped significantly once boundaries were enforced. The contract doc is also useful for future human collaborators.

## Consequences

**Positive:**
- Claude no longer writes art prompts; the asset spec doc lists exactly what's needed.
- Codex no longer edits `.gd` files; the codex prompt explicitly forbids it.
- The "Don't touch" list in every codex prompt is a clean handshake.
- Future human collaborators can read the asset spec and know what to make.

**Negative / Trade-offs:**
- Adding a new asset category (e.g. background music, particle FX) requires writing a new contract doc before Codex can deliver.
- Some decisions sit at the boundary (e.g. naming conventions, folder structure) — these are Claude's call and Codex follows, which means Codex's pipeline expertise can't surface naming improvements without going through Claude.

**Risks (and mitigations):**
- *Risk:* Codex finds the contract doc ambiguous and asks Claude — round trip. *Mitigation:* the codex prompt explicitly says "if ambiguous, stop and ask the human", not Claude.
- *Risk:* a third AI tool is added later (e.g. audio generation). *Mitigation:* same pattern — write a contract doc + ownership statement + "don't touch" list.

## Revisit Triggers
- A new AI tool joins the workflow
- One of the two AIs gains significantly stronger cross-domain capability
- The contract docs themselves become a coordination bottleneck (e.g. 5 round-trips per asset)
- A human collaborator joins and needs different boundaries

## Related
- `docs/codex-prompt-tactical-toolkit.md` (the canonical codex briefing)
- `docs/asset-spec-tactical-toolkit.md` (the contract for one content slice)
- `docs/project-rules.md` §7 prohibits Codex from committing GDScript / JSON / tscn changes
