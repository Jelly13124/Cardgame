# Documentation Map

Start here after cloning the repository.

## Current sources of truth

1. `AGENTS.md` — concise operational entry point.
2. `docs/project-rules.md` — non-negotiable architecture, asset, UI07, and art rules.
3. `docs/art-style-reference.md` — approved visual language and production exemplars.
4. `docs/PRD.md` — current product scope, systems, roadmap, and known debt.
5. `docs/PROJECT_STRUCTURE.md` — scene, script, data, and asset map.
6. `docs/conventions/` and `docs/adr/` — implementation contracts and decisions.
7. `docs/handoffs/2026-07-22-repository-migration.md` — exact migration state and next action.

## Generated references

`docs/catalog_html/` is generated from game JSON and translations by
`scripts/gen_catalog_html.py`. Never hand-edit its HTML. Regenerate it after card,
enemy, relic, equipment, tool, event, affix, or keyword changes.

## Historical records

Files under `docs/archive/` and dated `docs/superpowers/plans/`, reports, or old
specs document past decisions. They may contain removed card names or mechanics
and are not authoritative over current JSON, validators, tests, or the sources of
truth above. `docs/sts2-port-audit.md` is retained only as a superseded marker.
