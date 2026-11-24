import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  final registry = UnitRegistry();

  group('length conversions', () {
    test('metre to feet and back', () {
      expect(registry.convert(1, 'm', 'feet'), closeTo(3.280839895, 1e-9));
      expect(
        registry.convert(registry.convert(12, 'feet', 'm'), 'm', 'feet'),
        closeTo(12, 1e-9),
      );
    });

    test('inch and millimetre', () {
      expect(registry.convert(1, 'inch', 'mm'), closeTo(25.4, 1e-9));
      expect(registry.convert(1000, 'mm', 'm'), closeTo(1, 1e-12));
    });

    test('running foot is a length alias', () {
      expect(registry.convert(10, 'rft', 'm'), closeTo(3.048, 1e-12));
    });
  });

  group('area conversions', () {
    test('square metre to square foot uses squared factor', () {
      expect(registry.convert(1, 'sqm', 'sqft'), closeTo(10.763910417, 1e-8));
    });

    test('acre to decimal', () {
      expect(registry.convert(1, 'acre', 'decimal'), closeTo(100, 1e-9));
    });
  });

  group('volume conversions', () {
    test('cubic metre to cubic feet', () {
      expect(registry.convert(1, 'cubicm', 'cft'), closeTo(35.3146667, 1e-6));
    });

    test('litre to cubic metre', () {
      expect(registry.convert(1000, 'liter', 'cubicm'), closeTo(1, 1e-12));
    });
  });

  group('mass conversions', () {
    test('kilogram to pound', () {
      expect(registry.convert(1, 'kg', 'pound'), closeTo(2.20462262, 1e-7));
    });
  });

  group('regional land units', () {
    test('Bangladesh preset: 1 bigha = 20 katha', () {
      expect(registry.convert(20, 'katha', 'bigha'), closeTo(1, 1e-12));
    });

    test('Bangladesh preset: 1 katha is about 718.7 sq ft', () {
      expect(registry.convert(1, 'katha', 'sqft'), closeTo(718.74, 0.02));
    });

    test('preset changes katha factor', () {
      const custom = LandUnitPreset(
        id: 'custom',
        labelEn: 'Custom',
        labelBn: 'কাস্টম',
        decimalSquareMetres: 40.468564224,
        kathaInDecimal: 2.0,
        bighaInKatha: 16,
      );
      final customRegistry = UnitRegistry(preset: custom);
      expect(customRegistry.convert(1, 'katha', 'sqft'), closeTo(871.2, 1e-2));
      expect(customRegistry.convert(1, 'bigha', 'katha'), closeTo(16, 1e-12));
    });
  });

  group('error handling', () {
    test('unknown unit fails with evidence', () {
      final result = registry.convertWithEvidence(1, 'm', 'parsec');
      expect(result.isValid, isFalse);
      expect(result.errors.single.code, 'unknownUnit');
    });

    test('dimension mismatch fails with evidence', () {
      final result = registry.convertWithEvidence(1, 'm', 'kg');
      expect(result.isValid, isFalse);
      expect(result.errors.single.code, 'dimensionMismatch');
    });

    test('convert throws for incompatible units', () {
      expect(
        () => registry.convert(1, 'm', 'liter'),
        throwsA(isA<UnitConversionException>()),
      );
    });
  });

  test('evidence includes steps and assumptions', () {
    final result = registry.convertWithEvidence(1, 'm', 'feet');
    expect(result.isValid, isTrue);
    expect(result.steps, hasLength(2));
    expect(result.assumptions['gallon'], 'US liquid gallon');
  });
}
