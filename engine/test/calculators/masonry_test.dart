import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  const calculator = BrickCalculator();

  BrickInput wall({double waste = 0}) => BrickInput(
    wallLengthM: 10,
    wallHeightM: 3,
    wallThicknessM: 0.2,
    wastePercent: waste,
  );

  test('10x3x0.2 m wall with standard bricks', () {
    final result = calculator.calculate(wall());
    expect(result.isValid, isTrue, reason: '${result.issues}');
    final out = result.output!;
    expect(out.wallAreaM2, 30);
    expect(out.netWallVolumeM3, closeTo(6, 1e-9));
    expect(out.bricks, 3000);
    expect(out.mortarWetM3, closeTo(1.383, 1e-9));
    expect(out.cementBags, 8);
    expect(out.sandM3, closeTo(1.57662, 1e-9));
  });

  test('waste adds bricks and mortar', () {
    final result = calculator.calculate(wall(waste: 10));
    final out = result.output!;
    expect(out.bricks, 3300);
    expect(out.cementBags, 9);
  });

  test('openings reduce wall volume', () {
    final result = calculator.calculate(
      const BrickInput(
        wallLengthM: 10,
        wallHeightM: 3,
        wallThicknessM: 0.2,
        openingsAreaM2: 4,
      ),
    );
    expect(result.output!.wallAreaM2, 26);
    expect(result.output!.netWallVolumeM3, closeTo(5.2, 1e-9));
  });

  test('openings larger than wall rejected', () {
    final result = calculator.calculate(
      const BrickInput(
        wallLengthM: 2,
        wallHeightM: 2,
        wallThicknessM: 0.2,
        openingsAreaM2: 10,
      ),
    );
    expect(result.isValid, isFalse);
    expect(result.errors.single.code, 'openingsExceedWall');
  });

  test('custom brick size changes count', () {
    final result = calculator.calculate(
      const BrickInput(
        wallLengthM: 10,
        wallHeightM: 3,
        wallThicknessM: 0.2,
        brickLengthMm: 200,
        brickWidthMm: 100,
        brickHeightMm: 100,
        jointMm: 10,
      ),
    );
    expect(result.output!.bricks, lessThan(3000));
  });
}
