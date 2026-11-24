# Testing Strategy

## Commands (this device)
Flutter lives inside the Ubuntu proot container. Run all Flutter/Dart commands like this:

```sh
proot-distro login ubuntu -- bash -lc 'export PATH=/root/tools/flutter/bin:$PATH; cd /data/user/0/ai.antigem/files/home/projects/ai_construction_calculator && flutter analyze'
proot-distro login ubuntu -- bash -lc 'export PATH=/root/tools/flutter/bin:$PATH; cd /data/user/0/ai.antigem/files/home/projects/ai_construction_calculator/engine && dart test'
```

## Layers

| Layer | Location | Tool | Requirement |
|---|---|---|---|
| Pure engine unit tests | `engine/test/` | `dart test` | Every formula, conversion, parser path, shared-wall invariant |
| Golden value tests | `engine/test/**/*_test.dart` | `dart test` | Documented numeric examples with explicit expected values |
| Repository tests | `engine/test/storage` | `dart test` (in-memory repo) | CRUD, ordering, dirty flags, queue semantics |
| Widget tests | `test/widget/` | `flutter test` | calculators, converter, editor interactions, l10n switch |
| Integration tests | `integration_test/` | `flutter test integration_test` | offline create/save/restart, report export |
| Static analysis | whole project | `flutter analyze` | Zero issues before a task is DONE |
| Formatting | whole project | `dart format --output=none --set-exit-if-changed .` | Clean |

## Mandatory test cases
- **Calculator:** precedence, parentheses, unary minus, `%`, `√`, power, sin/cos/tan, log/ln, divide-by-zero, malformed expression, empty input, chained operations, memory recall/clear.
- **Units:** every factor, round-trip conversion, regional presets, precision boundaries, area/volume squared/cubed factors.
- **Concrete/brick/steel/finishing:** nominal example, zero waste, high waste, invalid sizes, cost path, rounding of piece counts.
- **Floor plan:** room create/resize/delete, wall link/unlink, shared-wall edit propagation, **duplicate shared-wall prevention**, openings, area/volume, takeoff.
- **Offline:** creation while offline, app restart persistence, pending queue survival, failed-sync recovery, no false synced state.
- **AI:** timeout, HTTP failure, malformed JSON, uncertain values, status transitions, no-provider path.

## Definition of done for tests
1. Test written against observable behaviour (not implementation internals where avoidable).
2. Test fails for a deliberately wrong implementation (sanity check for critical tests).
3. Entire suite passes; no `@skip` without a documented reason in `KNOWN_ISSUES.md`.
4. Result recorded in `TASK_BOARD.md` and `DEVELOPMENT_LOG.md`.

## Coverage priority
Shared-wall engine > concrete/masonry formulas > parser > unit factors > persistence > UI > AI > sync.
