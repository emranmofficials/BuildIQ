# Database Schema (offline-first)

Engine: SQLite via `sqflite`. Database file: `construction_calculator.db` in the app documents directory.
Version: **1** (initial). All future migrations are additive; destructive changes require backup + explicit user approval.

## Conventions
- IDs are TEXT UUIDs generated locally (offline-safe).
- Timestamps are INTEGER Unix milliseconds UTC.
- Monetary values are INTEGER minor units (e.g., BDT paise) to avoid float drift; UI formats them.
- Measurements are REAL in SI base units (m, m², m³, kg) plus a `unit` label for display.
- Every mutable row has `updated_at` and `dirty` (0/1). `dirty=1` means pending sync.
- Foreign keys are ON; `ON DELETE` is RESTRICT for engineering records, never CASCADE on user data.

## Tables

### `meta`
| column | type | notes |
|---|---|---|
| key | TEXT PK | e.g. `schema_version`, `land_unit_preset` |
| value | TEXT | JSON or scalar |

### `projects`
| column | type | notes |
|---|---|---|
| id | TEXT PK | UUID |
| name | TEXT NOT NULL | |
| client_name | TEXT | |
| client_phone | TEXT | |
| address | TEXT | |
| project_type | TEXT | `sqft_based`, `contract`, `daily_rate`, `custom` |
| start_date | INTEGER | ms |
| end_date | INTEGER | ms |
| budget_minor | INTEGER | |
| notes | TEXT | |
| status | TEXT | `planning`, `active`, `completed`, `on_hold` |
| currency | TEXT default 'BDT' | |
| created_at, updated_at | INTEGER | |
| dirty | INTEGER default 0 | |

### `buildings`
`id`, `project_id` FK, `name`, `address`, `created_at`, `updated_at`, `dirty`

### `floors`
`id`, `building_id` FK, `name`, `level` INTEGER, `floor_height_m` REAL, `created_at`, `updated_at`, `dirty`

### `rooms`
`id`, `floor_id` FK, `name`, `polygon_json` TEXT (ordered x,y vertices in metres), `finish_level_m` REAL, `notes`, `created_at`, `updated_at`, `dirty`
> Room area is derived from `polygon_json`; it is never stored as a competing source of truth.

### `walls`
`id` TEXT PK (unique physical wall), `floor_id` FK, `name`, `x1,y1,x2,y2` REAL, `thickness_m` REAL, `height_m` REAL, `wall_type` TEXT (`exterior`,`interior`,`partition`,`boundary`,`foundation`,`parapet`,`custom`), `material`, `brick_type`, `mortar_ratio`, `is_shared` INTEGER, `ai_status` TEXT, `confidence` REAL, `created_at`, `updated_at`, `dirty`

### `room_walls` (shared-wall link table)
`room_id` FK, `wall_id` FK, `role` TEXT (`owner`,`shared`), PRIMARY KEY(room_id, wall_id)
> A physical wall appears once in `walls` but may have multiple `room_walls` rows. This is the core anti-duplication structure.

### `wall_segments`
`id`, `wall_id` FK, `start_m`, `end_m`, `thickness_m`, `height_m`, `notes`

### `openings`
`id`, `wall_id` FK (mandatory), `kind` TEXT (`door`,`window`,`ventilator`,`opening`), `subtype` TEXT (`main`,`room`,`bathroom`,`balcony`,`sliding`,`double`,`fixed`,`casement`,`bay`,`custom`), `offset_m` REAL, `width_m` REAL, `height_m` REAL, `sill_m` REAL, `ai_status`, `confidence`, `created_at`, `updated_at`, `dirty`

### `materials`
`id`, `project_id` FK nullable, `name`, `unit` TEXT (`kg`,`bag`,`m3`,`pcs`,`L`,`ft`), `unit_cost_minor` INTEGER, `supplier`, `notes`, `created_at`, `updated_at`, `dirty`

### `saved_calculations`
`id`, `project_id` FK nullable, `kind` TEXT (`concrete`,`brick`,`steel`,`plaster`,`paint`,`tile`,`unit_conversion`,`expression`,...), `title`, `input_json` TEXT, `result_json` TEXT (full breakdown/assumptions/warnings), `created_at`, `updated_at`, `dirty`

### `calculation_history`
`id`, `expression` TEXT, `result` TEXT, `created_at` — append-only, local only

### `boq_lines`
`id`, `project_id` FK, `source_type` TEXT (`calculation`,`floorplan`,`manual`), `source_id` TEXT nullable, `description`, `quantity` REAL, `unit` TEXT, `rate_minor` INTEGER, `amount_minor` INTEGER, `category`, `notes`, `created_at`, `updated_at`, `dirty`

### `expenses`
`id`, `project_id` FK, `title`, `amount_minor`, `category`, `spent_at` INTEGER, `notes`, `created_at`, `updated_at`, `dirty`

### `settings`
`key` TEXT PK, `value_json` TEXT — locale, theme, precision, land preset, mix ratios, wastage defaults, AI config reference (never raw secrets)

### `sync_queue`
`id`, `entity_type`, `entity_id`, `operation` (`insert`,`update`,`delete`), `payload_json`, `status` (`pending`,`in_flight`,`failed`,`applied`), `attempts` INTEGER, `last_error` TEXT, `created_at`, `next_attempt_at`
> Rows are removed only after server acknowledgement. Failure never deletes local data.

### `sync_log`
`id`, `started_at`, `finished_at`, `result` (`success`,`partial`,`failed`), `items_json`, `error` TEXT

### `ai_analyses`
`id`, `project_id` FK nullable, `source_type` (`image`,`pdf`), `source_path`, `provider`, `model`, `raw_response_json`, `draft_floorplan_json`, `status`, `created_at`

## Indexes
`projects(updated_at)`, `floors(building_id)`, `rooms(floor_id)`, `walls(floor_id)`, `room_walls(wall_id)`, `openings(wall_id)`, `saved_calculations(project_id,kind)`, `boq_lines(project_id)`, `expenses(project_id,spent_at)`, `sync_queue(status,next_attempt_at)`.

## Migration policy
1. Read `PRAGMA user_version`; run ordered additive migrations inside a transaction.
2. Backup the DB file to `backups/db-v<old>-<timestamp>.db` before any version bump.
3. Add columns with defaults; never drop or rename in-place without user approval.
4. Verify row counts after migration; log result.
