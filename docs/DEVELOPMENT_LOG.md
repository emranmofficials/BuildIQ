# Development Log

## 2026-11-24 — Product rename to BuildIQ

**Actions taken**
- User requested the app be named **BuildIQ** with package `com.buildIq.app`.
- Updated `android/app/src/main/AndroidManifest.xml` (`android:label="BuildIQ"`), `android/app/build.gradle.kts` (`namespace` + `applicationId`), moved `MainActivity.kt` to `kotlin/com/buildIq/app/` with the new `package` declaration, changed the Flutter window title in `lib/main.dart`, and set `appTitle` to `BuildIQ` in both Bangla and English catalogues.
- Adjusted `test/widget_test.dart` expectations to the new name; updated `docs/PROJECT_OVERVIEW.md` with the product name and application ID.
- Stopped the stale pre-rename debug build, ran `dart format`, `flutter analyze` (**No issues found**), engine `dart test` (**65/65**) and `flutter test` (**6/6**) on the renamed code.
- Started a clean debug APK build with the new identity (single Gradle worker). APK result to be recorded when the build reports back.

## 2026-11-23 — Phase 0 (Audit & Planning)

**Actions taken**
- Listed `/data/user/0/ai.antigem/files/home/projects`; confirmed no existing AI Construction Calculator source. Existing Flutter apps (`zara`, `hermes_mobile`, `mosque_seba`) and AndroidIDE trees were inspected only, never modified.
- Checked toolchain: no Flutter/Dart on Termux PATH; found standalone Dart arm64 SDK (glibc-dependent, unusable directly in Termux) and, after deeper inspection, **Flutter 3.50.1 / Dart 3.14.0 inside the pre-installed Ubuntu proot** at `/root/tools/flutter/bin`.
- Verified workspace path is visible inside proot, so `flutter analyze`, `dart test` and builds are executable.
- Wrote all required Phase 0 documents and the 54-task board.
- Decided to keep a pure-Dart `engine/` package (zero Flutter imports) as the deterministic domain boundary, which also allows fast, isolated testing.

**Evidence**
- `flutter --version` → Flutter 3.50.1 • Dart 3.14.0 • linux_arm64.
- `proot-distro list` → ubuntu installed.

**Decisions**
- Shared walls stored once with a link table; takeoff deduplicates by wall ID.
- AI defaults to a no-op provider; no secrets in source; every detected item carries a verification status.
- SQLite source of truth; sync is append-only queue with honest state reporting.

**Result:** Phase 0 DONE.

## 2026-11-23 — Phase 1 (Application layer + validation)

**Actions taken**
- Generated the Flutter scaffold and a pure-Dart `engine/` package; resolved dependencies after switching to `material_ui: ^1.11.1` (this SDK deprecates `package:flutter/material.dart`).
- Implemented and wired the full engine surface: expression parser, unit converter with Bangladeshi land presets, concrete/masonry/steel/finishing engines, floor-plan domain + `SharedWallRegistry`, BOQ generator, repository contract and sync queue.
- Implemented the offline-first state layer (`AppState`), SQLite schema/migrations (`AppDatabase`), connectivity probe, logging, localization and theming.
- Implemented the UI shell and every primary screen: home, calculator, construction hub, floor-plan editor, projects, reports, AI assistant and settings. Real services (`AiService`, `SyncService`, `ReportService`) are injected via `provider`.
- Replaced the generated counter widget test with meaningful localization/theme/smoke tests and added connectivity state tests.
- Ran repeated format/analyze/test cycles and fixed every reported issue rather than suppressing it.
- Added full JSON round-trip support to the floor-plan models and persisted plans to SQLite (`saveFloorPlan`/`loadFloorPlan`), including the shared-wall link table; the editor now loads saved plans and exposes a Save action.
- Audited AI/sync services: fixed stale provider selection after configuration and wired committed local writes into the append-only sync queue.

**Evidence**
- `engine && dart test` → **65/65 passed** (calculators, units, floor plan/shared wall, JSON round-trip, BOQ + sync queue).
- `flutter analyze` → **No issues found!**
- `flutter test` → **6/6 passed** (bilingual catalogue, missing-key fallback, Material 3 themes, app render, network status labels).
- Debug APK build attempt 1 failed inside the proot environment with `Failed to close process exit code pipe` / `Could not start thread DartWorker: 38 (Function not implemented)` during `assembleDebug`. This is an environment limitation, not a compile error — `flutter analyze` is clean. A retry with Gradle workers limited to 1 is in progress.

**Notable fixes**
- `CalculationResult.toJson` was missing a closing brace → restored; engine suite green again.
- `csv` package changed API → `Csv().encode(rows)`; `pdf` deprecation → `TableHelper.fromTextArray`.
- Wall editor built `TextEditingController`s inside `build()`, dropping focus on every keystroke → converted to a `StatefulWidget` with persistent controllers that commit on submit.
- Removed unused imports, fixed `context.t` extension imports across all UI files, and cleaned all lint findings.

**Result:** Phase 1 implementation COMPLETE; verification gate IN_PROGRESS pending the APK build and remaining widget/DB tests. Task board updated to 27 DONE / 16 CODE_COMPLETE / 2 IN_PROGRESS / 9 TODO. Floor-plan persistence (K-09) resolved.
