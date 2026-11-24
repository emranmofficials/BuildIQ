# Known Issues & Limitations

| ID | Issue | Impact | Status / Mitigation |
|---|---|---|---|
| K-01 | Flutter/Dart are not on the Termux PATH | Commands fail if run directly | Run them through `proot-distro login ubuntu -- bash -lc '...'` (see `TESTING_STRATEGY.md`) |
| K-02 | A standalone Dart SDK was downloaded to `~/tools/dart-sdk` but cannot execute under Termux (glibc linker missing) | Wasted disk (~250 MB extracted) | Unused; proot SDK is authoritative. Safe to delete after project acceptance |
| K-03 | No application code exists yet at Phase 0 completion | App cannot be installed | **Resolved in Phase 1** — full application layer implemented; see `DEVELOPMENT_LOG.md` |
| K-04 | Regional land-unit factors vary by locality | Conversion may not match a specific local convention | Presets are configurable; UI displays the active preset; never presented as universal |
| K-05 | AI structural advice cannot replace engineering review | Safety risk | Mandatory warning in assistant output; no engineering approval claims |
| K-06 | Cloud sync is optional and unconfigured by default | Multi-device sync unavailable until configured | Offline features unaffected; no false `synced` status |
| K-07 | Debug APK build has not yet been confirmed | Installation artifact not verified | First attempt failed in proot during Gradle (see K-13); retry with 1 Gradle worker in progress |
| K-08 | SQLite CRUD is exercised by the pure-Dart in-memory repository, not yet by a sqflite-on-Flutter test | DB adapter not independently verified under `flutter test` | `sqflite_common_ffi` test dependency not yet added; task T-012 remains CODE_COMPLETE |
| K-09 | Floor-plan editor is in-memory demo state, not persisted to SQLite | Edits are lost on app restart | **Resolved** — `AppState.saveFloorPlan`/`loadFloorPlan` persist walls, openings, rooms and shared-wall links; editor loads on startup and has a Save action |
| K-10 | Floor-plan editor lacks rotate/duplicate/pan and widget-level interaction tests | Reduced editing capability | Core select/add/openings/undo/redo implemented; task T-054 remains CODE_COMPLETE |
| K-11 | Report exports are generated but not yet covered by golden/artifact tests | Output correctness not automatically asserted | Services implemented; tasks T-070…T-072 remain CODE_COMPLETE |
| K-12 | AI drawing analysis (image/PDF → draft floor plan) is not implemented | No automated plan import | Task T-082 is TODO; AI default remains no-op with honest "not configured" UI |
| K-13 | First `flutter build apk --debug` attempt aborted inside the Ubuntu proot with `Failed to close process exit code pipe` / `Could not start thread DartWorker: 38 (Function not implemented)` | APK not produced by that attempt | Environmental thread limit, not a compile error. Single-worker Gradle retry got past this stage |
| K-16 | Clean build with `--no-pub` failed Java compilation: `GeneratedPluginRegistrant.java` referenced plugin packages (`flutter_secure_storage`, `integration_test`, `dart_lang.jni*`, `printing`, `shared_preferences`, `sqflite`) absent from the Gradle classpath | No debug APK | Caused by `flutter clean` removing plugin registration state while `--no-pub` skipped `flutter pub get`. Fixed by running `flutter pub get` to regenerate plugin registrations; rebuild in progress |
| K-17 | No device/emulator is attached to `adb` or `flutter devices` in this environment | Cannot use `flutter run` to launch the UI directly | Install the generated debug APK on a physical Android device for manual testing |
| K-14 | The sync queue is still in-memory (`SyncQueue`) and is not restored from the `sync_queue` SQLite table after restart | Pending uploads are lost on app restart | Honest status is preserved (never falsely `synced`); persisting the queue is part of T-092 hardening |
| K-15 | BOQ lines derived from saved calculations use inferred units and the stored total cost, not per-material persisted rates | Material-level cost breakdown is coarser than a freshly generated BOQ | Quantities and total cost are accurate to what was saved; richer rate persistence is part of T-062 |

## Test status (2026-11-23, Phase 1)
- Engine: 65/65 passed.
- Flutter: 6/6 passed (localization, themes, connectivity labels, smoke).
- Analyzer: `flutter analyze` → No issues found.
- No currently failing or skipped tests are recorded. This file must be updated whenever a failure, skip or unresolved defect appears.
