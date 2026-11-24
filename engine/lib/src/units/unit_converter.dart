import '../core/result.dart';

enum UnitDimension { length, area, volume, mass }

enum UnitGroup { length, area, volume, mass, land, construction }

class UnitDef {
  final String id;
  final String labelEn;
  final String labelBn;
  final String symbol;
  final UnitDimension dimension;
  final UnitGroup group;
  final double factorToBase;

  const UnitDef({
    required this.id,
    required this.labelEn,
    required this.labelBn,
    required this.symbol,
    required this.dimension,
    required this.group,
    required this.factorToBase,
  });

  @override
  String toString() => symbol;
}

/// Regional land units genuinely differ. Never present presets as universal truth.
class LandUnitPreset {
  final String id;
  final String labelEn;
  final String labelBn;
  final double decimalSquareMetres;
  final double kathaInDecimal;
  final double bighaInKatha;

  const LandUnitPreset({
    required this.id,
    required this.labelEn,
    required this.labelBn,
    required this.decimalSquareMetres,
    required this.kathaInDecimal,
    required this.bighaInKatha,
  });

  static const LandUnitPreset bangladeshStandard = LandUnitPreset(
    id: 'bd_standard',
    labelEn: 'Bangladesh (standard)',
    labelBn: 'বাংলাদেশ (প্রচলিত)',
    decimalSquareMetres: 40.468564224, // 435.6 sq ft
    kathaInDecimal: 1.65, // ≈ 718.7 sq ft
    bighaInKatha: 20,
  );

  static const LandUnitPreset bangladeshDhaka = LandUnitPreset(
    id: 'bd_dhaka',
    labelEn: 'Bangladesh (Dhaka variant)',
    labelBn: 'বাংলাদেশ (ঢাকা)',
    decimalSquareMetres: 40.468564224,
    kathaInDecimal: 1.65,
    bighaInKatha: 20,
  );

  static const Map<String, LandUnitPreset> presets = {
    'bd_standard': bangladeshStandard,
    'bd_dhaka': bangladeshDhaka,
  };
}

class UnitConversionException implements Exception {
  final String message;
  const UnitConversionException(this.message);

  @override
  String toString() => 'UnitConversionException: $message';
}

class UnitRegistry {
  final LandUnitPreset landPreset;
  late final Map<String, UnitDef> _units;

  UnitRegistry({LandUnitPreset? preset})
    : landPreset = preset ?? LandUnitPreset.bangladeshStandard {
    _units = {
      for (final unit in _staticUnits) unit.id: unit,
      ..._landUnits(landPreset),
    };
  }

  static const _foot = 0.3048;
  static const _inch = 0.0254;
  static const _squareFoot = _foot * _foot;
  static const _cubicFoot = _foot * _foot * _foot;
  static const _acre = 4046.8564224;

  static const List<UnitDef> _staticUnits = [
    // Length
    UnitDef(
      id: 'mm',
      labelEn: 'Millimetre',
      labelBn: 'মিলিমিটার',
      symbol: 'mm',
      dimension: UnitDimension.length,
      group: UnitGroup.length,
      factorToBase: 0.001,
    ),
    UnitDef(
      id: 'cm',
      labelEn: 'Centimetre',
      labelBn: 'সেন্টিমিটার',
      symbol: 'cm',
      dimension: UnitDimension.length,
      group: UnitGroup.length,
      factorToBase: 0.01,
    ),
    UnitDef(
      id: 'm',
      labelEn: 'Metre',
      labelBn: 'মিটার',
      symbol: 'm',
      dimension: UnitDimension.length,
      group: UnitGroup.length,
      factorToBase: 1,
    ),
    UnitDef(
      id: 'km',
      labelEn: 'Kilometre',
      labelBn: 'কিলোমিটার',
      symbol: 'km',
      dimension: UnitDimension.length,
      group: UnitGroup.length,
      factorToBase: 1000,
    ),
    UnitDef(
      id: 'inch',
      labelEn: 'Inch',
      labelBn: 'ইঞ্চি',
      symbol: 'in',
      dimension: UnitDimension.length,
      group: UnitGroup.length,
      factorToBase: _inch,
    ),
    UnitDef(
      id: 'feet',
      labelEn: 'Foot',
      labelBn: 'ফুট',
      symbol: 'ft',
      dimension: UnitDimension.length,
      group: UnitGroup.length,
      factorToBase: _foot,
    ),
    UnitDef(
      id: 'yard',
      labelEn: 'Yard',
      labelBn: 'গজ',
      symbol: 'yd',
      dimension: UnitDimension.length,
      group: UnitGroup.length,
      factorToBase: 0.9144,
    ),
    UnitDef(
      id: 'mile',
      labelEn: 'Mile',
      labelBn: 'মাইল',
      symbol: 'mi',
      dimension: UnitDimension.length,
      group: UnitGroup.length,
      factorToBase: 1609.344,
    ),
    UnitDef(
      id: 'rft',
      labelEn: 'Running foot',
      labelBn: 'রানিং ফুট',
      symbol: 'RFT',
      dimension: UnitDimension.length,
      group: UnitGroup.construction,
      factorToBase: _foot,
    ),
    // Area
    UnitDef(
      id: 'sqmm',
      labelEn: 'Square millimetre',
      labelBn: 'বর্গ মিলিমিটার',
      symbol: 'mm²',
      dimension: UnitDimension.area,
      group: UnitGroup.area,
      factorToBase: 1e-6,
    ),
    UnitDef(
      id: 'sqcm',
      labelEn: 'Square centimetre',
      labelBn: 'বর্গ সেন্টিমিটার',
      symbol: 'cm²',
      dimension: UnitDimension.area,
      group: UnitGroup.area,
      factorToBase: 1e-4,
    ),
    UnitDef(
      id: 'sqm',
      labelEn: 'Square metre',
      labelBn: 'বর্গ মিটার',
      symbol: 'm²',
      dimension: UnitDimension.area,
      group: UnitGroup.area,
      factorToBase: 1,
    ),
    UnitDef(
      id: 'sqkm',
      labelEn: 'Square kilometre',
      labelBn: 'বর্গ কিলোমিটার',
      symbol: 'km²',
      dimension: UnitDimension.area,
      group: UnitGroup.area,
      factorToBase: 1e6,
    ),
    UnitDef(
      id: 'sqin',
      labelEn: 'Square inch',
      labelBn: 'বর্গ ইঞ্চি',
      symbol: 'in²',
      dimension: UnitDimension.area,
      group: UnitGroup.area,
      factorToBase: _inch * _inch,
    ),
    UnitDef(
      id: 'sqft',
      labelEn: 'Square foot',
      labelBn: 'বর্গ ফুট',
      symbol: 'ft²',
      dimension: UnitDimension.area,
      group: UnitGroup.area,
      factorToBase: _squareFoot,
    ),
    UnitDef(
      id: 'sqyd',
      labelEn: 'Square yard',
      labelBn: 'বর্গ গজ',
      symbol: 'yd²',
      dimension: UnitDimension.area,
      group: UnitGroup.area,
      factorToBase: 0.83612736,
    ),
    UnitDef(
      id: 'acre',
      labelEn: 'Acre',
      labelBn: 'একর',
      symbol: 'ac',
      dimension: UnitDimension.area,
      group: UnitGroup.area,
      factorToBase: _acre,
    ),
    UnitDef(
      id: 'decimal',
      labelEn: 'Decimal',
      labelBn: 'ডেসিমল',
      symbol: 'dec',
      dimension: UnitDimension.area,
      group: UnitGroup.land,
      factorToBase: 40.468564224,
    ),
    UnitDef(
      id: 'shotok',
      labelEn: 'Shotok',
      labelBn: 'শতক',
      symbol: 'shotok',
      dimension: UnitDimension.area,
      group: UnitGroup.land,
      factorToBase: 40.468564224,
    ),
    // Volume
    UnitDef(
      id: 'cubicmm',
      labelEn: 'Cubic millimetre',
      labelBn: 'ঘন মিলিমিটার',
      symbol: 'mm³',
      dimension: UnitDimension.volume,
      group: UnitGroup.volume,
      factorToBase: 1e-9,
    ),
    UnitDef(
      id: 'cubiccm',
      labelEn: 'Cubic centimetre',
      labelBn: 'ঘন সেন্টিমিটার',
      symbol: 'cm³',
      dimension: UnitDimension.volume,
      group: UnitGroup.volume,
      factorToBase: 1e-6,
    ),
    UnitDef(
      id: 'cubicm',
      labelEn: 'Cubic metre',
      labelBn: 'ঘন মিটার',
      symbol: 'm³',
      dimension: UnitDimension.volume,
      group: UnitGroup.volume,
      factorToBase: 1,
    ),
    UnitDef(
      id: 'cubicin',
      labelEn: 'Cubic inch',
      labelBn: 'ঘন ইঞ্চি',
      symbol: 'in³',
      dimension: UnitDimension.volume,
      group: UnitGroup.volume,
      factorToBase: 1.6387064e-5,
    ),
    UnitDef(
      id: 'cft',
      labelEn: 'Cubic foot',
      labelBn: 'ঘন ফুট',
      symbol: 'CFT',
      dimension: UnitDimension.volume,
      group: UnitGroup.construction,
      factorToBase: _cubicFoot,
    ),
    UnitDef(
      id: 'liter',
      labelEn: 'Litre',
      labelBn: 'লিটার',
      symbol: 'L',
      dimension: UnitDimension.volume,
      group: UnitGroup.volume,
      factorToBase: 0.001,
    ),
    UnitDef(
      id: 'gallon',
      labelEn: 'US gallon',
      labelBn: 'ইউএস গ্যালন',
      symbol: 'gal',
      dimension: UnitDimension.volume,
      group: UnitGroup.volume,
      factorToBase: 0.003785411784,
    ),
    // Mass
    UnitDef(
      id: 'gram',
      labelEn: 'Gram',
      labelBn: 'গ্রাম',
      symbol: 'g',
      dimension: UnitDimension.mass,
      group: UnitGroup.mass,
      factorToBase: 0.001,
    ),
    UnitDef(
      id: 'kg',
      labelEn: 'Kilogram',
      labelBn: 'কিলোগ্রাম',
      symbol: 'kg',
      dimension: UnitDimension.mass,
      group: UnitGroup.mass,
      factorToBase: 1,
    ),
    UnitDef(
      id: 'tonne',
      labelEn: 'Metric ton',
      labelBn: 'মেট্রিক টন',
      symbol: 't',
      dimension: UnitDimension.mass,
      group: UnitGroup.mass,
      factorToBase: 1000,
    ),
    UnitDef(
      id: 'pound',
      labelEn: 'Pound',
      labelBn: 'পাউন্ড',
      symbol: 'lb',
      dimension: UnitDimension.mass,
      group: UnitGroup.mass,
      factorToBase: 0.45359237,
    ),
  ];

  static Map<String, UnitDef> _landUnits(LandUnitPreset preset) {
    final katha = preset.decimalSquareMetres * preset.kathaInDecimal;
    return {
      'katha': UnitDef(
        id: 'katha',
        labelEn: 'Katha (${preset.labelEn})',
        labelBn: 'কাঠা (${preset.labelBn})',
        symbol: 'katha',
        dimension: UnitDimension.area,
        group: UnitGroup.land,
        factorToBase: katha,
      ),
      'bigha': UnitDef(
        id: 'bigha',
        labelEn: 'Bigha (${preset.labelEn})',
        labelBn: 'বিঘা (${preset.labelBn})',
        symbol: 'bigha',
        dimension: UnitDimension.area,
        group: UnitGroup.land,
        factorToBase: katha * preset.bighaInKatha,
      ),
    };
  }

  UnitDef? find(String id) => _units[id];

  /// All registered units (immutable snapshot) for picker UIs.
  List<UnitDef> get units => List.unmodifiable(_units.values);

  List<UnitDef> unitsIn(UnitGroup group) => _units.values
      .where((unit) => unit.group == group)
      .toList(growable: false);

  /// Converts using SI base units. Throws on unknown or incompatible units.
  double convert(double value, String fromId, String toId) {
    final from = find(fromId);
    final to = find(toId);
    if (from == null) {
      throw UnitConversionException('Unknown source unit: $fromId');
    }
    if (to == null) {
      throw UnitConversionException('Unknown target unit: $toId');
    }
    if (from.dimension != to.dimension) {
      throw UnitConversionException(
        'Incompatible dimensions: ${from.dimension.name} → ${to.dimension.name}',
      );
    }
    if (!value.isFinite) {
      throw const UnitConversionException('Value must be finite.');
    }
    return value * from.factorToBase / to.factorToBase;
  }

  /// Converts and returns an evidence-carrying result for history/reporting.
  CalculationResult<double> convertWithEvidence(
    double value,
    String fromId,
    String toId,
  ) {
    final from = find(fromId);
    final to = find(toId);
    if (from == null || to == null) {
      return CalculationResult.failure([
        ValidationIssue(
          code: 'unknownUnit',
          field: from == null ? 'from' : 'to',
          message: 'Unknown unit: ${from == null ? fromId : toId}',
        ),
      ]);
    }
    if (from.dimension != to.dimension) {
      return CalculationResult.failure([
        const ValidationIssue(
          code: 'dimensionMismatch',
          field: 'to',
          message: 'Cannot convert between different dimensions.',
        ),
      ]);
    }
    return CalculationResult.success(
      convert(value, fromId, toId),
      steps: [
        CalculationStep(
          label: 'SI base value',
          value: value * from.factorToBase,
          unit: _baseUnit(from.dimension),
          formula: 'value × fromFactor',
        ),
        CalculationStep(
          label: 'Target value',
          value: value * from.factorToBase / to.factorToBase,
          unit: to.symbol,
          formula: 'baseValue ÷ toFactor',
        ),
      ],
      formulaIds: const ['units.convert.v1'],
      assumptions: {
        'landPreset': landPreset.id,
        'gallon': 'US liquid gallon',
        'ft': 'international foot = 0.3048 m',
      },
    );
  }

  static String _baseUnit(UnitDimension dimension) => switch (dimension) {
    UnitDimension.length => 'm',
    UnitDimension.area => 'm²',
    UnitDimension.volume => 'm³',
    UnitDimension.mass => 'kg',
  };
}
