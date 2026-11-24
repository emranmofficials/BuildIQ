import '../project/models.dart';

/// Offline-first repository contract. Local storage is the source of truth.
abstract class Repository<T extends Identified> {
  Future<T?> get(String id);
  Future<List<T>> getAll();
  Future<void> put(T item);
  Future<void> delete(String id);
  Future<void> clear();
}

/// Reference implementation used by engine tests and as a fallback when
/// platform storage is unavailable. The Flutter app uses sqflite in production.
class InMemoryRepository<T extends Identified> implements Repository<T> {
  final Map<String, T> _items = <String, T>{};

  @override
  Future<T?> get(String id) async => _items[id];

  @override
  Future<List<T>> getAll() async => List.unmodifiable(_items.values);

  @override
  Future<void> put(T item) async {
    _items[item.id] = item;
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }

  @override
  Future<void> clear() async {
    _items.clear();
  }
}

enum SyncOperation { insert, update, delete }

enum PendingSyncStatus { pending, inFlight, failed, applied }

class PendingSyncOp {
  final String id;
  final String entityType;
  final String entityId;
  final SyncOperation operation;
  final Map<String, dynamic> payload;
  final int attempts;
  final PendingSyncStatus status;
  final String? lastError;
  final DateTime createdAt;
  final DateTime nextAttemptAt;

  const PendingSyncOp({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.attempts = 0,
    this.status = PendingSyncStatus.pending,
    this.lastError,
    required this.createdAt,
    DateTime? nextAttemptAt,
  }) : nextAttemptAt = nextAttemptAt ?? createdAt;

  PendingSyncOp copyWith({
    int? attempts,
    PendingSyncStatus? status,
    String? lastError,
    DateTime? nextAttemptAt,
  }) {
    return PendingSyncOp(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      attempts: attempts ?? this.attempts,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }
}

/// Append-only queue: failed operations are never silently discarded.
class SyncQueue {
  final Map<String, PendingSyncOp> _ops = <String, PendingSyncOp>{};

  void enqueue(PendingSyncOp op) {
    _ops[op.id] = op;
  }

  List<PendingSyncOp> get all => List.unmodifiable(_ops.values);

  List<PendingSyncOp> get pending => _ops.values
      .where((op) => op.status == PendingSyncStatus.pending)
      .toList(growable: false);

  List<PendingSyncOp> due(DateTime now) => _ops.values
      .where(
        (op) =>
            op.status == PendingSyncStatus.pending &&
            !op.nextAttemptAt.isAfter(now),
      )
      .toList(growable: false);

  void markInFlight(String id) {
    final op = _ops[id];
    if (op != null) _ops[id] = op.copyWith(status: PendingSyncStatus.inFlight);
  }

  /// Only a server acknowledgement removes an operation from the queue.
  void acknowledge(String id) {
    _ops.remove(id);
  }

  void recordFailure(String id, String error, DateTime retryAt) {
    final op = _ops[id];
    if (op == null) return;
    _ops[id] = op.copyWith(
      attempts: op.attempts + 1,
      status: PendingSyncStatus.failed,
      lastError: error,
      nextAttemptAt: retryAt,
    );
  }

  void requeue(String id) {
    final op = _ops[id];
    if (op != null) {
      _ops[id] = op.copyWith(status: PendingSyncStatus.pending);
    }
  }
}
