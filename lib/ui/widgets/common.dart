import 'package:engine/engine.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';

/// Displays a CalculationResult with steps, assumptions and warnings.
class ResultPanel<T> extends StatelessWidget {
  final CalculationResult<T> result;
  final String Function(T value) format;
  final VoidCallback? onSave;
  final String? saveLabel;

  const ResultPanel({
    super.key,
    required this.result,
    required this.format,
    this.onSave,
    this.saveLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.isValid) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('validationError'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...result.errors.map(
                (issue) => Text(
                  '• ${issue.message}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final warnings = result.warnings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calculate_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.t('result'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              format(result.output as T),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onSave != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onSave,
                child: Text(saveLabel ?? context.t('save')),
              ),
            ],
            if (result.steps.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                context.t('steps'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ...result.steps.map((step) => _buildStep(context, step)),
            ],
            if (result.assumptions.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                context.t('assumptions'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ...result.assumptions.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• ${entry.key}: ${entry.value}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
            if (warnings.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                context.t('warnings'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              ...warnings.map(
                (w) => Text(
                  '• ${w.message}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              context.t('structuralWarning'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, CalculationStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              step.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              step.formula ?? step.unit,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (step.value.isFinite)
            Text(
              step.value.toStringAsFixed(2),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// Numeric input field with a label and suffix.
class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onEditingComplete;

  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      onEditingComplete: onEditingComplete,
      textInputAction: TextInputAction.done,
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return context.t('validationError');
            }
            if (double.tryParse(value) == null) {
              return context.t('validationError');
            }
            return null;
          },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
