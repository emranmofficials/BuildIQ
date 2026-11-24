import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';

import '../services/ai_service.dart';
import '../services/report_service.dart';
import '../services/sync_service.dart';
import 'ai_page.dart';
import 'calculator_page.dart';
import 'construction_page.dart';
import 'floorplan_page.dart';
import 'home_page.dart';
import 'projects_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';

class AppShell extends StatefulWidget {
  final AiService aiService;
  final SyncService syncService;
  final ReportService reportService;

  const AppShell({
    super.key,
    required this.aiService,
    required this.syncService,
    required this.reportService,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _goto(int index) => setState(() => _index = index);

  void _openFullScreen(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        openCalculator: () => _goto(1),
        openConstruction: () => _goto(2),
        openFloorPlan: () => _goto(3),
        openProjects: () => _goto(4),
      ),
      const CalculatorPage(),
      const ConstructionPage(),
      const FloorPlanPage(),
      const ProjectsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goto,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: context.t('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calculate_outlined),
            selectedIcon: const Icon(Icons.calculate),
            label: context.t('calculator'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.construction_outlined),
            selectedIcon: const Icon(Icons.construction),
            label: context.t('construction'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: context.t('floorPlan'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: context.t('projects'),
          ),
        ],
      ),
      appBar: AppBar(
        title: Text(context.t('appTitle')),
        actions: [
          IconButton(
            tooltip: context.t('reports'),
            icon: const Icon(Icons.description_outlined),
            onPressed: () => _openFullScreen(
              ReportsPage(reportService: widget.reportService),
            ),
          ),
          IconButton(
            tooltip: context.t('aiAssistant'),
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => _openFullScreen(AiPage(service: widget.aiService)),
          ),
          IconButton(
            tooltip: context.t('settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openFullScreen(
              SettingsPage(
                aiService: widget.aiService,
                syncService: widget.syncService,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
