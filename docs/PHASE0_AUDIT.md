# Phase 0 — Project Audit Report

Date: 2026-11-23
Auditor: Autonomous Flutter Engineering Agent
Status: COMPLETED

## 1. Workspace inspection

Workspace root: `/data/user/0/ai.antigem/files/home/projects`

Existing entries (inspected, not modified):

| Entry | Type | Relevance |
|---|---|---|
| `README.md` | Workspace note | Confirms this is the app's file workspace |
| `android-code-studio/`, `acs-antigem-merge/` | AndroidIDE/Kotlin source trees | Not a Flutter app; unrelated to this product |
| `antigem/`, `antigem-studio/`, `hermes_mobile/`, `zara/`, `ZaRa/`, `mosque_seba/` | Existing apps (Dart/Flutter where present) | Unrelated products. Inspected only to confirm no existing AI Construction Calculator code exists |
| `Maya_*.md`, `Maya_UI_kathon.md`, `zara_scaffold.py` | Analysis/design documents | Unrelated product research |

`pubspec.yaml` search found Flutter apps only in `zara/`, `hermes_mobile/`, `mosque_seba/`. None contains construction-calculation code, BOQ, floor-plan engines, or Bengali construction terminology. **Conclusion: this is a greenfield project.** No existing implementation to preserve beyond the workspace itself.

A past chat about "Project Khata" (construction site attendance/payroll PRD, Supabase/FCM) exists in agent memory but is a **different product** and is explicitly out of scope.

## 2. Environment inspection

| Check | Result |
|---|---|
| OS/platform | Android (AntiGem built-in Linux, Termux packages), `aarch64` |
| `flutter` on Termux PATH | Not on PATH, but **available inside the installed Ubuntu proot** at `/root/tools/flutter/bin/flutter` |
| `dart` on Termux PATH | Not on PATH; a standalone arm64 Dart SDK was downloaded to `~/tools/dart-sdk` but needs glibc, so the proot SDK is used instead |
| Flutter/Dart version (proot) | **Flutter 3.50.1 stable, Dart 3.14.0, linux_arm64** — verified with `flutter --version` |
| Workspace visibility in proot | Confirmed: `/data/user/0/ai.antigem/files/home/projects` is visible inside Ubuntu proot |
| `git` | Available (`2.56.1`) |
| `node`, `python`, `clang`, `git` | Available |
| Network | Available (pub.dev and Google Cloud Storage reachable) |
| Free storage | ~115 GB |
| Flutter plugin configs under `~/.gemini` / `~/.config/flutter` | IDE plugin metadata only; **no SDK binaries** |
| Official Flutter arm64 Linux archive | Not needed; SDK already present in proot |

### Environment conclusion (corrected after deeper inspection)
The initial PATH check was misleading: Flutter **is** available inside the pre-installed Ubuntu proot container. `flutter analyze`, `flutter test` and Flutter builds can be executed by prefixing commands with `proot-distro login ubuntu -- bash -lc '...'`. The suspected hard blocker is therefore **resolved**.

The standalone pure-Dart `engine/` package is still retained as an architectural decision (ADR-001): it makes the entire deterministic domain layer independently testable and keeps formulas out of widgets.

## 3. Requirements coverage matrix

| Requirement area | Planned location | Phase | Current status |
|---|---|---|---|
| Basic/scientific calculator, history | `engine/lib/src/calculator`, `lib/features/calculator` | 2 | BACKLOG |
| Unit conversion incl. regional land units | `engine/lib/src/units` | 3 | BACKLOG |
| Central calculation engine (concrete, brick, steel, finishing) | `engine/lib/src/calculators` | 4 | BACKLOG |
| Floor plan + shared wall engine | `engine/lib/src/floorplan` | 5 | BACKLOG |
| 2D floor plan editor | `lib/features/floorplan` | 5 | BACKLOG |
| Projects, materials, BOQ, cost | `engine/lib/src/project`, `lib/features/projects` | 6 | BACKLOG |
| PDF/Excel/CSV reports | `lib/features/reports` | 7 | BACKLOG |
| Offline-first local database | `engine/lib/src/storage` contracts + `lib/data/local` sqflite impl | 1, 6 | BACKLOG |
| AI assistant + drawing analysis (modular, no secrets) | `lib/features/ai` | 8 | BACKLOG |
| Cloud sync (modular, offline-safe) | `lib/features/sync` | 9 | BACKLOG |
| Bengali + English localization | `lib/core/l10n` | 1 | BACKLOG |
| Automated tests | `engine/test`, `test/` | all | BACKLOG |

## 4. Key architectural decisions (ADRs)

1. **ADR-001 — Pure-Dart engine boundary.** All formulas, validation, unit conversion, floor-plan geometry and shared-wall accounting live in `engine/`, a pure Dart package with zero Flutter imports. UI only renders engine outputs. Reason: deterministic, testable, and testable today with the available Dart SDK.
2. **ADR-002 — Result objects carry evidence.** Every calculation returns input echo, formula identifier, step breakdown, units, assumptions, warnings, waste and cost where applicable. Reason: reports and AI explanations must show real derivations, not magic numbers.
3. **ADR-003 — Walls are first-class, rooms reference them.** Geometry stores a single `Wall` record per physical wall with `connectedRoomIds`. Room area comes from its polygon; wall material takeoff is computed once from the deduplicated global wall set. Reason: prevents double counting of shared walls.
4. **ADR-004 — Offline-first with explicit sync states.** Local DB is source of truth. Cloud is an optional adapter. `synced` is only emitted after server acknowledgement. Queue never deletes local pending changes.
5. **ADR-005 — AI is advisory and unverified by default.** AI output uses `AI_DETECTED`, `ESTIMATED`, `UNCERTAIN`, `USER_VERIFIED`, `USER_EDITED` statuses. No AI value silently becomes a measured value. No keys in app source.
6. **ADR-006 — Minimal dependency surface.** Flutter UI uses stable mainstream packages only, so a future Flutter environment can resolve them without exotic patches.

## 5. Risks

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| R-01 | SDK not on main PATH; commands must run inside Ubuntu proot | LOW | Resolved: use `proot-distro login ubuntu -- bash -lc ...`; document the command pattern in `KNOWN_ISSUES.md` |
| R-02 | Very large feature scope vs. single agent capacity | HIGH | Strict priority order; engine correctness first; honest task statuses |
| R-03 | Regional land units vary by locality | MEDIUM | Configurable factors with named presets, never hardcoded as universal truth |
| R-04 | Structural advice from AI could be misused | HIGH | Mandatory disclaimer, confidence/status labels, no code-based engineering approval |
| R-05 | Sync conflicts could lose data | HIGH | Append-only pending ops + explicit conflict list + user decision; never auto-delete |
| R-06 | Floating point drift in quantity takeoff | MEDIUM | Fixed-decimal rounding at output boundaries, `num` arithmetic with explicit precision policy |

## 6. Phase 0 verdict

Audit complete. Architecture, database, engine, floor-plan, offline, AI and testing strategies documented in the sibling files. Task board created in `TASK_BOARD.md`. Implementation may proceed, starting with the pure-Dart engine where real verification is possible.
