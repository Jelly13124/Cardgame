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

9. `docs/handoffs/` — open hand-offs to other agents. Current:
   `2026-11-10-codex-art-handoff.md` (missing and outdated art for Codex).
10. `docs/superpowers/specs/` and `docs/superpowers/plans/` — the design and plan
    of each feature since the 2026-10 refactor, named by date. They record why a
    system is shaped the way it is; the code and the documents above are what is
    current.

## Generated references

`docs/catalog_html/` is generated from game JSON and translations by
`tools/gen_catalog_html.py`. Never hand-edit its HTML. Regenerate it after card,
enemy, relic, equipment, tool, event, affix, or keyword changes.

Apart from the dated specs and plans above, the documentation tree contains
current contracts only. Delivery reports, superseded ADRs and tombstone documents
are not retained, and a hand-off is deleted once its work is done.
