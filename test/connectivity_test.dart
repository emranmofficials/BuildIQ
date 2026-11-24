import 'package:ai_construction_calculator/core/connectivity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkStatus labels', () {
    test('every status has a stable, non-empty key', () {
      final keys = <String>{};
      for (final status in NetworkStatus.values) {
        expect(status.key, isNotEmpty);
        expect(
          keys.add(status.key),
          isTrue,
          reason: 'Duplicate key for $status: ${status.key}',
        );
      }
      expect(keys.length, NetworkStatus.values.length);
    });

    test('offline-first states map to their documented keys', () {
      expect(NetworkStatus.offline.key, 'offline');
      expect(NetworkStatus.internetUnavailable.key, 'internetUnavailable');
      expect(NetworkStatus.serverUnavailable.key, 'serverUnavailable');
      expect(NetworkStatus.syncPending.key, 'syncPending');
      expect(NetworkStatus.syncing.key, 'syncing');
      expect(NetworkStatus.synced.key, 'synced');
      expect(NetworkStatus.syncFailed.key, 'syncFailed');
    });
  });
}
