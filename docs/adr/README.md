# Architecture Decision Records

This folder holds **ADRs** — short documents that capture each significant technical or design decision, including the alternatives we considered and why we picked what we picked.

## Why this exists

Code shows the *current* state. Git log shows *what changed*. Neither tells you **why we picked this approach over the obvious alternative**. ADRs do.

When you (or a collaborator, or Codex) look at e.g. `RunManager` being an autoload and wonder "should this be DI instead?" — read `0001-runmanager-autoload.md` first. If the trade-offs there still hold, leave it alone. If conditions changed, write a NEW ADR that supersedes it.

## Rules

1. **One file per decision.** Numbered sequentially: `NNNN-short-kebab-title.md`.
2. **Never modify accepted ADRs.** If the decision changes, write a new ADR with `Status: Supersedes ADR-NNNN`. The old one stays as a historical record of what we believed then.
3. **Use `0000-template.md`** as the starting structure. Trim sections that don't apply rather than leaving them empty.
4. **Keep it short.** 100-300 lines. Most of the value is in **Context** + **Alternatives Considered** + **Consequences**.
5. **Status starts at `Accepted`** for decisions already in the codebase. Use `Proposed` only if you're discussing before implementing.

## Index

| # | Title | Status |
|---|---|---|
| [0000](0000-template.md) | (Template — copy this, do not edit) | — |
| [0001](0001-runmanager-autoload.md) | RunManager as autoload singleton | Accepted |
| [0002](0002-card-data-as-dictionary.md) | card_info as Dictionary, not typed Resource | Accepted |
| [0003](0003-sprite-folder-structure.md) | Sprites split into per-animation subfolders | Accepted |
| [0004](0004-shock-enemy-only.md) | Shock status only applies to enemies | Accepted |
| [0005](0005-claude-codex-ownership-split.md) | Claude owns code/JSON, Codex owns art | Accepted |
| [0006](0006-class-name-via-preload.md) | Reference custom classes via `const X = preload(...)`, not `class_name` global | Accepted |
| [0007](0007-art-pivot-to-cute-wasteland-cartoon.md) | Art direction pivot: Pixel Punk → Cute Wasteland Cartoon | Superseded by ADR-0008 |
| [0008](0008-art-pivot-to-hardcore-128-pixel-wasteland.md) | Art direction pivot: Cute Wasteland Cartoon -> Hardcore 128 Pixel Wasteland Art | Superseded by ADR-0012 |
| [0009](0009-remove-idle-animation-assets.md) | Remove separate idle animation assets | Accepted |
| [0010](0010-third-palette-recalibration.md) | Third palette recalibration via script-sampling; theme renamed to `wasteland_theme.gd` (no style suffix) | Accepted (style name clarified by ADR-0011) |
| [0011](0011-art-style-rename-to-rendered-sprite.md) | Art style renamed to "Hardcore Wasteland Sprite Art"; pixel-art wording corrected to detailed rendered sprites | Superseded by ADR-0012 |
| [0012](0012-art-pivot-to-offbeat-sci-fi-cartoon-wasteland.md) | Art direction pivot to Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland | Reference choice superseded by ADR-0013 |
| [0013](0013-art-reference-standard-radiation-rat.md) | Art reference standard: radiation rat | Superseded by ADR-0015 |
| [0014](0014-cowboy-bill-character-sheet-reference.md) | Cowboy Bill character sheet is the primary Bill reference | Superseded by ADR-0015 |
| [0015](0015-single-cowboy-bill-reference.md) | Single art reference: Cowboy Bill character sheet | Superseded by ADR-0016 |
| [0016](0016-art-pivot-to-offbeat-adult-sci-fi-cartoon.md) | Art direction pivot to Offbeat Adult Sci-Fi Cartoon Wasteland | Superseded by ADR-0017 |
| [0017](0017-formal-art-style-lock-offbeat-adult-sci-fi-cartoon.md) | Formal art style lock: Offbeat Adult Sci-Fi Cartoon Wasteland | Accepted |
