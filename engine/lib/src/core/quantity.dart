import 'result.dart';

/// A value tagged with its unit symbol. Useful for history and reports.
class Quantity {
  final double value;
  final String unit;

  const Quantity(this.value, this.unit);

  @override
  String toString() => '${value.toStringAsFixed(3)} $unit';

  Map<String, dynamic> toJson() => {'value': value, 'unit': unit};
}

ValidationIssue? checkRange(String field, num value, num min, num max) {
  if (value < min || value > max) {
    return ValidationIssue(
      code: 'outOfRange',
      field: field,
      message: '$field must be between $min and $max.',
    );
  }
  return null;
}
