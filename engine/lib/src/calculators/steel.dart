import '../core/result.dart';

enum BarShape { round, square }

class RebarInput {
  final BarShape shape;
  final double diameterMm;
  final double memberLengthM;
  final double spacingMm;
  final double spanMm;
  final double coverMm;
  final double hookLengthMm;
  final int? explicitCount;
  final double wastePercent;
  final int ratePerKgMinor;

  const RebarInput({
    this.shape = BarShape.round,
    required this.diameterMm,
    required this.memberLengthM,
    required this.spacingMm,
    required this.spanMm,
    this.coverMm = 40,
    this.hookLengthMm = 0,
    this.explicitCount,
    this.wastePercent = 0,
    this.ratePerKgMinor = 0,
  });
}

class RebarOutput {
  final double unitWeightKgPerM;
  final double cuttingLengthM;
  final int bars;
  final double totalLengthM;
  final double totalWeightKg;
  final Money? cost;

  const RebarOutput({
    required this.unitWeightKgPerM,
    required this.cuttingLengthM,
    required this.bars,
    required this.totalLengthM,
    required this.totalWeightKg,
    this.cost,
  });

  Map<String, dynamic> toJson() => {
    'unitWeightKgPerM': unitWeightKgPerM,
    'cuttingLengthM': cuttingLengthM,
    'bars': bars,
    'totalLengthM': totalLengthM,
    'totalWeightKg': totalWeightKg,
    'cost': cost?.toJson(),
  };
}

class RebarCalculator {
  const RebarCalculator();

  /// Unit weight of a circular bar: D²/162 kg/m (D in mm).
  /// Derived from steel density 7850 kg/m³ and rounded for site use.
  static double roundBarUnitWeight(double diameterMm) =>
      diameterMm * diameterMm / 162;

  /// Square bar: side² × 0.00785 kg/m.
  static double squareBarUnitWeight(double sideMm) => sideMm * sideMm * 0.00785;

  CalculationResult<RebarOutput> calculate(RebarInput input) {
    final issues = validatePositive(
      fields: {
        'diameterMm': input.diameterMm,
        'memberLengthM': input.memberLengthM,
        'spacingMm': input.spacingMm,
        'spanMm': input.spanMm,
      },
      allowZero: true,
    );
    if (input.wastePercent < 0 || input.wastePercent > 100) {
      issues.add(
        const ValidationIssue(
          code: 'invalidWaste',
          field: 'wastePercent',
          message: 'Waste percentage must be between 0 and 100.',
        ),
      );
    }
    if (input.explicitCount != null && input.explicitCount! < 1) {
      issues.add(
        const ValidationIssue(
          code: 'invalidCount',
          field: 'explicitCount',
          message: 'Bar count must be at least 1.',
        ),
      );
    }
    if (issues.isNotEmpty) return CalculationResult.failure(issues);

    final unitWeight = input.shape == BarShape.round
        ? roundBarUnitWeight(input.diameterMm)
        : squareBarUnitWeight(input.diameterMm);
    final cuttingLength =
        input.memberLengthM +
        2 * input.hookLengthMm / 1000 -
        2 * input.coverMm / 1000;
    if (cuttingLength <= 0) {
      return CalculationResult.failure([
        const ValidationIssue(
          code: 'negativeCuttingLength',
          field: 'cuttingLength',
          message: 'Cover deduction exceeds member length.',
        ),
      ]);
    }

    final bars =
        input.explicitCount ??
        (input.spacingMm > 0 ? (input.spanMm / input.spacingMm).ceil() + 1 : 1);
    final netLength = cuttingLength * bars;
    final totalLength = applyWaste(netLength, input.wastePercent);
    final totalWeight = totalLength * unitWeight;
    final money = input.ratePerKgMinor > 0
        ? Money((totalWeight * input.ratePerKgMinor).round())
        : null;

    return CalculationResult.success(
      RebarOutput(
        unitWeightKgPerM: unitWeight,
        cuttingLengthM: cuttingLength,
        bars: bars,
        totalLengthM: totalLength,
        totalWeightKg: totalWeight,
        cost: money,
      ),
      steps: [
        CalculationStep(
          label: 'Unit weight',
          value: unitWeight,
          unit: 'kg/m',
          formula: input.shape == BarShape.round
              ? 'D² / 162'
              : 'side² × 0.00785',
        ),
        CalculationStep(
          label: 'Cutting length',
          value: cuttingLength,
          unit: 'm',
          formula: 'member + 2×hook − 2×cover',
        ),
        CalculationStep(
          label: 'Number of bars',
          value: bars,
          unit: 'pcs',
          formula: 'ceil(span / spacing) + 1',
        ),
        CalculationStep(
          label: 'Total length with waste',
          value: totalLength,
          unit: 'm',
          formula: 'cuttingLength × bars × (1+waste)',
        ),
        CalculationStep(
          label: 'Total weight',
          value: totalWeight,
          unit: 'kg',
          formula: 'totalLength × unitWeight',
        ),
      ],
      formulaIds: const ['steel.unitWeight.v1', 'steel.quantity.v1'],
      assumptions: {
        'shape': input.shape.name,
        'cover': '${input.coverMm} mm',
        'hook': '${input.hookLengthMm} mm per end',
        'waste': '${input.wastePercent}%',
        'safety': 'Estimation only — requires structural engineer review.',
      },
    );
  }
}
