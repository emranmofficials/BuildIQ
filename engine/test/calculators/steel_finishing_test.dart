import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('steel and rebar', () {
    const calculator = RebarCalculator();

    test('unit weight formulas', () {
      expect(RebarCalculator.roundBarUnitWeight(12), closeTo(0.8888889, 1e-6));
      expect(RebarCalculator.roundBarUnitWeight(20), closeTo(2.4691358, 1e-6));
      expect(RebarCalculator.squareBarUnitWeight(12), closeTo(1.1304, 1e-4));
    });

    test('bars, cutting length and weight', () {
      final result = calculator.calculate(
        const RebarInput(
          diameterMm: 12,
          memberLengthM: 5,
          spacingMm: 150,
          spanMm: 3000,
          coverMm: 40,
        ),
      );
      expect(result.isValid, isTrue, reason: '${result.issues}');
      final out = result.output!;
      expect(out.bars, 21);
      expect(out.cuttingLengthM, closeTo(4.92, 1e-9));
      expect(out.totalLengthM, closeTo(103.32, 1e-9));
      expect(out.totalWeightKg, closeTo(91.84, 1e-3));
    });

    test('waste and cost', () {
      final result = calculator.calculate(
        const RebarInput(
          diameterMm: 12,
          memberLengthM: 5,
          spacingMm: 150,
          spanMm: 3000,
          wastePercent: 5,
          ratePerKgMinor: 10000,
        ),
      );
      expect(result.output!.totalWeightKg, closeTo(96.432, 1e-3));
      expect(result.output!.cost!.major, closeTo(9643.2, 0.02));
    });

    test('cover larger than member rejected', () {
      final result = calculator.calculate(
        const RebarInput(
          diameterMm: 12,
          memberLengthM: 0.05,
          spacingMm: 150,
          spanMm: 3000,
          coverMm: 40,
        ),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single.code, 'negativeCuttingLength');
    });
  });

  group('finishing', () {
    const finishing = FinishingCalculator();

    test('plaster 100 m² 12 mm 1:4', () {
      final result = finishing.plaster(areaM2: 100, thicknessMm: 12);
      expect(result.isValid, isTrue);
      final materials = result.output!.materials;
      expect(materials[0].quantity, 10);
      expect(materials[1].quantity, closeTo(1.2768, 1e-9));
    });

    test('paint two coats', () {
      final result = finishing.liquidCoating(
        item: 'Paint',
        areaM2: 100,
        coverageM2PerLitre: 10,
        coats: 2,
        wastePercent: 10,
      );
      expect(result.output!.materials.single.quantity, closeTo(22, 1e-9));
    });

    test('tiles round up', () {
      final result = finishing.tiles(
        areaM2: 20,
        tileLengthMm: 300,
        tileWidthMm: 300,
      );
      expect(result.output!.materials.first.quantity, 223);
    });

    test('invalid coverage rejected', () {
      final result = finishing.liquidCoating(
        item: 'Paint',
        areaM2: 100,
        coverageM2PerLitre: 0,
        coats: 1,
      );
      expect(result.isValid, isFalse);
    });
  });
}
