import 'dart:math' as math;

import '../core/result.dart';

enum ConcreteElement {
  pcc,
  rcc,
  footing,
  foundation,
  columnRectangular,
  columnCircular,
  beam,
  slab,
  roof,
  stair,
  lintel,
  groundBeam,
}

class MixDesign {
  final String id;
  final double cement;
  final double sand;
  final double aggregate;

  const MixDesign(this.id, this.cement, this.sand, this.aggregate);

  double get sum => cement + sand + aggregate;

  static const m10 = MixDesign('M10', 1, 3, 6);
  static const m15 = MixDesign('M15', 1, 2, 4);
  static const m20 = MixDesign('M20', 1, 1.5, 3);
  static const m25 = MixDesign('M25', 1, 1, 2);

  static const presets = {'M10': m10, 'M15': m15, 'M20': m20, 'M25': m25};
}

class ConcreteAssumptions {
  final double dryVolumeFactor;
  final double cementDensityKgM3;
  final double bagWeightKg;
  final double waterCementRatio;
  final double wastePercent;

  const ConcreteAssumptions({
    this.dryVolumeFactor = 1.54,
    this.cementDensityKgM3 = 1440,
    this.bagWeightKg = 50,
    this.waterCementRatio = 0.50,
    this.wastePercent = 0,
  });
}

class ConcreteInput {
  final ConcreteElement element;
  final double lengthM;
  final double widthM;
  final double thicknessM;
  final double? diameterM;
  final int? stairSteps;
  final double? treadM;
  final double? riseM;
  final MixDesign mix;
  final ConcreteAssumptions assumptions;
  final MaterialRates rates;

  const ConcreteInput._({
    required this.element,
    required this.lengthM,
    required this.widthM,
    required this.thicknessM,
    this.diameterM,
    this.stairSteps,
    this.treadM,
    this.riseM,
    required this.mix,
    required this.assumptions,
    required this.rates,
  });

  factory ConcreteInput.rectangular({
    required ConcreteElement element,
    required double lengthM,
    required double widthM,
    required double thicknessM,
    MixDesign mix = MixDesign.m20,
    ConcreteAssumptions assumptions = const ConcreteAssumptions(),
    MaterialRates rates = const MaterialRates(),
  }) {
    return ConcreteInput._(
      element: element,
      lengthM: lengthM,
      widthM: widthM,
      thicknessM: thicknessM,
      mix: mix,
      assumptions: assumptions,
      rates: rates,
    );
  }

  factory ConcreteInput.circularColumn({
    required double diameterM,
    required double heightM,
    MixDesign mix = MixDesign.m20,
    ConcreteAssumptions assumptions = const ConcreteAssumptions(),
    MaterialRates rates = const MaterialRates(),
  }) {
    return ConcreteInput._(
      element: ConcreteElement.columnCircular,
      lengthM: heightM,
      widthM: diameterM,
      thicknessM: diameterM,
      diameterM: diameterM,
      mix: mix,
      assumptions: assumptions,
      rates: rates,
    );
  }

  /// Stair wet volume = triangular steps + optional landing thickness.
  factory ConcreteInput.stair({
    required int steps,
    required double treadM,
    required double riseM,
    required double widthM,
    double landingVolumeM3 = 0,
    MixDesign mix = MixDesign.m20,
    ConcreteAssumptions assumptions = const ConcreteAssumptions(),
    MaterialRates rates = const MaterialRates(),
  }) {
    return ConcreteInput._(
      element: ConcreteElement.stair,
      lengthM: steps * treadM,
      widthM: widthM,
      thicknessM: riseM,
      stairSteps: steps,
      treadM: treadM,
      riseM: riseM,
      mix: mix,
      assumptions: assumptions,
      rates: rates,
    );
  }
}

class ConcreteOutput {
  final double wetVolumeM3;
  final double dryVolumeM3;
  final double cementVolumeM3;
  final double sandM3;
  final double aggregateM3;
  final double cementKg;
  final int cementBags;
  final double waterLitres;
  final double wastePercent;
  final Money? cost;

  const ConcreteOutput({
    required this.wetVolumeM3,
    required this.dryVolumeM3,
    required this.cementVolumeM3,
    required this.sandM3,
    required this.aggregateM3,
    required this.cementKg,
    required this.cementBags,
    required this.waterLitres,
    required this.wastePercent,
    this.cost,
  });

  Map<String, dynamic> toJson() => {
    'wetVolumeM3': wetVolumeM3,
    'dryVolumeM3': dryVolumeM3,
    'cementVolumeM3': cementVolumeM3,
    'sandM3': sandM3,
    'aggregateM3': aggregateM3,
    'cementKg': cementKg,
    'cementBags': cementBags,
    'waterLitres': waterLitres,
    'wastePercent': wastePercent,
    'cost': cost?.toJson(),
  };
}

class ConcreteCalculator {
  const ConcreteCalculator();

  CalculationResult<ConcreteOutput> calculate(ConcreteInput input) {
    final issues = validatePositive(
      fields: {
        'lengthM': input.lengthM,
        'widthM': input.widthM,
        'thicknessM': input.thicknessM,
        'dryVolumeFactor': input.assumptions.dryVolumeFactor,
        'cementDensityKgM3': input.assumptions.cementDensityKgM3,
        'bagWeightKg': input.assumptions.bagWeightKg,
      },
    );
    if (input.assumptions.wastePercent < 0 ||
        input.assumptions.wastePercent > 100) {
      issues.add(
        const ValidationIssue(
          code: 'invalidWaste',
          field: 'wastePercent',
          message: 'Waste percentage must be between 0 and 100.',
        ),
      );
    }
    if (input.mix.sum <= 0) {
      issues.add(
        const ValidationIssue(
          code: 'invalidMix',
          field: 'mix',
          message: 'Mix ratio components must be positive.',
        ),
      );
    }
    if (issues.isNotEmpty) return CalculationResult.failure(issues);

    final wet = switch (input.element) {
      ConcreteElement.columnCircular =>
        math.pi *
            math.pow(input.diameterM ?? input.widthM, 2) /
            4 *
            input.lengthM,
      ConcreteElement.stair =>
        (input.stairSteps ?? 0) *
            0.5 *
            (input.treadM ?? 0) *
            (input.riseM ?? 0) *
            input.widthM,
      _ => input.lengthM * input.widthM * input.thicknessM,
    };

    if (wet <= 0) {
      return CalculationResult.failure([
        const ValidationIssue(
          code: 'zeroVolume',
          field: 'dimensions',
          message: 'Computed concrete volume is zero.',
        ),
      ]);
    }

    final dry = wet * input.assumptions.dryVolumeFactor;
    final effectiveDry = applyWaste(dry, input.assumptions.wastePercent);
    final cementVolume = effectiveDry * input.mix.cement / input.mix.sum;
    final sand = effectiveDry * input.mix.sand / input.mix.sum;
    final aggregate = effectiveDry * input.mix.aggregate / input.mix.sum;
    final cementKg = cementVolume * input.assumptions.cementDensityKgM3;
    final cementBags = (cementKg / input.assumptions.bagWeightKg).ceil();
    final water = cementKg * input.assumptions.waterCementRatio;

    final wastedWet = applyWaste(wet, input.assumptions.wastePercent);
    Money? cost;
    if (input.rates.hasAny) {
      var minor = cementBags * input.rates.cementPerBagMinor;
      minor += (sand * input.rates.sandPerM3Minor).round();
      minor += (aggregate * input.rates.aggregatePerM3Minor).round();
      minor += (water * input.rates.waterPerLitreMinor).round();
      cost = Money(minor);
    }

    final steps = <CalculationStep>[
      CalculationStep(
        label: 'Wet volume',
        value: wet,
        unit: 'm³',
        formula: 'L × W × T',
      ),
      CalculationStep(
        label: 'Dry volume',
        value: dry,
        unit: 'm³',
        formula: 'wet × ${input.assumptions.dryVolumeFactor}',
      ),
      CalculationStep(
        label: 'Dry volume including waste',
        value: effectiveDry,
        unit: 'm³',
        formula: 'dry × (1 + waste/100)',
      ),
      CalculationStep(
        label: 'Cement volume',
        value: cementVolume,
        unit: 'm³',
        formula: 'dry × ${input.mix.cement} / ${input.mix.sum}',
      ),
      CalculationStep(
        label: 'Sand',
        value: sand,
        unit: 'm³',
        formula: 'dry × sand / sum',
      ),
      CalculationStep(
        label: 'Aggregate',
        value: aggregate,
        unit: 'm³',
        formula: 'dry × aggregate / sum',
      ),
      CalculationStep(
        label: 'Cement mass',
        value: cementKg,
        unit: 'kg',
        formula: 'cementVolume × density',
      ),
      CalculationStep(
        label: 'Cement bags',
        value: cementBags,
        unit: 'bags',
        formula: 'ceil(cementMass / bagWeight)',
      ),
      CalculationStep(
        label: 'Water',
        value: water,
        unit: 'L',
        formula: 'cementMass × waterCementRatio',
      ),
      CalculationStep(
        label: 'Wet volume including waste',
        value: wastedWet,
        unit: 'm³',
        formula: 'wet × (1 + waste/100)',
      ),
    ];

    return CalculationResult.success(
      ConcreteOutput(
        wetVolumeM3: wet,
        dryVolumeM3: dry,
        cementVolumeM3: cementVolume,
        sandM3: sand,
        aggregateM3: aggregate,
        cementKg: cementKg,
        cementBags: cementBags,
        waterLitres: water,
        wastePercent: input.assumptions.wastePercent,
        cost: cost,
      ),
      steps: steps,
      formulaIds: [
        'concrete.${input.element.name}.v1',
        'concrete.dryVolume.v1',
        'concrete.mixDesign.v1',
      ],
      assumptions: {
        'mix': input.mix.id,
        'mixRatio':
            '${input.mix.cement}:${input.mix.sand}:${input.mix.aggregate}',
        'dryFactor': input.assumptions.dryVolumeFactor.toString(),
        'cementDensity': '${input.assumptions.cementDensityKgM3} kg/m³',
        'bagWeight': '${input.assumptions.bagWeightKg} kg',
        'waterCementRatio': input.assumptions.waterCementRatio.toString(),
        'waste': '${input.assumptions.wastePercent}%',
        'safety': 'Estimation only — requires structural engineer review.',
      },
    );
  }
}
