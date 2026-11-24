import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  const calculator = ExpressionCalculator();

  double eval(String expression) {
    final result = calculator.evaluate(expression);
    expect(result.isValid, isTrue, reason: 'Failed: ${result.issues}');
    return result.output!;
  }

  group('arithmetic and precedence', () {
    test('basic operations', () {
      expect(eval('2+3'), 5);
      expect(eval('10-4'), 6);
      expect(eval('6*7'), 42);
      expect(eval('9/2'), 4.5);
    });

    test('precedence and parentheses', () {
      expect(eval('2+3*4'), 14);
      expect(eval('(2+3)*4'), 20);
      expect(eval('100/5/2'), 10);
      expect(eval('2^3^2'), 512);
    });

    test('unary minus and implicit multiplication', () {
      expect(eval('-5+2'), -3);
      expect(eval('3*-2'), -6);
      expect(eval('2(3+4)'), 14);
      expect(eval('-(2+3)'), -5);
    });

    test('percent is postfix divide by 100', () {
      expect(eval('50%'), 0.5);
      expect(eval('200*10%'), 20);
    });

    test('constants', () {
      expect(eval('pi'), closeTo(3.141592653589793, 1e-12));
      expect(eval('2*pi'), closeTo(6.283185307179586, 1e-12));
    });
  });

  group('scientific functions', () {
    test('square root, power, logarithm', () {
      expect(eval('sqrt(16)'), 4);
      expect(eval('2^10'), 1024);
      expect(eval('log(1000)'), closeTo(3, 1e-12));
      expect(eval('ln(e)'), closeTo(1, 1e-12));
    });

    test('trigonometry uses degrees by default', () {
      expect(eval('sin(30)'), closeTo(0.5, 1e-12));
      expect(eval('cos(0)'), 1);
      expect(eval('asin(0.5)'), closeTo(30, 1e-12));
    });

    test('radians mode', () {
      const radians = ExpressionCalculator(degrees: false);
      final result = radians.evaluate('sin(pi/2)');
      expect(result.isValid, isTrue);
      expect(result.output!, closeTo(1, 1e-12));
    });
  });

  group('invalid input', () {
    test('divide by zero is an error, not a crash', () {
      final result = calculator.evaluate('1/0');
      expect(result.isValid, isFalse);
      expect(result.errors.single.code, 'divideByZero');
    });

    test('malformed expressions', () {
      expect(calculator.evaluate('').errors.single.code, 'emptyExpression');
      expect(calculator.evaluate('2+').isValid, isFalse);
      expect(calculator.evaluate('(2+3').isValid, isFalse);
      expect(calculator.evaluate('2+3)').isValid, isFalse);
      expect(calculator.evaluate('foo(2)').isValid, isFalse);
      expect(calculator.evaluate('2\$3').isValid, isFalse);
    });

    test('domain errors', () {
      expect(calculator.evaluate('sqrt(-1)').errors.single.code, 'domainError');
      expect(calculator.evaluate('log(0)').errors.single.code, 'domainError');
    });
  });

  test('evidence includes formula id and assumptions', () {
    final result = calculator.evaluate('1+1');
    expect(result.formulaIds, contains('calculator.expression.v1'));
    expect(result.assumptions['angleUnit'], 'degrees');
  });

  test('memory functions', () {
    final memory = CalculatorMemory();
    memory.store(10);
    memory.add(5);
    memory.subtract(3);
    expect(memory.value, 12);
    memory.clear();
    expect(memory.isEmpty, isTrue);
  });
}
