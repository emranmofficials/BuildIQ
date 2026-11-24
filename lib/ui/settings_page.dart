import 'dart:async';

import 'package:engine/engine.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';

import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../services/ai_service.dart';
import '../services/sync_service.dart';

class SettingsPage extends StatelessWidget {
  final AiService aiService;
  final SyncService syncService;
  const SettingsPage({
    super.key,
    required this.aiService,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: context.t('language'),
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'bn', label: Text('বাংলা')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {state.locale.languageCode},
                onSelectionChanged: (values) =>
                    unawaited(state.setLocale(Locale(values.first))),
              ),
            ],
          ),
          _Section(
            title: context.t('theme'),
            children: [
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(context.t('light')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(context.t('dark')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(context.t('system')),
                  ),
                ],
                selected: {state.themeMode},
                onSelectionChanged: (values) =>
                    unawaited(state.setThemeMode(values.first)),
              ),
            ],
          ),
          _Section(
            title: 'Precision',
            children: [
              Slider(
                value: state.precision.toDouble(),
                min: 0,
                max: 6,
                divisions: 6,
                label: '${state.precision}',
                onChanged: (value) =>
                    unawaited(state.setPrecision(value.round())),
              ),
            ],
          ),
          _Section(
            title: 'Land unit preset',
            children: [
              DropdownButtonFormField<String>(
                initialValue: state.landPresetId,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (final entry in LandUnitPreset.presets.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        state.locale.languageCode == 'bn'
                            ? entry.value.labelBn
                            : entry.value.labelEn,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) unawaited(state.setLandPreset(value));
                },
              ),
            ],
          ),
          _Section(
            title: context.t('sync'),
            children: [
              Text(
                'Status: ${state.syncStatus.name}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Sync endpoint (optional)',
                  hintText: 'https://example.com/api/sync',
                ),
                controller: TextEditingController(text: syncService.endpoint),
                onSubmitted: (value) =>
                    unawaited(syncService.configureEndpoint(value)),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () async {
                  final result = await syncService.attemptSync();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.message ?? result.status.name),
                      ),
                    );
                  }
                },
                child: Text('Sync now'),
              ),
            ],
          ),
          _Section(
            title:
                '${context.t('aiAssistant')} (${aiService.activeProvider.name})',
            children: [
              Text(
                context.t('aiNotConfigured'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              const _AiConfigForm(),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AiConfigForm extends StatefulWidget {
  const _AiConfigForm();

  @override
  State<_AiConfigForm> createState() => _AiConfigFormState();
}

class _AiConfigFormState extends State<_AiConfigForm> {
  final _endpoint = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _endpoint.text = state.aiEndpoint ?? '';
    _model.text = state.aiModel ?? '';
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _endpoint,
          decoration: InputDecoration(labelText: context.t('endpoint')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _model,
          decoration: InputDecoration(labelText: context.t('model')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _key,
          obscureText: true,
          decoration: InputDecoration(labelText: context.t('apiKey')),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final state = context.read<AppState>();
            await state.configureAi(
              endpoint: _endpoint.text,
              model: _model.text,
              key: _key.text,
            );
            if (context.mounted) {
              // The provider is selected at startup; refresh it immediately so
              // the assistant becomes usable without an app restart.
              context.read<AiService>().refresh();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(context.t('saved'))));
            }
          },
          child: Text(context.t('save')),
        ),
      ],
    );
  }
}
