# Changelog

All notable changes are recorded here. Format: Unreleased → versions.

## Unreleased — 2026-11-24
### Added
- Product renamed to **BuildIQ**; Android application ID / package changed to `com.buildIq.app` (manifest label, Gradle namespace/applicationId, MainActivity Kotlin package path, Flutter window title and Bangla/English `appTitle`).
- Phase 0 audit report (`PHASE0_AUDIT.md`), project overview, architecture with 6 ADRs.
- Database schema, calculation engine spec, floor-plan/shared-wall spec, offline-first strategy, AI system design, testing strategy.
- Task board with 54 tracked tasks; Phase 0 tasks T-001…T-008 marked DONE with evidence.
- **Phase 1 application layer:** real Flutter UI shell with offline-first state wiring, bilingual Bangla/English UI, Material 3 light/dark themes, and provider-based service locator.
- Expression/scientific calculator with memory and persisted history; unit converter including configurable regional land presets.
- Construction calculator hub: concrete, brick/masonry, rebar/steel and finishing calculators with per-material breakdown, saving results and dedicated result panels.
- Interactive 2D floor-plan editor: room/wall selection, openings linked to walls, shared-wall awareness, thickness/height editing, undo/redo, and live deduplicated takeoff banner.
- Projects CRUD (create/list/detail/delete) backed by SQLite.
- BOQ/report screen with a real CSV, `.xlsx` and PDF export service.
- Modular AI service (no-op default + user-configured OpenAI-compatible provider) and chat UI with a clear "not configured" state.
- Sync service with endpoint configuration, append-only queue semantics, retry/backoff and honest status reporting.
- `test/connectivity_test.dart` (network status labels) and expanded `test/widget_test.dart` (localization, themes, smoke).
- Floor-plan JSON round-trip factories (`Building`, `Floor`, `Room`, `Wall`, `Opening`, `PlanPoint`) plus `engine/test/floorplan/serialization_test.dart`.
- Real SQLite persistence for floor plans: `AppState.saveFloorPlan` / `loadFloorPlan` write and rebuild buildings, floors, walls, openings, rooms and the `room_walls` link table; the editor now loads on startup and has a Save action.

### Changed
- Environment assessment corrected: Flutter 3.50.1 / Dart 3.14.0 available in Ubuntu proot; initial "no SDK" blocker withdrawn.
- Switched Flutter imports to `package:material_ui/material_ui.dart` because this SDK deprecates `package:flutter/material.dart`.
- Wall-editor number fields now keep their controllers across rebuilds and commit on submit, so typing no longer loses focus.
- Task board refreshed with evidence-based statuses: 27 DONE / 16 CODE_COMPLETE / 2 IN_PROGRESS / 9 TODO.
- Room `status` column added to the SQLite schema so verification status survives a restart.
- AI provider selection now refreshes immediately after saving endpoint/model/key in Settings (no restart needed).
- Local writes (projects, saved calculations, floor plans) now enqueue real pending sync operations through an `AppState.onLocalChange` hook wired by `SyncService`.
- Fixed a crash when saving calculation results: output objects are now serialized via their own `toJson()` before being written to SQLite.
- BOQ/report generation now reads the serialized `output` map, infers sensible units, and carries the saved cost's exact minor amount instead of reporting a misleading zero total.

### Removed
- Unused imports and the generated counter smoke test scaffold.

### Fixed
- Engine `CalculationResult.toJson` missing class-closing brace; engine tests back to 63/63.
- CSV export updated to the `csv: ^8.0.0` `Csv().encode(...)` API.
- PDF table updated to `pw.TableHelper.fromTextArray` (deprecation fix).
- `flutter analyze` now reports **No issues found**.
