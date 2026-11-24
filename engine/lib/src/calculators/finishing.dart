import '../core/result.dart';

class MaterialLine {
  final String name;
  final double quantity;
  final String unit;
  final Money? cost;

  const MaterialLine(this.name, this.quantity, this.unit, [this.cost]);

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'cost': cost?.toJson(),
  };
}

class FinishingOutput {
  final List<MaterialLine> materials;
  final double areaM2;
  final double wastePercent;

  const FinishingOutput({
    required this.materials,
    required this.areaM2,
    required this.wastePercent,
  });

  Map<String, dynamic> toJson() => {
    'materials': materials.map((line) => line.toJson()).toList(),
    'areaM2': areaM2,
    'wastePercent': wastePercent,
  };
}

class FinishingCalculator {
  const FinishingCalculator();

  CalculationResult<FinishingOutput> plaster({
    required double areaM2,
    required double thicknessMm,
    int cementRatio = 1,
    double sandRatio = 4,
    double dryFactor = 1.33,
    double wastePercent = 0,
    double cementDensityKgM3 = 1440,
    double bagWeightKg = 50,
    int cementPerBagMinor = 0,
    int sandPerM3Minor = 0,
  }) {
    final issues = validatePositive(
      fields: {
        'areaM2': areaM2,
        'thicknessMm': thicknessMm,
        'dryFactor': dryFactor,
      },
      allowZero: true,
    );
    if (issues.isNotEmpty) return CalculationResult.failure(issues);

    final wet = areaM2 * thicknessMm / 1000;
    final dry = applyWaste(wet * dryFactor, wastePercent);
    final sum = cementRatio + sandRatio;
    final cementVolume = dry * cementRatio / sum;
    final cementKg = cementVolume * cementDensityKgM3;
    final bags = (cementKg / bagWeightKg).ceil();
    final sand = dry * sandRatio / sum;

    return CalculationResult.success(
      FinishingOutput(
        areaM2: areaM2,
        wastePercent: wastePercent,
        materials: [
          MaterialLine(
            'Cement',
            bags.toDouble(),
            'bags',
            cementPerBagMinor > 0 ? Money(bags * cementPerBagMinor) : null,
          ),
          MaterialLine(
            'Sand',
            sand,
            'm³',
            sandPerM3Minor > 0 ? Money((sand * sandPerM3Minor).round()) : null,
          ),
        ],
      ),
      steps: [
        CalculationStep(
          label: 'Wet volume',
          value: wet,
          unit: 'm³',
          formula: 'area × thickness',
        ),
        CalculationStep(
          label: 'Dry volume with waste',
          value: dry,
          unit: 'm³',
          formula: 'wet × dryFactor × (1+waste)',
        ),
        CalculationStep(
          label: 'Cement bags',
          value: bags,
          unit: 'bags',
          formula: 'dry × cementShare × density / bagWeight',
        ),
        CalculationStep(
          label: 'Sand',
          value: sand,
          unit: 'm³',
          formula: 'dry × sandShare',
        ),
      ],
      formulaIds: const ['finishing.plaster.v1'],
      assumptions: {
        'ratio': '$cementRatio:$sandRatio',
        'thickness': '$thicknessMm mm',
        'waste': '$wastePercent%',
      },
    );
  }

  CalculationResult<FinishingOutput> liquidCoating({
    required String item,
    required double areaM2,
    required double coverageM2PerLitre,
    required int coats,
    double wastePercent = 0,
    int ratePerLitreMinor = 0,
  }) {
    final issues = validatePositive(
      fields: {'areaM2': areaM2, 'coverageM2PerLitre': coverageM2PerLitre},
    );
    if (coats < 1) {
      issues.add(
        const ValidationIssue(
          code: 'invalidCoats',
          field: 'coats',
          message: 'At least one coat is required.',
        ),
      );
    }
    if (issues.isNotEmpty) return CalculationResult.failure(issues);

    final litres = applyWaste(
      areaM2 / coverageM2PerLitre * coats,
      wastePercent,
    );
    return CalculationResult.success(
      FinishingOutput(
        areaM2: areaM2,
        wastePercent: wastePercent,
        materials: [
          MaterialLine(
            item,
            litres,
            'L',
            ratePerLitreMinor > 0
                ? Money((litres * ratePerLitreMinor).round())
                : null,
          ),
        ],
      ),
      steps: [
        CalculationStep(
          label: '$item volume',
          value: litres,
          unit: 'L',
          formula: 'area ÷ coverage × coats × (1+waste)',
        ),
      ],
      formulaIds: const ['finishing.liquidCoating.v1'],
      assumptions: {
        'item': item,
        'coverage': '$coverageM2PerLitre m²/L',
        'coats': '$coats',
        'waste': '$wastePercent%',
      },
    );
  }

  CalculationResult<FinishingOutput> tiles({
    required double areaM2,
    required double tileLengthMm,
    required double tileWidthMm,
    double wastePercent = 0,
    int ratePerPieceMinor = 0,
    double skirtingPerimeterM = 0,
    double skirtingHeightMm = 0,
  }) {
    final issues = validatePositive(
      fields: {
        'areaM2': areaM2,
        'tileLengthMm': tileLengthMm,
        'tileWidthMm': tileWidthMm,
      },
      allowZero: true,
    );
    if (issues.isNotEmpty) return CalculationResult.failure(issues);

    final tileArea = tileLengthMm * tileWidthMm / 1e6;
    if (tileArea <= 0) {
      return CalculationResult.failure([
        const ValidationIssue(
          code: 'invalidTile',
          field: 'tileDimensions',
          message: 'Tile dimensions must be positive.',
        ),
      ]);
    }
    final pieces = ceilQuantity(applyWaste(areaM2 / tileArea, wastePercent));
    final skirtingArea = skirtingPerimeterM * skirtingHeightMm / 1000;
    final skirtingPieces = skirtingHeightMm > 0
        ? ceilQuantity(applyWaste(skirtingArea / tileArea, wastePercent))
        : 0;

    return CalculationResult.success(
      FinishingOutput(
        areaM2: areaM2,
        wastePercent: wastePercent,
        materials: [
          MaterialLine(
            'Tiles',
            pieces.toDouble(),
            'pcs',
            ratePerPieceMinor > 0 ? Money(pieces * ratePerPieceMinor) : null,
          ),
          if (skirtingPieces > 0)
            MaterialLine(
              'Skirting tiles',
              skirtingPieces.toDouble(),
              'pcs',
              ratePerPieceMinor > 0
                  ? Money(skirtingPieces * ratePerPieceMinor)
                  : null,
            ),
        ],
      ),
      steps: [
        CalculationStep(
          label: 'Tile area',
          value: tileArea,
          unit: 'm²',
          formula: 'length × width',
        ),
        CalculationStep(
          label: 'Tiles',
          value: pieces,
          unit: 'pcs',
          formula: 'ceil(area ÷ tileArea × (1+waste))',
        ),
      ],
      formulaIds: const ['finishing.tiles.v1'],
      assumptions: {
        'tile': '$tileLengthMm×$tileWidthMm mm',
        'waste': '$wastePercent%',
        'skirting': '$skirtingPerimeterM m × $skirtingHeightMm mm',
      },
    );
  }
}
