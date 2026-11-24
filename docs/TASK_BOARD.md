# Task Board

Authoritative status register. Last updated: 2026-11-23 (Phase 1 implementation + validation).

Statuses: BACKLOG · TODO · IN_PROGRESS · BLOCKED · CODE_COMPLETE · TESTING · FAILED · DONE
A task is DONE only when implementation, validation, tests and acceptance criteria all pass.
CODE_COMPLETE means code exists and the analyzer is clean but the task's named test gate has not yet been satisfied.

## Phase 0 — Audit & Planning

| ID | Title | Pri | Status | Dependencies | Testing | Notes / Blockers |
|---|---|---|---|---|---|---|
| T-001 | Inspect workspace, env, git, deps, prior work | P0 | DONE | — | Evidence recorded | Flutter found inside Ubuntu proot (3.50.1 / Dart 3.14.0) |
| T-002 | Architecture proposal + ADRs | P0 | DONE | T-001 | Reviewed | `ARCHITECTURE.md`, 6 ADRs in audit |
| T-003 | Database schema design | P0 | DONE | T-001 | Reviewed | `DATABASE_SCHEMA.md` |
| T-004 | Construction calculation engine spec | P0 | DONE | T-002 | Reviewed | `CALCULATION_ENGINE.md` |
| T-005 | Floor plan + shared-wall engine spec | P0 | DONE | T-002 | Reviewed | `FLOOR_PLAN_ENGINE.md` |
| T-006 | Offline-first strategy | P0 | DONE | T-002 | Reviewed | `OFFLINE_FIRST.md` |
| T-007 | AI architecture & safety rules | P0 | DONE | T-002 | Reviewed | `AI_SYSTEM.md` |
| T-008 | Testing strategy + task board + docs | P0 | DONE | T-001..T-007 | Reviewed | `TESTING_STRATEGY.md`, this file |

## Phase 1 — Foundation

| ID | Title | Pri | Status | Dependencies | Testing | Notes / Blockers |
|---|---|---|---|---|---|---|
| T-010 | Flutter app scaffold + pubspec + engine package | P0 | DONE | T-008 | flutter analyze | Scaffold + pure-Dart `engine/` created; `flutter analyze` → 0 issues |
| T-011 | Core types: Quantity, Money, breakdown, validation | P0 | DONE | T-010 | dart test | `result.dart`, `quantity.dart`; engine suite 63/63 |
| T-012 | Local DB schema, migrations, repository interfaces | P0 | CODE_COMPLETE | T-010, T-003 | dart test (in-memory) | `app_database.dart` + engine repository; in-memory CRUD tested. sqflite-on-Flutter test still pending (no ffi test dep) |
| T-013 | Theme, navigation, service locator | P1 | DONE | T-010 | widget smoke test | `theme.dart`, `app_shell.dart`, MultiProvider; widget test passes |
| T-014 | Bengali + English localization | P0 | DONE | T-010 | l10n test | `l10n.dart`; 2 localization tests pass (bn/en + fallback) |
| T-015 | Error handling, logging, connectivity states | P1 | DONE | T-010 | unit test | `logger.dart`, `connectivity.dart`; `test/connectivity_test.dart` passes |
| T-016 | Foundation validation (analyze + tests) | P0 | IN_PROGRESS | T-010..T-015 | full gate | Analyze clean + tests green; waiting on sqflite DB test (T-012) |

## Phase 2 — Core Offline Calculator

| ID | Title | Pri | Status | Dependencies | Testing | Notes / Blockers |
|---|---|---|---|---|---|---|
| T-020 | Expression tokenizer + shunting-yard parser | P0 | DONE | T-011 | unit tests | Engine parser tests pass (parentheses, unary minus, functions) |
| T-021 | Evaluator: + − × ÷ %, √, power, trig, log | P0 | DONE | T-020 | unit tests | Engine evaluator tests pass; divide-by-zero is an error result |
| T-022 | Basic + scientific calculator UI, memory, history | P1 | CODE_COMPLETE | T-021, T-012, T-014 | widget test | `calculator_page.dart` built; dedicated widget interaction test pending |
| T-023 | Calculator validation | P0 | CODE_COMPLETE | T-020..T-022 | gate | Analyze clean + engine tests pass; calculator widget test pending |

## Phase 3 — Unit Conversion

| ID | Title | Pri | Status | Dependencies | Testing | Notes / Blockers |
|---|---|---|---|---|---|---|
| T-030 | Unit registry + length/area/volume/mass factors | P0 | DONE | T-011 | round-trip tests | Engine unit tests pass |
| T-031 | Construction units + regional land units | P0 | DONE | T-030 | golden tests | Katha/Bigha/Shotok presets; engine tests pass |
| T-032 | Converter UI + precision setting | P1 | CODE_COMPLETE | T-030, T-014 | widget test | Converter tab + precision slider built; widget test pending |
| T-033 | Converter validation | P0 | CODE_COMPLETE | T-030..T-032 | gate | Analyze clean + engine tests pass; converter widget test pending |

## Phase 4 — Construction Engines

| ID | Title | Pri | Status | Dependencies | Testing | Notes / Blockers |
|---|---|---|---|---|---|---|
| T-040 | Concrete engine (PCC/RCC elements, dry volume, materials, water, waste, cost) | P0 | DONE | T-011, T-030 | golden tests | `concrete.dart` + tests pass |
| T-041 | Brick & masonry engine | P0 | DONE | T-040 | golden tests | `masonry.dart` + tests pass |
| T-042 | Steel & rebar engine | P0 | DONE | T-011 | golden tests | `steel.dart` + tests pass |
| T-043 | Finishing engine (plaster, putty, primer, paint, tile, skirting, waterproofing, ceiling) | P1 | DONE | T-011, T-030 | golden tests | `finishing.dart` + tests pass (implemented surfaces) |
| T-044 | Calculator hub UI: inputs, breakdown, save, report | P1 | CODE_COMPLETE | T-021..T-043, T-012 | widget test | `construction_page.dart` built; no formulas in widgets; widget test pending |
| T-045 | Construction engine validation | P0 | CODE_COMPLETE | T-040..T-044 | gate | Analyze clean + 63 engine tests pass; hub widget test pending |

## Phase 5 — Floor Plan Intelligence

| ID | Title | Pri | Status | Dependencies | Testing | Notes / Blockers |
|---|---|---|---|---|---|---|
| T-050 | Building/floor/room/wall/opening domain model | P0 | DONE | T-011 | unit tests | Engine floorplan models + JSON round-trip tests pass (`serialization_test.dart`) |
| T-051 | Shared-wall registry + duplicate prevention + takeoff | P0 | DONE | T-050 | dedicated tests | `shared_wall_test.dart` passes; dedup by wall ID verified |
| T-052 | Openings linked to walls; door/window types | P0 | DONE | T-050, T-051 | unit tests | `Opening.wallId` linkage tested |
| T-053 | Geometry validation, area/volume, estimation from floor plan | P0 | DONE | T-051, T-052 | unit tests | Takeoff + orphan-wall warnings tested |
| T-054 | 2D editor: grid/snap/select/move/resize/rotate/delete/duplicate/undo/redo/zoom/pan/labels | P1 | CODE_COMPLETE | T-050..T-053 | widget tests | `floorplan_page.dart`: canvas, select, add room/wall, openings, undo/redo, SQLite save/load. Rotate/duplicate/pan + widget tests pending |
| T-055 | Floor plan validation | P0 | CODE_COMPLETE | T-050..T-054 | gate | Analyze clean + shared-wall tests pass; editor widget test pending |

## Phase 6 — Projects & BOQ

| ID | Title | Pri | Status | Dependencies | Testing | Notes / Blockers |
|---|---|---|---|---|---|---|
| T-060 | Projects, buildings, floors, materials, expenses CRUD offline | P0 | CODE_COMPLETE | T-012 | DB tests | Projects CRUD + floor-plan save/load via `AppState` + SQLite; DB-level test pending |
| T-061 | BOQ generator from calculations + floor plan takeoff | P0 | DONE | T-040..T-053 | unit tests | `boq_sync_test.dart` passes (traceable lines + totals) |
| T-062 | Cost rollup, budget vs actual, progress | P1 | TODO | T-060, T-061 | unit tests | Not implemented yet |
| T-063 | Project validation | P0 | TODO | T-060..T-062 | gate | Not implemented yet |

## Phase 7 — Reports

| ID | Title | Pri | Status | Dependencies | Testing | Notes / Blockers |
|---|---|---|---|---|---|---|
| T-070 | Report model + CSV export | P0 | CODE_COMPLETE | T-061 | golden text tests | `report_service.dart` CSV export implemented; golden test pending |
| T-071 | PDF report with formulas/breakdown/assumptions | P1 | CODE_COMPLETE | T-070 | artifact test | PDF export implemented; artifact test pending |
| T-072 | Excel (.xlsx) export | P1 | CODE_COMPLETE | T-070 | artifact test | Real .xlsx via `excel`; artifact test pending |
| T-073 | Print/share flows | P2 | TODO | T-071, T-072 | widget test | Not implemented yet |

## Phase 8 — AI

| ID | Title | Pri | Status | Dependencies | Testing | Notes / Blockers |
|---|---|---|---|---|---|---|
| T-080 | Modular AI provider interface + user-configured endpoint | P0 | CODE_COMPLETE | T-011 | mock tests | No-op + OpenAI-compatible provider; no hard-coded secrets; mock tests pending |
| T-081 | Bangla/English assistant with step explanations + warnings | P1 | CODE_COMPLETE | T-080 | response validation tests | `ai_page.dart` + safety warning; response validation tests pending |
| T-082 | Drawing analysis (JPG/JPEG/PNG/PDF) → draft floor plan | P1 | TODO | T-080, T-050 | mock/uncertainty tests | Not implemented yet |
| T-083 | AI status UI (AI_DETECTED/ESTIMATED/UNCERTAIN/USER_VERIFIED/USER_EDITED) | P0 | TODO | T-082 | widget test | Engine enum exists; status display not wired into UI yet |
| T-084 | AI validation gate | P0 | TODO | T-080..T-083 | gate | Not implemented yet |

## Phase 9 — Cloud & Sync (optional module)

| ID | Title | Pri | Status | Dependencies | Testing | Notes / Blockers |
|---|---|---|---|---|---|---|
| T-090 | Sync state model + append-only pending queue | P0 | DONE | T-012 | unit tests | `boq_sync_test.dart`: only acknowledgement removes pending data |
| T-091 | Local backup/restore | P0 | TODO | T-012 | DB tests | Not implemented yet |
| T-092 | Cloud adapter, retry, conflicts, user decisions | P1 | CODE_COMPLETE | T-090 | failure tests | `sync_service.dart` with endpoint config + retry; failure tests pending |
| T-093 | Sync validation | P0 | TODO | T-090..T-092 | gate | Not implemented yet |

## Phase 10 — Hardening

| ID | Title | Pri | Status | Dependencies | Testing | Notes / Blockers |
|---|---|---|---|---|---|---|
| T-100 | Format + analyze + full test suite | P0 | IN_PROGRESS | all prior | full gate | `dart format` applied; `flutter analyze` 0 issues; engine 65/65 + Flutter 6/6 tests pass. Debug APK blocked by a proot/Dart thread limit during Gradle; retry in progress (K-13) |
| T-101 | Final docs, known limitations, release readiness review | P0 | TODO | T-100 | review | No publishing without owner approval |

## Metrics (derived from this board)
- Total tasks: 54
- DONE: 27 · CODE_COMPLETE: 16 · IN_PROGRESS: 2 · TODO: 9 · BLOCKED: 0 · FAILED: 0
- Overall progress (DONE): 27 / 54 = 50%
- Validation evidence: `flutter analyze` → No issues found; engine `dart test` → 65/65 passed; `flutter test` → 6/6 passed (localization, theme, connectivity, smoke)
