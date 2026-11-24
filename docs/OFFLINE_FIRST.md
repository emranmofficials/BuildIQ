# Offline-First Strategy

Local SQLite is the source of truth. Network is an optional enhancement. Core calculators, converters, floor plans, projects, BOQ, history and local reports must never require internet.

## Connectivity model
Do **not** infer internet from Wi-Fi/mobile state. `ConnectivityService` combines platform link state with an actual lightweight HTTPS probe to the configured health URL.

| State | Meaning | UI label (en / bn) |
|---|---|---|
| `offline` | No network link | Offline / অফলাইন |
| `connected` | Link + probe OK | Connected / সংযুক্ত |
| `internetUnavailable` | Link present, no internet | Internet unavailable / ইন্টারনেট নেই |
| `serverUnavailable` | Internet OK, API unreachable | Server unavailable / সার্ভার পাওয়া যায়নি |
| `syncPending` | Local dirty rows exist | Sync pending / সিঙ্ক বাকি |
| `syncing` | Queue in flight | Syncing / সিঙ্ক হচ্ছে |
| `synced` | Server acknowledged all changes | Synced / সিঙ্ক সম্পন্ন |
| `syncFailed` | Retryable or conflicted | Sync failed / সিঙ্ক ব্যর্থ |

`synced` is emitted **only** after server acknowledgement. No optimistic "Synced" badge.

## Write path
1. User action writes to local DB in a transaction.
2. Row marked `dirty=1`; append op to `sync_queue` (atomic with the write).
3. UI updates immediately from local state.
4. Sync worker may run later; failure leaves queue and dirty flags intact.

## Sync rules
- Never delete local data because sync failed.
- Never overwrite user edits with remote data without comparison.
- Conflicts are listed explicitly with local/remote values and require a user decision (`keep local`, `keep remote`, `merge manually`).
- Retry with exponential backoff for recoverable errors; surface terminal failures.
- Maintain `sync_log` entries for every attempt.
- Cloud module is isolated; disabling it must not affect offline features.

## Offline test matrix
- Airplane mode: calculator, converter, project creation, floor plan edit, saved calculation, CSV/PDF export.
- Kill app mid-edit → restart → draft preserved.
- Simulate sync failure → pending queue survives restart → retry succeeds.
- Simulate server timeout → UI shows `serverUnavailable`/`syncFailed`, never `synced`.
