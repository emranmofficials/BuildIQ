# Master Roadmap

Sequence is fixed by dependency. A phase is not called complete until its validation tasks pass.

| Phase | Name | Outcome | Gate |
|---|---|---|---|
| 0 | Audit & Planning | Evidence-based audit, ADRs, DB/engine/floor-plan/AI/testing designs, task board | Documents written and reviewed |
| 1 | Foundation | Flutter + pure-Dart engine scaffold, DI, navigation, theme, en/bn l10n, local DB, error/logging, connectivity | `flutter analyze` clean on scaffold; DB init test; startup smoke test |
| 2 | Core Offline Calculator | Tokenizer/parser/evaluator, basic + scientific calculator, memory, history | Parser and calculator unit tests pass; divide-by-zero and invalid input handled |
| 3 | Unit Conversion | Length/area/volume/mass/construction units, regional land presets, quick conversion, precision | Conversion factor tests incl. round trips and regional presets |
| 4 | Construction Engines | Concrete, brick/masonry, steel/rebar, finishing (plaster/putty/primer/paint/tile/skirting/waterproofing/ceiling) | Golden-value tests with waste and cost; no formulas in UI |
| 5 | Floor Plan Intelligence | Building/floor/room/wall/opening model, shared-wall registry, 2D editor, undo/redo, geometry & takeoff | Automated shared-wall non-duplication tests pass |
| 6 | Projects & BOQ | Multiple projects, client/budget/status, materials, expenses, BOQ lines, progress | Offline CRUD + persistence tests |
| 7 | Reports | Report model, PDF, Excel/CSV, print/share, assumptions & warnings | Generated artifacts contain real values and formulas |
| 8 | AI System | Modular provider, Bangla/English assistant, drawing analysis, status/confidence, validation | Failure/timeout/invalid-response tests; no secrets in source |
| 9 | Cloud & Sync (optional) | Backup, sync queue, retry, conflict surfacing, state honesty | Pending changes survive failure; no false `synced` state |
| 10 | Hardening & Release Prep | Full analyze/format/test pass, docs, known limitations | All DONE criteria or explicitly disclosed gaps |

## Execution policy
- Highest-priority unblocked task first.
- A task moves to `DONE` only with implementation + validation + tests passing + no critical issue.
- `CODE_COMPLETE` means code written but not yet validated.
- If a task is blocked, document cause and continue with the next unblocked task.

## Current position
Phase 0 complete (2026-11-23). Starting Phase 1 foundation after documenting the design.
