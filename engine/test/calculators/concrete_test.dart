import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  const calculator = ConcreteCalculator();

  ConcreteInput slab({
    ConcreteAssumptions assumptions = const ConcreteAssumptions(),
    MaterialRates rates = const MaterialRates(),
    MixDesign mix = MixDesign.m20,
  }) => ConcreteInput.rectangular(
    element: ConcreteElement.slab,
    lengthM: 10,
    widthM: 10,
    thicknessM: 0.15,
    mix: mix,
    assumptions: assumptions,
    rates: rates,
  );

  group('concrete golden values', () {
    test('15 m³ M20 slab', () {
      final result = calculator.calculate(slab());
      expect(result.isValid, isTrue, reason: '${result.issues}');
      final out = result.output!;
      expect(out.wetVolumeM3, closeTo(15, 1e-9));
      expect(out.dryVolumeM3, closeTo(23.1, 1e-9));
      expect(out.cementVolumeM3, closeTo(4.2, 1e-9));
      expect(out.sandM3, closeTo(6.3, 1e-9));
      expect(out.aggregateM3, closeTo(12.6, 1e-9));
      expect(out.cementKg, closeTo(6048, 1e-9));
      expect(out.cementBags, 121);
      expect(out.waterLitres, closeTo(3024, 1e-9));
      expect(result.formulaIds, contains('concrete.slab.v1'));
    });

    test('waste increases all material quantities', () {
      final withWaste = calculator.calculate(
        slab(assumptions: const ConcreteAssumptions(wastePercent: 10)),
      );
      expect(withWaste.isValid, isTrue);
      final out = withWaste.output!;
      expect(out.cementVolumeM3, closeTo(4.62, 1e-9));
      expect(out.sandM3, closeTo(6.93, 1e-9));
      expect(out.cementBags, 134);
    });

    test('circular column volume uses pi r squared', () {
      final result = calculator.calculate(
        ConcreteInput.circularColumn(diameterM: 0.3, heightM: 3),
      );
      expect(result.isValid, isTrue);
      expect(result.output!.wetVolumeM3, closeTo(0.2120575, 1e-6));
      expect(result.output!.cementBags, 2);
    });

    test('cost uses supplied rates', () {
      final result = calculator.calculate(
        slab(
          rates: const MaterialRates(
            cementPerBagMinor: 50000,
            sandPerM3Minor: 6000,
            aggregatePerM3Minor: 8000,
            waterPerLitreMinor: 2,
          ),
        ),
      );
      expect(result.output!.cost, isNotNull);
      // 121×500.00 + 6.3×60.00 + 12.6×80.00 + 3024×0.02 BDT
      expect(result.output!.cost!.major, closeTo(61946.48, 0.02));
    });

    test('M15 mix design', () {
      final result = calculator.calculate(slab(mix: MixDesign.m15));
      expect(result.output!.sandM3, closeTo(6.6, 1e-9));
      expect(result.output!.aggregateM3, closeTo(13.2, 1e-9));
    });
  });

  group('concrete validation', () {
    test('negative dimensions rejected', () {
      final result = calculator.calculate(
        ConcreteInput.rectangular(
          element: ConcreteElement.beam,
          lengthM: -1,
          widthM: 1,
          thicknessM: 1,
        ),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.map((e) => e.code), contains('notPositive'));
    });

    test('waste above 100 rejected', () {
      final result = calculator.calculate(
        slab(assumptions: const ConcreteAssumptions(wastePercent: 120)),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single.code, 'invalidWaste');
    });
  });
}
