import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'logger.dart';

/// Connectivity states required by the offline-first specification.
enum NetworkStatus {
  offline,
  connected,
  internetUnavailable,
  serverUnavailable,
  syncPending,
  syncing,
  synced,
  syncFailed,
}

extension NetworkStatusLabel on NetworkStatus {
  String get key => switch (this) {
    NetworkStatus.offline => 'offline',
    NetworkStatus.connected => 'connected',
    NetworkStatus.syncPending => 'syncPending',
    NetworkStatus.syncFailed => 'syncFailed',
    NetworkStatus.synced => 'synced',
    NetworkStatus.syncing => 'syncing',
    NetworkStatus.internetUnavailable => 'internetUnavailable',
    NetworkStatus.serverUnavailable => 'serverUnavailable',
  };
}

/// Does not treat Wi-Fi/mobile link as internet access: an actual HTTPS
/// probe decides whether the device is truly online.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<NetworkStatus> status = ValueNotifier<NetworkStatus>(
    NetworkStatus.offline,
  );
  final String probeUrl;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityService({
    this.probeUrl = 'https://clients3.google.com/generate_204',
  });

  Future<void> initialize() async {
    _subscription = _connectivity.onConnectivityChanged.listen(
      (_) => refresh(),
    );
    await refresh();
  }

  Future<NetworkStatus> refresh() async {
    final links = await _connectivity.checkConnectivity();
    final hasLink = links.any((result) => result != ConnectivityResult.none);
    if (!hasLink) {
      status.value = NetworkStatus.offline;
      return status.value;
    }
    try {
      final response = await http
          .get(Uri.parse(probeUrl))
          .timeout(const Duration(seconds: 4));
      status.value = response.statusCode >= 200 && response.statusCode < 400
          ? NetworkStatus.connected
          : NetworkStatus.serverUnavailable;
    } on TimeoutException {
      status.value = NetworkStatus.internetUnavailable;
    } catch (error) {
      AppLogger.warn('Internet probe failed: $error');
      status.value = NetworkStatus.internetUnavailable;
    }
    return status.value;
  }

  void dispose() {
    _subscription?.cancel();
    status.dispose();
  }
}
