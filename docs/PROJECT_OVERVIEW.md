# BuildIQ — Project Overview

**Product name:** BuildIQ · **Android application ID / package:** `com.buildIq.app`

A professional, offline-first construction calculation application for Android and iOS, built with Flutter. The app combines everyday calculators, deterministic construction quantity engines, an editable floor-plan system with non-duplicating shared walls, project/BOQ management, reports, and modular AI assistance in Bengali and English.

## Product principles
1. **Offline by default.** Every core calculation, project record, floor plan and report works without internet.
2. **Verifiable numbers.** Every result exposes its formula, inputs, assumptions and step breakdown.
3. **No double counting.** A physical wall is stored once; rooms reference it.
4. **AI is advisory.** Detected/estimated values are clearly labelled and require user verification before being used as measurements.
5. **User data is never silently overwritten or deleted.**

## High-level feature map
- **Calculators:** basic, scientific, concrete (PCC/RCC/footing/column/beam/slab/roof/stair/lintel/ground beam), brick, masonry, steel & rebar, plaster, putty, primer, paint, tile, skirting, waterproofing, ceiling, material & cost.
- **Engineering data:** configurable mix ratios, waste percentages, unit weights, regional land units.
- **Floor Plan Intelligence:** buildings → floors → rooms → walls → openings; 2D editor with grid, snapping, select/move/resize/rotate/delete/duplicate, undo/redo, zoom/pan, labels.
- **Shared Wall Engine:** unique wall IDs, connected rooms, segment support, validation, deduplicated material takeoff and automated regression tests.
- **Project management:** multiple projects, client, address, type, dates, budget, notes, status, expenses, progress.
- **Reports:** PDF, Excel/CSV, print/share with inputs, formulas, breakdown, quantities, cost, assumptions, warnings.
- **AI:** Bangla/English assistant, drawing analysis (JPG/JPEG/PNG/PDF), material estimator, BOQ helper; modular provider interface with user-supplied configuration.
- **Localization:** English and বাংলা, including Bengali digits where used in UI formatting.
- **Sync:** optional cloud backup with sync queue, retry, conflict visibility and explicit states.

## Repository layout
```
ai_construction_calculator/
├── engine/                 # pure Dart domain + calculation package (testable without Flutter)
│   ├── lib/
│   └── test/
├── lib/                    # Flutter application
│   ├── core/               # theme, l10n, routing, errors, connectivity, DI
│   ├── data/               # local database adapters
│   ├── features/           # calculator, units, floorplan, projects, reports, ai, sync
│   └── shared/             # reusable widgets
├── docs/                   # project management documents
└── test/                   # Flutter widget/integration tests
```

## Status summary
See [`TASK_BOARD.md`](TASK_BOARD.md) for authoritative status. Phase 0 is complete. Flutter 3.50.1 / Dart 3.14.0 are available inside the Ubuntu proot container on this device, so `flutter analyze`, `flutter test` and builds can be executed there.
