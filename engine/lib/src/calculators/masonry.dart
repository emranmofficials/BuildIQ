import '../core/result.dart';

class BrickInput {
  final double wallLengthM;
  final double wallHeightM;
  final double wallThicknessM;
  final double openingsAreaM2;
  final double brickLengthMm;
  final double brickWidthMm;
  final double brickHeightMm;
  final double jointMm;
  final double wastePercent;
  final double mortarDryFactor;
  final double cementDensityKgM3;
  final double bagWeightKg;
  final int mortarCementRatio;
  final double mortarSandRatio;
  final MaterialRates rates;

  const BrickInput({
    required this.wallLengthM,
    required this.wallHeightM,
    required this.wallThicknessM,
    this.openingsAreaM2 = 0,
    this.brickLengthMm = 190,
    this.brickWidthMm = 90,
    this.brickHeightMm = 90,
    this.jointMm = 10,
    this.wastePercent = 0,
    this.mortarDryFactor = 1.33,
    this.cementDensityKgM3 = 1440,
    this.bagWeightKg = 50,
    this.mortarCementRatio = 1,
    this.mortarSandRatio = 6,
    this.rates = const MaterialRates(),
  });
}

class BrickOutput {
  final double wallAreaM2;
  final double netWallVolumeM3;
  final int bricks;
  final double mortarWetM3;
  final double mortarDryM3;
  final int cementBags;
  final double sandM3;
  final Money? cost;

  const BrickOutput({
    required this.wallAreaM2,
    required this.netWallVolumeM3,
    required this.bricks,
    required this.mortarWetM3,
    required this.mortarDryM3,
    required this.cementBags,
    required this.sandM3,
    this.cost,
  });

  Map<String, dynamic> toJson() => {
    'wallAreaM2': wallAreaM2,
    'netWallVolumeM3': netWallVolumeM3,
    'bricks': bricks,
    'mortarWetM3': mortarWetM3,
    'mortarDryM3': mortarDryM3,
    'cementBags': cementBags,
    'sandM3': sandM3,
    'cost': cost?.toJson(),
  };
}

class BrickCalculator {
  const BrickCalculator();

  CalculationResult<BrickOutput> calculate(BrickInput input) {
    final issues = validatePositive(
      fields: {
        'wallLengthM': input.wallLengthM,
        'wallHeightM': input.wallHeightM,
        'wallThicknessM': input.wallThicknessM,
        'brickLengthMm': input.brickLengthMm,
        'brickWidthMm': input.brickWidthMm,
        'brickHeightMm': input.brickHeightMm,
        'mortarDryFactor': input.mortarDryFactor,
        'cementDensityKgM3': input.cementDensityKgM3,
        'bagWeightKg': input.bagWeightKg,
      },
      allowZero: true,
    );
    if (input.openingsAreaM2 < 0) {
      issues.add(
        const ValidationIssue(
          code: 'negativeOpenings',
          field: 'openingsAreaM2',
          message: 'Opening area cannot be negative.',
        ),
      );
    }
    if (input.wastePercent < 0 || input.wastePercent > 100) {
      issues.add(
        const ValidationIssue(
          code: 'invalidWaste',
          field: 'wastePercent',
          message: 'Waste percentage must be between 0 and 100.',
        ),
      );
    }
    if (input.jointMm < 0) {
      issues.add(
        const ValidationIssue(
          code: 'negativeJoint',
          field: 'jointMm',
          message: 'Mortar joint cannot be negative.',
        ),
      );
    }
    if (issues.isNotEmpty) return CalculationResult.failure(issues);

    final grossArea = input.wallLengthM * input.wallHeightM;
    final netArea = grossArea - input.openingsAreaM2;
    if (netArea <= 0) {
      return CalculationResult.failure([
        const ValidationIssue(
          code: 'openingsExceedWall',
          field: 'openingsAreaM2',
          message: 'Opening area must be smaller than wall area.',
        ),
      ]);
    }
    final volume = netArea * input.wallThicknessM;
    final brickVolume =
        input.brickLengthMm * input.brickWidthMm * input.brickHeightMm / 1e9;
    final nominalVolume =
        (input.brickLengthMm + input.jointMm) *
        (input.brickWidthMm + input.jointMm) *
        (input.brickHeightMm + input.jointMm) /
        1e9;
    if (nominalVolume <= 0) {
      return CalculationResult.failure([
        const ValidationIssue(
          code: 'invalidBrick',
          field: 'brickDimensions',
          message: 'Brick dimensions must be positive.',
        ),
      ]);
    }

    final netBricks = volume / nominalVolume;
    final bricks = ceilQuantity(applyWaste(netBricks, input.wastePercent));
    final mortarWetNet = (volume - netBricks * brickVolume).clamp(0.0, volume);
    final mortarWet = applyWaste(mortarWetNet, input.wastePercent);
    final mortarDry = mortarWet * input.mortarDryFactor;
    final ratioSum = input.mortarCementRatio + input.mortarSandRatio;
    final cementVolume = mortarDry * input.mortarCementRatio / ratioSum;
    final cementBags = ceilQuantity(
      cementVolume * input.cementDensityKgM3 / input.bagWeightKg,
    );
    final sand = mortarDry * input.mortarSandRatio / ratioSum;

    Money? cost;
    if (input.rates.hasAny) {
      var minor = bricks * input.rates.brickPerPieceMinor;
      minor += (cementBags * input.rates.cementPerBagMinor);
      minor += (sand * input.rates.sandPerM3Minor).round();
      cost = Money(minor);
    }

    return CalculationResult.success(
      BrickOutput(
        wallAreaM2: netArea,
        netWallVolumeM3: volume,
        bricks: bricks,
        mortarWetM3: mortarWet,
        mortarDryM3: mortarDry,
        cementBags: cementBags,
        sandM3: sand,
        cost: cost,
      ),
      steps: [
        CalculationStep(
          label: 'Net wall area',
          value: netArea,
          unit: 'm²',
          formula: 'L × H − openings',
        ),
        CalculationStep(
          label: 'Wall volume',
          value: volume,
          unit: 'm³',
          formula: 'netArea × thickness',
        ),
        CalculationStep(
          label: 'Brick volume',
          value: brickVolume,
          unit: 'm³',
          formula: 'L × W × H',
        ),
        CalculationStep(
          label: 'Nominal brick volume with joint',
          value: nominalVolume,
          unit: 'm³',
          formula: '(L+j) × (W+j) × (H+j)',
        ),
        CalculationStep(
          label: 'Bricks',
          value: bricks,
          unit: 'pcs',
          formula: 'ceil(wallVolume / nominalVolume × (1+waste))',
        ),
        CalculationStep(
          label: 'Mortar (wet, with waste)',
          value: mortarWet,
          unit: 'm³',
          formula: '(wallVolume − netBricks × brickVolume) × (1+waste)',
        ),
        CalculationStep(
          label: 'Mortar (dry)',
          value: mortarDry,
          unit: 'm³',
          formula: 'wet × dryFactor',
        ),
        CalculationStep(
          label: 'Cement bags',
          value: cementBags,
          unit: 'bags',
          formula: 'mortarDry × cementShare × density / bagWeight',
        ),
        CalculationStep(
          label: 'Sand',
          value: sand,
          unit: 'm³',
          formula: 'mortarDry × sandShare',
        ),
      ],
      formulaIds: const ['masonry.brickCount.v1', 'masonry.mortar.v1'],
      assumptions: {
        'brick':
            '${input.brickLengthMm}×${input.brickWidthMm}×${input.brickHeightMm} mm',
        'joint': '${input.jointMm} mm',
        'mortarRatio': '${input.mortarCementRatio}:${input.mortarSandRatio}',
        'waste': '${input.wastePercent}%',
      },
    );
  }
}
