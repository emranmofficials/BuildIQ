import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_state.dart';
import 'core/connectivity.dart';
import 'core/logger.dart';
import 'core/theme.dart';
import 'data/app_database.dart';
import 'services/ai_service.dart';
import 'services/report_service.dart';
import 'services/sync_service.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(
    () async {
      FlutterError.onError = (details) {
        AppLogger.error('Flutter error', details.exception);
        FlutterError.presentError(details);
      };
      try {
        final preferences = await SharedPreferences.getInstance();
        final database = AppDatabase.instance;
        final connectivity = ConnectivityService();
        final state = AppState(
          database: database,
          connectivity: connectivity,
          preferences: preferences,
          secureStorage: const FlutterSecureStorage(),
        );
        await state.load();
        await connectivity.initialize();

        final ai = AiService(state);
        final sync = SyncService(state);
        final reports = ReportService();
        sync.start();

        runApp(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppState>.value(value: state),
              Provider<AiService>.value(value: ai),
              Provider<SyncService>.value(value: sync),
              Provider<ReportService>.value(value: reports),
            ],
            child: const ConstructionApp(),
          ),
        );
      } catch (error, stack) {
        AppLogger.error('Fatal startup error', '$error\n$stack');
        runApp(_ErrorApp(error: error));
      }
    },
    (error, stack) {
      AppLogger.error('Uncaught async error', '$error\n$stack');
    },
  );
}

class ConstructionApp extends StatelessWidget {
  const ConstructionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'BuildIQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.themeMode,
      locale: state.locale,
      supportedLocales: const [Locale('bn'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AppShell(
        aiService: context.read<AiService>(),
        syncService: context.read<SyncService>(),
        reportService: context.read<ReportService>(),
      ),
    );
  }
}

class _ErrorApp extends StatelessWidget {
  final Object error;
  const _ErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Startup failed: $error'),
          ),
        ),
      ),
    );
  }
}
