import 'dart:async';

import 'package:engine/engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/l10n.dart';
import 'widgets/common.dart';

class CalculatorPage extends StatelessWidget {
  const CalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('calculator')),
          bottom: TabBar(
            tabs: [
              Tab(text: context.t('calculator')),
              Tab(text: context.t('converter')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ExpressionCalculator(), _ConverterTab()],
        ),
      ),
    );
  }
}

class _ExpressionCalculator extends StatefulWidget {
  const _ExpressionCalculator();

  @override
  State<_ExpressionCalculator> createState() => _ExpressionCalculatorState();
}

class _ExpressionCalculatorState extends State<_ExpressionCalculator> {
  final _expression = TextEditingController();
  final _memory = CalculatorMemory();
  CalculationResult<double>? _result;
  bool _degrees = true;

  @override
  void dispose() {
    _expression.dispose();
    super.dispose();
  }

  void _insert(String text) {
    final sel = _expression.selection;
    final next =
        _expression.text.substring(0, sel.start) +
        text +
        _expression.text.substring(sel.end);
    _expression.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
  }

  void _evaluate() {
    setState(() {
      _result = ExpressionCalculator(degrees: _degrees)
          .evaluate(_expression.text);
    });
    if (_result!.isValid) {
      unawaited(
        context.read<AppState>().addHistory(_expression.text, _result!.output!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expression,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _evaluate(),
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: InputDecoration(
                    hintText: '2+3*sqrt(16)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.backspace_outlined),
                      onPressed: () {
                        final value = _expression.text;
                        if (value.isNotEmpty) {
                          _expression.text = value.substring(
                            0,
                            value.length - 1,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _degrees ? 'DEG' : 'RAD',
                onPressed: () => setState(() => _degrees = !_degrees),
                icon: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _degrees ? 'DEG' : 'RAD',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ResultPanel<double>(
              result: _result!,
              format: (v) =>
                  v.toStringAsFixed(context.read<AppState>().precision),
            ),
          ),
        const Spacer(),
        _buildScientificRow(),
        _buildMemoryRow(),
        _buildKeypad(),
        const _HistoryStrip(),
      ],
    );
  }

  Widget _buildScientificRow() {
    final buttons = [
      'sin(',
      'cos(',
      'tan(',
      'sqrt(',
      'log(',
      'ln(',
      '^',
      '%',
      'pi',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: buttons
            .map(
              (key) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: OutlinedButton(
                  onPressed: () => _insert(key),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(52, 40),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(key, style: const TextStyle(fontSize: 12)),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMemoryRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _smallButton('MC', () => setState(_memory.clear)),
          _smallButton('MR', () => _insert(_memory.value.toString())),
          _smallButton('M+', () => _memory.add(_result?.output ?? 0)),
          _smallButton('M−', () => _memory.subtract(_result?.output ?? 0)),
          const Spacer(),
          Text(
            'M = ${_memory.value.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _smallButton(String label, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size(44, 36)),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    ),
  );

  Widget _buildKeypad() {
    final rows = [
      ['7', '8', '9', '/'],
      ['4', '5', '6', '*'],
      ['1', '2', '3', '-'],
      ['0', '.', '(', ')'],
      ['C', '+', '±', '='],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: rows
            .map((row) => Row(children: row.map(_keyButton).toList()))
            .toList(),
      ),
    );
  }

  Widget _keyButton(String key) {
    final isOperator = '/×*+-='.contains(key);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: SizedBox(
          height: 48,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: isOperator
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
            ),
            onPressed: () {
              if (key == '=') {
                _evaluate();
              } else if (key == 'C') {
                setState(() {
                  _expression.clear();
                  _result = null;
                });
              } else if (key == '±') {
                _insert('-');
              } else {
                _insert(key);
              }
            },
            child: Text(key, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }
}

class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().history;
    if (history.isEmpty) return const SizedBox(height: 8);
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: history.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = history[index];
          return ActionChip(
            label: Text('${item['expression']} = ${item['result']}'),
            onPressed: () {},
          );
        },
      ),
    );
  }
}

class _ConverterTab extends StatefulWidget {
  const _ConverterTab();

  @override
  State<_ConverterTab> createState() => _ConverterTabState();
}

class _ConverterTabState extends State<_ConverterTab> {
  final _value = TextEditingController(text: '1');
  String _from = 'm';
  String _to = 'feet';
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<AppState>().unitRegistry;
    final value = double.tryParse(_value.text);
    final result = (value == null || _error != null)
        ? null
        : registry.convertWithEvidence(value, _from, _to);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumberField(controller: _value, label: context.t('value')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _from,
                  decoration: InputDecoration(labelText: context.t('from')),
                  items: [
                    for (final unit in registry.units)
                      DropdownMenuItem(
                        value: unit.id,
                        child: Text(
                          context.read<AppState>().locale.languageCode == 'bn'
                              ? unit.labelBn
                              : unit.labelEn,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _from = v ?? _from),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _to,
                  decoration: InputDecoration(labelText: context.t('to')),
                  items: [
                    for (final unit in registry.units)
                      DropdownMenuItem(
                        value: unit.id,
                        child: Text(
                          context.read<AppState>().locale.languageCode == 'bn'
                              ? unit.labelBn
                              : unit.labelEn,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _to = v ?? _to),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (result != null)
            ResultPanel<double>(
              result: result,
              format: (v) =>
                  v.toStringAsFixed(context.watch<AppState>().precision),
            )
          else
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.t('validationError')),
              ),
            ),
        ],
      ),
    );
  }
}
