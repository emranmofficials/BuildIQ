import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/connectivity.dart';
import '../core/l10n.dart';

class HomePage extends StatelessWidget {
  final VoidCallback openCalculator;
  final VoidCallback openConstruction;
  final VoidCallback openFloorPlan;
  final VoidCallback openProjects;

  const HomePage({
    super.key,
    required this.openCalculator,
    required this.openConstruction,
    required this.openFloorPlan,
    required this.openProjects,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final status = switch (state.syncStatus) {
      NetworkStatus.synced => context.t('synced'),
      NetworkStatus.syncing => context.t('syncing'),
      NetworkStatus.syncFailed => context.t('syncFailed'),
      NetworkStatus.offline => context.t('offline'),
      NetworkStatus.connected => context.t('connected'),
      NetworkStatus.syncPending => context.t('syncPending'),
      NetworkStatus.internetUnavailable => context.t('internetUnavailable'),
      NetworkStatus.serverUnavailable => context.t('serverUnavailable'),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('appTitle')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: Icon(
                state.syncStatus == NetworkStatus.synced
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                size: 16,
              ),
              label: Text(status),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('offlineReady'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t('sharedWallNote'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _Tile(
                icon: Icons.calculate,
                label: context.t('calculator'),
                onTap: openCalculator,
              ),
              _Tile(
                icon: Icons.construction,
                label: context.t('construction'),
                onTap: openConstruction,
              ),
              _Tile(
                icon: Icons.grid_view,
                label: context.t('floorPlan'),
                onTap: openFloorPlan,
              ),
              _Tile(
                icon: Icons.folder_outlined,
                label: context.t('projects'),
                onTap: openProjects,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('history'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (state.history.isEmpty)
                    Text(context.t('noProjects'))
                  else
                    ...state.history
                        .take(5)
                        .map(
                          (item) => ListTile(
                            dense: true,
                            title: Text(
                              '${item['expression']} = ${item['result']}',
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
