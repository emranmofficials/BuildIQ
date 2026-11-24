import 'dart:math' as math;

import '../core/result.dart';

enum _TokenType { number, identifier, function, op, lparen, rparen }

class _Token {
  final _TokenType type;
  final String text;
  final double? value;

  const _Token(this.type, this.text, [this.value]);

  @override
  String toString() => text;
}

class CalculationHistoryEntry {
  final String expression;
  final double result;
  final DateTime createdAt;

  const CalculationHistoryEntry(this.expression, this.result, this.createdAt);

  Map<String, dynamic> toJson() => {
    'expression': expression,
    'result': result,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Simple offline calculator memory (M+, M−, MR, MC).
class CalculatorMemory {
  double _value = 0;

  double get value => _value;
  bool get isEmpty => _value == 0;

  void store(double value) => _value = value;
  void clear() => _value = 0;
  void add(double value) => _value += value;
  void subtract(double value) => _value -= value;
}

/// Tokenizer + shunting-yard evaluator with no Flutter/platform dependencies.
class ExpressionCalculator {
  /// When true, sin/cos/tan take degrees and inverse functions return degrees.
  final bool degrees;

  const ExpressionCalculator({this.degrees = true});

  static const _functions = {
    'sin',
    'cos',
    'tan',
    'asin',
    'acos',
    'atan',
    'sqrt',
    'log',
    'ln',
    'abs',
    'round',
    'floor',
    'ceil',
    'exp',
  };
  static const _constants = {'pi': math.pi, 'e': math.e, 'π': math.pi};

  CalculationResult<double> evaluate(String expression) {
    if (expression.trim().isEmpty) {
      return CalculationResult.failure([
        const ValidationIssue(
          code: 'emptyExpression',
          field: 'expression',
          message: 'Expression is empty.',
        ),
      ]);
    }

    final issues = <ValidationIssue>[];
    final tokens = _tokenize(expression, issues);
    if (issues.isNotEmpty) return CalculationResult.failure(issues);

    final rpn = _toRpn(tokens, issues);
    if (issues.isNotEmpty) return CalculationResult.failure(issues);

    final result = _evaluateRpn(rpn, issues);
    if (issues.isNotEmpty) return CalculationResult.failure(issues);

    return CalculationResult.success(
      result,
      formulaIds: const ['calculator.expression.v1'],
      steps: [
        CalculationStep(
          label: 'Infix expression',
          value: double.nan,
          unit: expression,
        ),
        CalculationStep(
          label: 'Reverse Polish form',
          value: double.nan,
          unit: rpn.map((token) => token.text).join(' '),
        ),
      ],
      assumptions: {
        'angleUnit': degrees ? 'degrees' : 'radians',
        'percent': 'postfix percent divides by 100 (50% = 0.5)',
      },
    );
  }

  List<_Token> _tokenize(String source, List<ValidationIssue> issues) {
    final tokens = <_Token>[];
    var i = 0;
    while (i < source.length) {
      final char = source[i];
      if (_isWhitespace(char)) {
        i++;
        continue;
      }
      if (_isDigit(char) || char == '.') {
        final start = i;
        var dots = 0;
        while (i < source.length && (_isDigit(source[i]) || source[i] == '.')) {
          if (source[i] == '.') dots++;
          i++;
        }
        final text = source.substring(start, i);
        if (dots > 1 || text == '.') {
          issues.add(
            ValidationIssue(
              code: 'invalidNumber',
              field: 'expression',
              message: 'Invalid number "$text".',
            ),
          );
          return tokens;
        }
        tokens.add(_Token(_TokenType.number, text, double.tryParse(text)));
        continue;
      }
      if (_isLetter(char) || char == 'π') {
        final start = i;
        while (i < source.length &&
            (_isLetter(source[i]) || _isDigit(source[i]))) {
          i++;
        }
        final text = source.substring(start, i).toLowerCase();
        tokens.add(_Token(_TokenType.identifier, text));
        continue;
      }
      if ('+-*/^%()'.contains(char)) {
        final type = char == '('
            ? _TokenType.lparen
            : char == ')'
            ? _TokenType.rparen
            : _TokenType.op;
        tokens.add(_Token(type, char));
        i++;
        continue;
      }
      issues.add(
        ValidationIssue(
          code: 'unknownCharacter',
          field: 'expression',
          message: 'Unexpected character "$char".',
        ),
      );
      return tokens;
    }
    return tokens;
  }

  List<_Token> _toRpn(List<_Token> tokens, List<ValidationIssue> issues) {
    final output = <_Token>[];
    final operators = <_Token>[];
    var expectOperand = true;
    _Token? previous;

    void addImplicitMultiply() {
      operators.add(const _Token(_TokenType.op, '*'));
    }

    for (final token in tokens) {
      if (token.type == _TokenType.number ||
          (token.type == _TokenType.identifier &&
              _constants.containsKey(token.text))) {
        if (!expectOperand) addImplicitMultiply();
        output.add(token);
        expectOperand = false;
      } else if (token.type == _TokenType.identifier) {
        if (!_functions.contains(token.text)) {
          issues.add(
            ValidationIssue(
              code: 'unknownFunction',
              field: 'expression',
              message: 'Unknown function or constant "${token.text}".',
            ),
          );
          return output;
        }
        if (!expectOperand) addImplicitMultiply();
        operators.add(_Token(_TokenType.function, token.text));
      } else if (token.type == _TokenType.lparen) {
        if (!expectOperand && previous?.type != _TokenType.function) {
          addImplicitMultiply();
        }
        operators.add(token);
        expectOperand = true;
      } else if (token.type == _TokenType.rparen) {
        var found = false;
        while (operators.isNotEmpty) {
          final top = operators.removeLast();
          if (top.type == _TokenType.lparen) {
            found = true;
            break;
          }
          output.add(top);
        }
        if (!found) {
          issues.add(
            const ValidationIssue(
              code: 'unbalancedParentheses',
              field: 'expression',
              message: 'Unmatched closing parenthesis.',
            ),
          );
          return output;
        }
        if (operators.isNotEmpty &&
            operators.last.type == _TokenType.function) {
          output.add(operators.removeLast());
        }
        expectOperand = false;
      } else if (token.type == _TokenType.op) {
        if (token.text == '%') {
          if (expectOperand) {
            issues.add(
              const ValidationIssue(
                code: 'misplacedPercent',
                field: 'expression',
                message: 'Percent must follow a value.',
              ),
            );
            return output;
          }
          output.add(const _Token(_TokenType.op, 'pct'));
          expectOperand = false;
          previous = token;
          continue;
        }

        String op = token.text;
        if ((op == '-' || op == '+') && expectOperand) {
          op = op == '-' ? 'u-' : 'u+';
        } else if (expectOperand) {
          issues.add(
            ValidationIssue(
              code: 'missingOperand',
              field: 'expression',
              message: 'Operator "$op" has no left operand.',
            ),
          );
          return output;
        }

        final precedence = _precedence(op);
        final rightAssoc = op == '^' || op == 'u-' || op == 'u+';
        if (!rightAssoc) {
          while (operators.isNotEmpty &&
              operators.last.type == _TokenType.op &&
              _precedence(operators.last.text) >= precedence) {
            output.add(operators.removeLast());
          }
        } else {
          while (operators.isNotEmpty &&
              operators.last.type == _TokenType.op &&
              _precedence(operators.last.text) > precedence) {
            output.add(operators.removeLast());
          }
        }
        operators.add(_Token(_TokenType.op, op));
        expectOperand = true;
      }
      previous = token;
    }

    if (expectOperand && tokens.isNotEmpty) {
      issues.add(
        const ValidationIssue(
          code: 'incompleteExpression',
          field: 'expression',
          message: 'Expression ends with an operator.',
        ),
      );
      return output;
    }

    while (operators.isNotEmpty) {
      final op = operators.removeLast();
      if (op.type == _TokenType.lparen) {
        issues.add(
          const ValidationIssue(
            code: 'unbalancedParentheses',
            field: 'expression',
            message: 'Unmatched opening parenthesis.',
          ),
        );
        return output;
      }
      output.add(op);
    }
    return output;
  }

  double _evaluateRpn(List<_Token> rpn, List<ValidationIssue> issues) {
    final stack = <double>[];
    for (final token in rpn) {
      if (token.type == _TokenType.number) {
        if (token.value == null) {
          issues.add(
            const ValidationIssue(
              code: 'invalidNumber',
              field: 'expression',
              message: 'Could not parse a number.',
            ),
          );
          return double.nan;
        }
        stack.add(token.value!);
        continue;
      }
      if (token.type == _TokenType.identifier) {
        final constant = _constants[token.text];
        if (constant != null) {
          stack.add(constant);
        } else {
          issues.add(
            ValidationIssue(
              code: 'unknownFunction',
              field: 'expression',
              message: 'Unknown symbol "${token.text}".',
            ),
          );
        }
        continue;
      }
      if (token.type == _TokenType.op) {
        if (token.text == 'u-' || token.text == 'u+' || token.text == 'pct') {
          if (stack.isEmpty) {
            issues.add(
              ValidationIssue(
                code: 'missingOperand',
                field: 'expression',
                message: 'Missing operand for ${token.text}.',
              ),
            );
            return double.nan;
          }
          final value = stack.removeLast();
          stack.add(
            token.text == 'u-'
                ? -value
                : token.text == 'pct'
                ? value / 100
                : value,
          );
          continue;
        }
        if (stack.length < 2) {
          issues.add(
            ValidationIssue(
              code: 'missingOperand',
              field: 'expression',
              message: 'Missing operand for ${token.text}.',
            ),
          );
          return double.nan;
        }
        final b = stack.removeLast();
        final a = stack.removeLast();
        final value = _binary(token.text, a, b, issues);
        if (issues.isNotEmpty) return double.nan;
        stack.add(value);
        continue;
      }
      // Function token
      if (stack.isEmpty) {
        issues.add(
          ValidationIssue(
            code: 'missingOperand',
            field: 'expression',
            message: 'Missing argument for ${token.text}.',
          ),
        );
        return double.nan;
      }
      final value = _applyFunction(token.text, stack.removeLast(), issues);
      if (issues.isNotEmpty) return double.nan;
      stack.add(value);
    }
    if (stack.length != 1) {
      issues.add(
        const ValidationIssue(
          code: 'invalidExpression',
          field: 'expression',
          message: 'Expression did not reduce to a single value.',
        ),
      );
      return double.nan;
    }
    final result = stack.single;
    if (!result.isFinite) {
      issues.add(
        const ValidationIssue(
          code: 'nonFiniteResult',
          field: 'expression',
          message: 'Result is not a finite number.',
        ),
      );
      return double.nan;
    }
    return result;
  }

  double _binary(String op, double a, double b, List<ValidationIssue> issues) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        if (b == 0) {
          issues.add(
            const ValidationIssue(
              code: 'divideByZero',
              field: 'expression',
              message: 'Division by zero is not allowed.',
            ),
          );
          return double.nan;
        }
        return a / b;
      case '^':
        final result = math.pow(a, b).toDouble();
        if (!result.isFinite) {
          issues.add(
            const ValidationIssue(
              code: 'nonFiniteResult',
              field: 'expression',
              message: 'Power result is not finite.',
            ),
          );
        }
        return result;
      default:
        issues.add(
          ValidationIssue(
            code: 'unknownOperator',
            field: 'expression',
            message: 'Unknown operator "$op".',
          ),
        );
        return double.nan;
    }
  }

  double _toRad(double v) => degrees ? v * math.pi / 180 : v;
  double _fromRad(double v) => degrees ? v * 180 / math.pi : v;

  double _applyFunction(
    String name,
    double value,
    List<ValidationIssue> issues,
  ) {
    switch (name) {
      case 'sin':
        return math.sin(_toRad(value));
      case 'cos':
        return math.cos(_toRad(value));
      case 'tan':
        return math.tan(_toRad(value));
      case 'asin':
        if (value < -1 || value > 1) return _domainError(name, issues);
        return _fromRad(math.asin(value));
      case 'acos':
        if (value < -1 || value > 1) return _domainError(name, issues);
        return _fromRad(math.acos(value));
      case 'atan':
        return _fromRad(math.atan(value));
      case 'sqrt':
        if (value < 0) return _domainError(name, issues);
        return math.sqrt(value);
      case 'log':
        if (value <= 0) return _domainError(name, issues);
        return math.log(value) / math.ln10;
      case 'ln':
        if (value <= 0) return _domainError(name, issues);
        return math.log(value);
      case 'abs':
        return value.abs();
      case 'round':
        return value.round().toDouble();
      case 'floor':
        return value.floor().toDouble();
      case 'ceil':
        return value.ceil().toDouble();
      case 'exp':
        return math.exp(value);
      default:
        issues.add(
          ValidationIssue(
            code: 'unknownFunction',
            field: 'expression',
            message: 'Unknown function "$name".',
          ),
        );
        return double.nan;
    }
  }

  double _domainError(String name, List<ValidationIssue> issues) {
    issues.add(
      ValidationIssue(
        code: 'domainError',
        field: 'expression',
        message: '$name is undefined for this input.',
      ),
    );
    return double.nan;
  }

  static int _precedence(String op) => switch (op) {
    'u-' || 'u+' => 5,
    '^' => 4,
    '*' || '/' => 3,
    '+' || '-' => 2,
    'pct' => 6,
    _ => 0,
  };

  static bool _isDigit(String s) =>
      s.codeUnitAt(0) >= 48 && s.codeUnitAt(0) <= 57;
  static bool _isLetter(String s) {
    final code = s.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  static bool _isWhitespace(String s) =>
      s == ' ' || s == '\t' || s == '\n' || s == '\r';
}
