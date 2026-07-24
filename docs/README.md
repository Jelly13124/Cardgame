# Documentation Map

Start here after cloning the repository.

## Current sources of truth

1. `AGENTS.md` — concise operational entry point.
2. `docs/project-rules.md` — non-negotiable architecture, asset, UI07, and art rules.
3. `docs/art-style-reference.md` — approved visual language and production exemplars.
4. `docs/enemy-art-direction.md` — current non-boss enemy silhouette, palette, and attack-motion direction.
5. `docs/art/external-references/rick-morty-s3e2-wasteland/README.md` — approved external study board and non-copying rules.
6. `docs/PRD.md` — current product scope, systems, roadmap, and known debt.
7. `docs/PROJECT_STRUCTURE.md` — scene, script, data, and asset map.
8. `docs/conventions/` — implementation contracts and coding conventions.

9. `docs/handoffs/2026-07-24-workstation-transfer.md` is the active transfer
   checkpoint for cloning this branch onto the replacement computer.

## Generated references

`docs/catalog_html/` is generated from game JSON and translations by
`scripts/gen_catalog_html.py`. Never hand-edit its HTML. Regenerate it after card,
enemy, relic, equipment, tool, event, affix, or keyword changes.

The documentation tree intentionally contains current contracts only. Historical
plans, delivery reports, superseded ADRs, and tombstone documents are not retained.
The workstation-transfer handoff above is the only active handoff and may be
deleted after the replacement computer has cloned, verified, and resumed the
project.
