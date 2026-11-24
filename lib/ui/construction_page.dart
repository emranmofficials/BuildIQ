import 'dart:async';

import 'package:engine/engine.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';

import 'package:provider/provider.dart';

import '../core/app_state.dart';
import 'widgets/common.dart';

class ConstructionPage extends StatelessWidget {
  const ConstructionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('construction')),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Concrete'),
              Tab(text: 'Brick'),
              Tab(text: 'Steel'),
              Tab(text: 'Finishing'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ConcreteTab(), _BrickTab(), _SteelTab(), _FinishingTab()],
        ),
      ),
    );
  }
}

void _saveResult(
  BuildContext context, {
  required String kind,
  required String title,
  required Map<String, dynamic> input,
  required Object result,
}) {
  unawaited(
    context.read<AppState>().saveCalculation(
      kind: kind,
      title: title,
      input: input,
      result: result is Map<String, dynamic> ? result : {},
    ),
  );
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(context.t('saved'))));
}

class _ConcreteTab extends StatefulWidget {
  const _ConcreteTab();

  @override
  State<_ConcreteTab> createState() => _ConcreteTabState();
}

class _ConcreteTabState extends State<_ConcreteTab> {
  final _formKey = GlobalKey<FormState>();
  final _length = TextEditingController(text: '10');
  final _width = TextEditingController(text: '10');
  final _thickness = TextEditingController(text: '0.15');
  final _waste = TextEditingController(text: '0');
  String _mix = 'M20';
  CalculationResult<ConcreteOutput>? _result;

  @override
  void dispose() {
    _length.dispose();
    _width.dispose();
    _thickness.dispose();
    _waste.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final rates = MaterialRates(
      cementPerBagMinor: 55000,
      sandPerM3Minor: 6000,
      aggregatePerM3Minor: 8000,
      waterPerLitreMinor: 2,
    );
    final input = ConcreteInput.rectangular(
      element: ConcreteElement.slab,
      lengthM: double.parse(_length.text),
      widthM: double.parse(_width.text),
      thicknessM: double.parse(_thickness.text),
      mix: MixDesign.presets[_mix] ?? MixDesign.m20,
      assumptions: ConcreteAssumptions(
        wastePercent: double.tryParse(_waste.text) ?? 0,
      ),
      rates: rates,
    );
    setState(() {
      _result = const ConcreteCalculator().calculate(input);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NumberField(
            controller: _length,
            label: context.t('length'),
            suffix: 'm',
          ),
          const SizedBox(height: 12),
          NumberField(
            controller: _width,
            label: context.t('width'),
            suffix: 'm',
          ),
          const SizedBox(height: 12),
          NumberField(
            controller: _thickness,
            label: context.t('thickness'),
            suffix: 'm',
          ),
          const SizedBox(height: 12),
          NumberField(
            controller: _waste,
            label: context.t('waste'),
            suffix: '%',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _mix,
            decoration: InputDecoration(labelText: context.t('mix')),
            items: [
              for (final key in MixDesign.presets.keys)
                DropdownMenuItem(value: key, child: Text(key)),
            ],
            onChanged: (v) => setState(() => _mix = v ?? _mix),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _calculate,
            child: Text(context.t('calculate')),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            ResultPanel<ConcreteOutput>(
              result: _result!,
              format: (out) =>
                  '${out.cementBags} ${context.t('cementBags')}\n'
                  '${context.t('sand')}: ${out.sandM3.toStringAsFixed(2)} m³\n'
                  '${context.t('aggregate')}: ${out.aggregateM3.toStringAsFixed(2)} m³',
              onSave: () => _saveResult(
                context,
                kind: 'concrete',
                title:
                    'Concrete ${_length.text}×${_width.text}×${_thickness.text}',
                input: {
                  'length': _length.text,
                  'width': _width.text,
                  'thickness': _thickness.text,
                  'mix': _mix,
                },
                result: _result!.toJson(serialize: (out) => out.toJson()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrickTab extends StatefulWidget {
  const _BrickTab();

  @override
  State<_BrickTab> createState() => _BrickTabState();
}

class _BrickTabState extends State<_BrickTab> {
  final _formKey = GlobalKey<FormState>();
  final _length = TextEditingController(text: '10');
  final _height = TextEditingController(text: '3');
  final _thickness = TextEditingController(text: '0.2');
  final _openings = TextEditingController(text: '0');
  final _waste = TextEditingController(text: '0');
  CalculationResult<BrickOutput>? _result;

  @override
  void dispose() {
    _length.dispose();
    _height.dispose();
    _thickness.dispose();
    _openings.dispose();
    _waste.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final input = BrickInput(
      wallLengthM: double.parse(_length.text),
      wallHeightM: double.parse(_height.text),
      wallThicknessM: double.parse(_thickness.text),
      openingsAreaM2: double.tryParse(_openings.text) ?? 0,
      wastePercent: double.tryParse(_waste.text) ?? 0,
    );
    setState(() => _result = const BrickCalculator().calculate(input));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NumberField(
            controller: _length,
            label: context.t('length'),
            suffix: 'm',
          ),
          const SizedBox(height: 12),
          NumberField(
            controller: _height,
            label: context.t('height'),
            suffix: 'm',
          ),
          const SizedBox(height: 12),
          NumberField(
            controller: _thickness,
            label: context.t('thickness'),
            suffix: 'm',
          ),
          const SizedBox(height: 12),
          NumberField(
            controller: _openings,
            label: 'Openings area',
            suffix: 'm²',
          ),
          const SizedBox(height: 12),
          NumberField(
            controller: _waste,
            label: context.t('waste'),
            suffix: '%',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _calculate,
            child: Text(context.t('calculate')),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            ResultPanel<BrickOutput>(
              result: _result!,
              format: (out) =>
                  '${out.bricks} ${context.t('bricks')}\n'
                  '${context.t('sand')}: ${out.sandM3.toStringAsFixed(2)} m³',
              onSave: () => _saveResult(
                context,
                kind: 'brick',
                title: 'Brick wall ${_length.text}×${_height.text}',
                input: {
                  'length': _length.text,
                  'height': _height.text,
                  'thickness': _thickness.text,
                },
                result: _result!.toJson(serialize: (out) => out.toJson()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SteelTab extends StatefulWidget {
  const _SteelTab();

  @override
  State<_SteelTab> createState() => _SteelTabState();
}

class _SteelTabState extends State<_SteelTab> {
  final _formKey = GlobalKey<FormState>();
  final _diameter = TextEditingController(text: '12');
  final _member = TextEditingController(text: '5');
  final _spacing = TextEditingController(text: '150');
  final _span = TextEditingController(text: '3000');
  final _waste = TextEditingController(text: '0');
  CalculationResult<RebarOutput>? _result;

  @override
  void dispose() {
    _diameter.dispose();
    _member.dispose();
    _spacing.dispose();
    _span.dispose();
    _waste.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final input = RebarInput(
      diameterMm: double.parse(_diameter.text),
      memberLengthM: double.parse(_member.text),
      spacingMm: double.parse(_spacing.text),
      spanMm: double.parse(_span.text),
      wastePercent: double.tryParse(_waste.text) ?? 0,
      ratePerKgMinor: 10000,
    );
    setState(() => _result = const RebarCalculator().calculate(input));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NumberField(controller: _diameter, label: 'Diameter', suffix: 'mm'),
          const SizedBox(height: 12),
          NumberField(controller: _member, label: 'Member length', suffix: 'm'),
          const SizedBox(height: 12),
          NumberField(controller: _spacing, label: 'Spacing', suffix: 'mm'),
          const SizedBox(height: 12),
          NumberField(controller: _span, label: 'Span', suffix: 'mm'),
          const SizedBox(height: 12),
          NumberField(
            controller: _waste,
            label: context.t('waste'),
            suffix: '%',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _calculate,
            child: Text(context.t('calculate')),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            ResultPanel<RebarOutput>(
              result: _result!,
              format: (out) =>
                  '${out.bars} bars × ${out.cuttingLengthM.toStringAsFixed(2)} m\n'
                  '${context.t('total')}: ${out.totalWeightKg.toStringAsFixed(2)} kg',
              onSave: () => _saveResult(
                context,
                kind: 'steel',
                title: 'Rebar ${_diameter.text}mm',
                input: {'diameter': _diameter.text, 'member': _member.text},
                result: _result!.toJson(serialize: (out) => out.toJson()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FinishingTab extends StatefulWidget {
  const _FinishingTab();

  @override
  State<_FinishingTab> createState() => _FinishingTabState();
}

class _FinishingTabState extends State<_FinishingTab> {
  final _formKey = GlobalKey<FormState>();
  final _area = TextEditingController(text: '100');
  final _thickness = TextEditingController(text: '12');
  final _coverage = TextEditingController(text: '10');
  int _mode = 0;
  CalculationResult<FinishingOutput>? _result;

  @override
  void dispose() {
    _area.dispose();
    _thickness.dispose();
    _coverage.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    const calculator = FinishingCalculator();
    final area = double.parse(_area.text);
    setState(() {
      switch (_mode) {
        case 0:
          _result = calculator.plaster(
            areaM2: area,
            thicknessMm: double.parse(_thickness.text),
          );
        case 1:
          _result = calculator.liquidCoating(
            item: 'Paint',
            areaM2: area,
            coverageM2PerLitre: double.parse(_coverage.text),
            coats: 2,
          );
        default:
          _result = calculator.tiles(
            areaM2: area,
            tileLengthMm: 300,
            tileWidthMm: 300,
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(context.t('plaster')),
                selected: _mode == 0,
                onSelected: (_) => setState(() => _mode = 0),
              ),
              ChoiceChip(
                label: Text(context.t('paint')),
                selected: _mode == 1,
                onSelected: (_) => setState(() => _mode = 1),
              ),
              ChoiceChip(
                label: Text(context.t('tiles')),
                selected: _mode == 2,
                onSelected: (_) => setState(() => _mode = 2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          NumberField(controller: _area, label: 'Area', suffix: 'm²'),
          const SizedBox(height: 12),
          if (_mode == 0)
            NumberField(
              controller: _thickness,
              label: context.t('thickness'),
              suffix: 'mm',
            ),
          if (_mode == 1)
            NumberField(
              controller: _coverage,
              label: 'Coverage',
              suffix: 'm²/L',
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _calculate,
            child: Text(context.t('calculate')),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            ResultPanel<FinishingOutput>(
              result: _result!,
              format: (out) => out.materials
                  .map(
                    (line) =>
                        '${line.name}: ${line.quantity.toStringAsFixed(2)} ${line.unit}',
                  )
                  .join('\n'),
              onSave: () => _saveResult(
                context,
                kind: 'finishing',
                title: 'Finishing $_area m²',
                input: {'area': _area.text, 'mode': _mode},
                result: _result!.toJson(serialize: (out) => out.toJson()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
