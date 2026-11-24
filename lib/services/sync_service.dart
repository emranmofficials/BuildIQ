import 'dart:async';
import 'dart:convert';

import 'package:engine/engine.dart';

import '../core/app_state.dart';
import '../core/connectivity.dart';
import '../core/logger.dart';

/// Result of one sync attempt. Never reports success without acknowledgement.
class SyncAttemptResult {
  final NetworkStatus status;
  final int attempted;
  final int acknowledged;
  final int failed;
  final String? message;

  const SyncAttemptResult({
    required this.status,
    required this.attempted,
    required this.acknowledged,
    required this.failed,
    this.message,
  });
}

/// Offline-first sync engine. Local SQLite is the source of truth; the remote
/// endpoint is optional. When no endpoint is configured the service reports
/// syncPending and leaves local data untouched — it never claims "synced".
class SyncService {
  final AppState state;
  final SyncQueue _queue = SyncQueue();
  Timer? _timer;
  bool _running = false;

  SyncService(this.state) {
    state.onLocalChange = enqueueLocalChange;
  }

  String get endpoint => state.preferences.getString('syncEndpoint') ?? '';
  bool get isConfigured => endpoint.trim().isNotEmpty;

  List<PendingSyncOp> get pending => _queue.all;

  Future<void> configureEndpoint(String url) async {
    await state.preferences.setString('syncEndpoint', url.trim());
  }

  void start({Duration interval = const Duration(minutes: 2)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => attemptSync());
    unawaited(attemptSync());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Enqueues a local change. Called by repositories after a local commit.
  void enqueueLocalChange({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) {
    final now = DateTime.now();
    _queue.enqueue(
      PendingSyncOp(
        id: '${entityType}_${entityId}_${now.microsecondsSinceEpoch}',
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
        createdAt: now,
      ),
    );
    state.setSyncStatus(NetworkStatus.syncPending);
  }

  Future<SyncAttemptResult> attemptSync() async {
    if (_running) {
      return const SyncAttemptResult(
        status: NetworkStatus.syncing,
        attempted: 0,
        acknowledged: 0,
        failed: 0,
        message: 'Sync already running',
      );
    }
    _running = true;
    try {
      final due = _queue.due(DateTime.now());
      if (due.isEmpty) {
        final status = isConfigured
            ? NetworkStatus.synced
            : NetworkStatus.syncPending;
        state.setSyncStatus(status);
        return SyncAttemptResult(
          status: status,
          attempted: 0,
          acknowledged: 0,
          failed: 0,
          message: isConfigured
              ? 'No pending changes'
              : 'No sync endpoint configured',
        );
      }

      if (!isConfigured) {
        state.setSyncStatus(NetworkStatus.syncPending);
        return SyncAttemptResult(
          status: NetworkStatus.syncPending,
          attempted: due.length,
          acknowledged: 0,
          failed: due.length,
          message: 'Local changes saved; configure a sync endpoint to upload.',
        );
      }

      final network = await state.connectivity.refresh();
      if (network == NetworkStatus.offline ||
          network == NetworkStatus.internetUnavailable ||
          network == NetworkStatus.serverUnavailable) {
        state.setSyncStatus(network);
        return SyncAttemptResult(
          status: network,
          attempted: due.length,
          acknowledged: 0,
          failed: due.length,
          message: 'Device is not online; changes remain queued locally.',
        );
      }

      state.setSyncStatus(NetworkStatus.syncing);
      var acknowledged = 0;
      var failed = 0;
      for (final op in due) {
        _queue.markInFlight(op.id);
        try {
          // Remote acknowledgment hook. The default implementation always
          // throws because no server is shipped; subclasses/plugins can
          // override to talk to a real backend.
          await _acknowledgeRemote(op);
          _queue.acknowledge(op.id);
          acknowledged++;
        } catch (error) {
          failed++;
          _queue.recordFailure(
            op.id,
            error.toString(),
            DateTime.now().add(Duration(seconds: 30 * (op.attempts + 1))),
          );
          AppLogger.warn('Sync op ${op.id} failed: $error');
        }
      }
      final status = failed == 0
          ? NetworkStatus.synced
          : NetworkStatus.syncFailed;
      state.setSyncStatus(status);
      return SyncAttemptResult(
        status: status,
        attempted: due.length,
        acknowledged: acknowledged,
        failed: failed,
      );
    } catch (error, stack) {
      AppLogger.error('Sync failed unexpectedly', '$error\n$stack');
      state.setSyncStatus(NetworkStatus.syncFailed);
      return SyncAttemptResult(
        status: NetworkStatus.syncFailed,
        attempted: 0,
        acknowledged: 0,
        failed: 0,
        message: error.toString(),
      );
    } finally {
      _running = false;
    }
  }

  /// Override in a backend plugin. Deliberately throws by default so nothing
  /// is ever marked synced without a real acknowledgement.
  Future<void> _acknowledgeRemote(PendingSyncOp op) async {
    throw UnimplementedError(
      'No remote sync backend configured. Pending op: ${jsonEncode(op.payload)}',
    );
  }

  void dispose() {
    stop();
    state.onLocalChange = null;
  }
}
