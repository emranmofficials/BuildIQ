# Architecture

## 1. Layering

```
┌──────────────────────────────────────────────────────────┐
│ Flutter UI (lib/features/*)                              │
│  pages, widgets, controllers (ChangeNotifier via Provider)│
└───────────────────┬──────────────────────────────────────┘
                    │ depends on
┌───────────────────▼──────────────────────────────────────┐
│ Application services (lib/data, lib/core)                │
│  repositories, sqflite, settings, connectivity, reports  │
└───────────────────┬──────────────────────────────────────┘
                    │ depends on
┌───────────────────▼──────────────────────────────────────┐
│ Pure Dart engine (engine/) — no Flutter imports          │
│  models, units, formulas, floor plan, shared walls, BOQ  │
└──────────────────────────────────────────────────────────┘
```

Dependency direction is strictly downward. The engine never imports Flutter, platform plugins, network clients or UI state.

## 2. Engine modules

| Namespace | Responsibility |
|---|---|
| `engine.core` | `Money`, `Quantity`, `ResultBreakdown`, `ValidationIssue`, rounding/precision |
| `engine.units` | Length, area, volume, mass, construction units, regional land units, conversion factors |
| `engine.calculator` | Tokenizer, shunting-yard parser, evaluator, memory/history model |
| `engine.concrete` | Mix designs, wet/dry volume, cement/sand/aggregate/water, wastage, cost |
| `engine.masonry` | Brick count, mortar, cement, sand, wall area/thickness, waste |
| `engine.steel` | Rebar unit weight, cutting length, count, total weight, wastage, cost |
| `engine.finishing` | Plaster, putty, primer, paint, tiles, skirting, waterproofing, ceiling |
| `engine.floorplan` | Building, Floor, Room, Wall, Opening, geometry, shared-wall registry, takeoff |
| `engine.project` | Project, material requirement, BOQ line, expense, cost rollup |
| `engine.storage` | Repository interfaces and in-memory reference implementation |

## 3. Flutter modules

| Namespace | Responsibility |
|---|---|
| `core/theme` | Light/dark Material 3 theme, high contrast for site use |
| `core/l10n` | `AppLocalizations` with `en` and `bn` ARB-backed delegates |
| `core/router` | Named routes and guarded navigation |
| `core/di` | Simple service locator (`Provider` + `RepositoryProvider`) |
| `core/connectivity` | Actual internet probe; states: offline, connected, internetUnavailable, serverUnavailable |
| `data/local` | sqflite database, migrations (additive only), DAOs |
| `features/*` | Feature UI + controllers |
| `shared/widgets` | Inputs, result cards, warning banners, number fields |

## 4. Data flow (example: concrete calculation)

1. User enters dimensions in the UI.
2. UI controller builds a `ConcreteInput` (typed, unit-tagged) from the engine.
3. Controller calls `ConcreteCalculator.calculate(input, config)`.
4. Engine validates, computes, and returns `CalculationResult<ConcreteOutput>` with breakdown and warnings.
5. UI renders result; "Save" writes a `SavedCalculation` through the repository; "Report" renders the same result object.

No formula is duplicated in a widget.

## 5. State management
`ChangeNotifier` + `provider` is used for feature state. It is simple, well supported, and requires no code generation. Repositories are injected at the root.

## 6. Error handling
- Engine throws `CalculationException` only for programmer errors; user-input problems are returned as `ValidationIssue`s.
- UI shows validation issues inline; never hides exceptions behind fake results.
- Global `FlutterError.onError` and `runZonedGuarded` route errors to a local log file.

## 7. Testing strategy
- **Engine:** `dart test` in `engine/` (executable in this environment).
- **Flutter:** widget tests for critical screens, integration tests for offline flows (require Flutter SDK; currently blocked).
- Shared-wall tests are mandatory and live in `engine/test/floorplan/shared_wall_test.dart`.

## 8. Security
- No API keys in source. AI endpoint and key are entered by the user and stored with platform secure storage (fallback: encrypted local preference with explicit user consent).
- Cloud credentials handled by the sync adapter, never by engine code.
- Database migrations are additive; no destructive migration without backup and user approval.
