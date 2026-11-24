/// Core result and validation types shared by every engine calculation.
///
/// No Flutter imports are allowed in this library.
library;

enum IssueSeverity { info, warning, error }

class ValidationIssue {
  final String code;
  final String field;
  final String message;
  final IssueSeverity severity;

  const ValidationIssue({
    required this.code,
    required this.field,
    required this.message,
    this.severity = IssueSeverity.error,
  });

  factory ValidationIssue.warning(String code, String field, String message) {
    return ValidationIssue(
      code: code,
      field: field,
      message: message,
      severity: IssueSeverity.warning,
    );
  }

  @override
  String toString() => '$severity/$code: $message ($field)';

  Map<String, dynamic> toJson() => {
    'code': code,
    'field': field,
    'message': message,
    'severity': severity.name,
  };
}

class CalculationStep {
  final String label;
  final num value;
  final String unit;
  final String? formula;

  const CalculationStep({
    required this.label,
    required this.value,
    required this.unit,
    this.formula,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'unit': unit,
    if (formula != null) 'formula': formula,
  };
}

/// A calculation result that always carries its own evidence.
class CalculationResult<T> {
  final T? output;
  final List<ValidationIssue> issues;
  final List<CalculationStep> steps;
  final List<String> formulaIds;
  final Map<String, String> assumptions;

  const CalculationResult._({
    this.output,
    this.issues = const [],
    this.steps = const [],
    this.formulaIds = const [],
    this.assumptions = const {},
  });

  factory CalculationResult.success(
    T output, {
    List<ValidationIssue> issues = const [],
    List<CalculationStep> steps = const [],
    List<String> formulaIds = const [],
    Map<String, String> assumptions = const {},
  }) {
    return CalculationResult._(
      output: output,
      issues: issues,
      steps: steps,
      formulaIds: formulaIds,
      assumptions: assumptions,
    );
  }

  factory CalculationResult.failure(List<ValidationIssue> issues) {
    return CalculationResult._(issues: issues);
  }

  bool get isValid =>
      output != null &&
      issues.every((issue) => issue.severity != IssueSeverity.error);

  List<ValidationIssue> get errors => issues
      .where((issue) => issue.severity == IssueSeverity.error)
      .toList(growable: false);

  List<ValidationIssue> get warnings => issues
      .where((issue) => issue.severity == IssueSeverity.warning)
      .toList(growable: false);

  Map<String, dynamic> toJson({Object? Function(T output)? serialize}) {
    final value = output;
    return {
      'valid': isValid,
      'output': value == null
          ? null
          : (serialize == null ? value : serialize(value)),
      'issues': issues.map((issue) => issue.toJson()).toList(),
      'steps': steps.map((step) => step.toJson()).toList(),
      'formulaIds': formulaIds,
      'assumptions': assumptions,
    };
  }
}

/// Rounding policy applied at presentation/export boundaries only.
class PrecisionPolicy {
  final int volumeDecimals;
  final int areaDecimals;
  final int lengthDecimals;
  final int massDecimals;
  final int moneyDecimals;

  const PrecisionPolicy({
    this.volumeDecimals = 3,
    this.areaDecimals = 2,
    this.lengthDecimals = 2,
    this.massDecimals = 2,
    this.moneyDecimals = 2,
  });

  double roundVolume(double value) => _round(value, volumeDecimals);
  double roundArea(double value) => _round(value, areaDecimals);
  double roundLength(double value) => _round(value, lengthDecimals);
  double roundMass(double value) => _round(value, massDecimals);

  static double _round(double value, int places) {
    final factor = _pow10(places);
    return (value * factor).round() / factor;
  }

  static double _pow10(int n) {
    var result = 1.0;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }
}

/// Money stored as integer minor units to avoid floating-point drift.
class Money {
  final int minor;
  final String currency;

  const Money(this.minor, {this.currency = 'BDT'});

  factory Money.fromMajor(num major, {String currency = 'BDT'}) =>
      Money((major * 100).round(), currency: currency);

  double get major => minor / 100;

  Money operator +(Money other) {
    assert(currency == other.currency, 'Currency mismatch');
    return Money(minor + other.minor, currency: currency);
  }

  Money operator *(num factor) =>
      Money((minor * factor).round(), currency: currency);

  @override
  String toString() => '$currency ${major.toStringAsFixed(2)}';

  Map<String, dynamic> toJson() => {'minor': minor, 'currency': currency};
}

/// Rates used to turn physical quantities into costs.
class MaterialRates {
  final int cementPerBagMinor;
  final int sandPerM3Minor;
  final int aggregatePerM3Minor;
  final int waterPerLitreMinor;
  final int brickPerPieceMinor;
  final int steelPerKgMinor;
  final int paintPerLitreMinor;
  final int tilePerPieceMinor;

  const MaterialRates({
    this.cementPerBagMinor = 0,
    this.sandPerM3Minor = 0,
    this.aggregatePerM3Minor = 0,
    this.waterPerLitreMinor = 0,
    this.brickPerPieceMinor = 0,
    this.steelPerKgMinor = 0,
    this.paintPerLitreMinor = 0,
    this.tilePerPieceMinor = 0,
  });

  bool get hasAny =>
      cementPerBagMinor != 0 ||
      sandPerM3Minor != 0 ||
      aggregatePerM3Minor != 0 ||
      waterPerLitreMinor != 0 ||
      brickPerPieceMinor != 0 ||
      steelPerKgMinor != 0 ||
      paintPerLitreMinor != 0 ||
      tilePerPieceMinor != 0;
}

/// Helper for uniform input validation.
List<ValidationIssue> validatePositive({
  required Map<String, num> fields,
  bool allowZero = false,
}) {
  final issues = <ValidationIssue>[];
  fields.forEach((name, value) {
    if (value.isNaN || value.isInfinite) {
      issues.add(
        ValidationIssue(
          code: 'notFinite',
          field: name,
          message: '$name must be a finite number.',
        ),
      );
    } else if (allowZero ? value < 0 : value <= 0) {
      issues.add(
        ValidationIssue(
          code: allowZero ? 'negative' : 'notPositive',
          field: name,
          message: allowZero
              ? '$name cannot be negative.'
              : '$name must be greater than zero.',
        ),
      );
    }
  });
  return issues;
}

/// Applies a waste percentage (0–100) with validation.
double applyWaste(double netQuantity, double wastePercent) {
  if (wastePercent < 0 || wastePercent > 100) return netQuantity;
  return netQuantity * (1 + wastePercent / 100);
}

/// Rounds piece counts up, tolerating tiny binary floating-point overshoot.
int ceilQuantity(double value) => value.isFinite ? (value - 1e-9).ceil() : 0;
