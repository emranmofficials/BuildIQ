import 'dart:async';
import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';

import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/logger.dart';
import '../services/report_service.dart';

class ReportsPage extends StatelessWidget {
  final ReportService reportService;
  const ReportsPage({super.key, required this.reportService});

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<AppState>().savedCalculations;
    final summary = _buildSummary(saved);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('boq'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('boq'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('${summary.lines.length} items'),
                  Text(
                    '${context.t('total')}: ${(summary.totalMinor / 100).toStringAsFixed(2)} BDT',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => _export(context, summary, 'csv'),
                child: Text(context.t('exportCsv')),
              ),
              FilledButton.tonal(
                onPressed: () => _export(context, summary, 'xlsx'),
                child: Text(context.t('exportExcel')),
              ),
              FilledButton.tonal(
                onPressed: () => _export(context, summary, 'pdf'),
                child: Text(context.t('exportPdf')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (summary.lines.isEmpty)
            Text(context.t('noProjects'))
          else
            Card(
              child: DataTable(
                columns: [
                  DataColumn(label: Text(context.t('description'))),
                  DataColumn(label: Text(context.t('quantity'))),
                  DataColumn(label: Text(context.t('total'))),
                ],
                rows: summary.lines
                    .map(
                      (line) => DataRow(
                        cells: [
                          DataCell(Text(line.description)),
                          DataCell(
                            Text(
                              '${line.quantity.toStringAsFixed(2)} ${line.unit}',
                            ),
                          ),
                          DataCell(
                            Text((line.amountMinor / 100).toStringAsFixed(0)),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  BoqSummary _buildSummary(List<Map<String, dynamic>> saved) {
    const generator = BoqGenerator();
    final lines = <BoqLine>[];
    for (final row in saved) {
      final resultJson = row['result_json'] as String?;
      if (resultJson == null) continue;
      try {
        final decoded = _decodeResult(resultJson);
        if (decoded == null) continue;
        final output = decoded['output'];
        if (output is! Map<String, dynamic>) continue;
        final title = row['title'] as String? ?? 'Calculation';
        final projectId = row['project_id'] as String? ?? '';
        final sourceId = row['id'] as String? ?? '';
        final category = row['kind'] as String? ?? 'general';

        for (final entry in output.entries) {
          final value = entry.value;
          if (value is num && value > 0) {
            lines.add(
              BoqLine(
                id: '${sourceId}_${entry.key}',
                projectId: projectId,
                description: '$title · ${entry.key}',
                quantity: value.toDouble(),
                unit: _unitFor(entry.key),
                category: category,
                sourceType: 'calculation',
                sourceId: sourceId,
              ),
            );
          }
        }

        // Costs are stored as a Money map by the calculators. Carry the exact
        // minor amount into the BOQ as one line instead of inventing rates.
        final cost = output['cost'];
        if (cost is Map<String, dynamic>) {
          final minor = cost['minor'];
          if (minor is num && minor > 0) {
            lines.add(
              BoqLine(
                id: '${sourceId}_cost',
                projectId: projectId,
                description: '$title · estimated cost',
                quantity: 1,
                unit: 'job',
                rateMinor: minor.round(),
                category: category,
                sourceType: 'calculation',
                sourceId: sourceId,
                notes: 'Rate used when the calculation was saved',
              ),
            );
          }
        }
      } catch (error) {
        AppLogger.warn('Could not build BOQ from ${row['id']}: $error');
      }
    }
    return generator.summarize(lines);
  }

  String _unitFor(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('bag')) return 'bags';
    if (lower.contains('litre') || lower.contains('water')) return 'L';
    if (lower.contains('kg')) return 'kg';
    if (lower.contains('brick') ||
        lower.contains('bar') ||
        lower.contains('tile')) {
      return 'pcs';
    }
    if (lower.contains('area') || lower.contains('m2')) return 'm²';
    if (lower.contains('volume') || lower.contains('m3')) return 'm³';
    if (lower.contains('percent') || lower.contains('waste')) return '%';
    return 'unit';
  }

  Map<String, dynamic>? _decodeResult(String json) {
    // Imported lazily to keep the import list focused.
    return _JsonHelper.decode(json);
  }

  Future<void> _export(
    BuildContext context,
    BoqSummary summary,
    String format,
  ) async {
    try {
      final projectName = 'Project';
      final result = switch (format) {
        'csv' => await reportService.exportCsv(
          projectName: projectName,
          summary: summary,
        ),
        'xlsx' => await reportService.exportExcel(
          projectName: projectName,
          summary: summary,
        ),
        _ => await reportService.exportPdf(
          projectName: projectName,
          summary: summary,
        ),
      };
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.message}: ${result.file.path}')),
        );
      }
    } catch (error) {
      AppLogger.error('Export failed', error);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $error')));
      }
    }
  }
}

class _JsonHelper {
  static Map<String, dynamic>? decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}
