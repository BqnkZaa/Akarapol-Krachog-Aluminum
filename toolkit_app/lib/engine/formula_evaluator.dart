class FormulaEvaluationResult {
  final bool isSiteMeasured;
  final double? valueMm;
  final double? estimatedMm;

  const FormulaEvaluationResult({
    required this.isSiteMeasured,
    this.valueMm,
    this.estimatedMm,
  });
}

class FormulaEvaluator {
  FormulaEvaluator._();

  static String formatMm(double val) {
    final rounded = (val * 10.0).round() / 10.0;
    if ((rounded - rounded.roundToDouble()).abs() < 1e-6) {
      return rounded.round().toString();
    }
    return rounded.toStringAsFixed(1);
  }

  static FormulaEvaluationResult evaluate(
    String rawFormula,
    Map<String, double> vars, {
    bool floorDivision = false,
  }) {
    final trimmed = rawFormula.trim();
    if (trimmed.isEmpty || trimmed.contains('วัดตามจริง')) {
      double? est;
      final estMatch = RegExp(r'ประมาณการรวม\s*([^)]+)\)').firstMatch(trimmed);
      if (estMatch != null) {
        est = _tryEvalNumeric(estMatch.group(1)!, vars);
      }
      return FormulaEvaluationResult(isSiteMeasured: true, estimatedMm: est);
    }

    // Strip "(ค่าคงที่)" suffix if present (e.g. "95 (ค่าคงที่)")
    final cleaned = trimmed.replaceAll(RegExp(r'\s*\(ค่าคงที่\)\s*'), '').trim();
    final rawVal = _tryEvalNumeric(cleaned, vars);
    if (rawVal == null) {
      return const FormulaEvaluationResult(isSiteMeasured: true);
    }

    final finalVal = floorDivision
        ? rawVal.floorToDouble()
        : ((rawVal * 10.0).round() / 10.0);

    return FormulaEvaluationResult(
      isSiteMeasured: false,
      valueMm: finalVal,
    );
  }

  static double evaluateNumber(
    String rawFormula,
    Map<String, double> vars, {
    bool floorDivision = false,
  }) {
    final res = evaluate(rawFormula, vars, floorDivision: floorDivision);
    return res.valueMm ?? 0.0;
  }

  static double? _tryEvalNumeric(String expr, Map<String, double> vars) {
    try {
      final parser = _ExprParser(expr, vars);
      final v = parser.parseExpression();
      parser.skipWhitespace();
      if (!parser.isAtEnd) return null;
      if (v.isNaN || v.isInfinite) return null;
      return v;
    } catch (_) {
      return null;
    }
  }
}

class _ExprParser {
  final String src;
  final Map<String, double> vars;
  int pos = 0;

  _ExprParser(this.src, this.vars);

  bool get isAtEnd => pos >= src.length;

  void skipWhitespace() {
    while (pos < src.length && (src[pos] == ' ' || src[pos] == '\t')) {
      pos++;
    }
  }

  double parseExpression() {
    var left = parseTerm();
    while (true) {
      skipWhitespace();
      if (pos < src.length && (src[pos] == '+' || src[pos] == '−' || src[pos] == '-')) {
        final op = src[pos];
        pos++;
        final right = parseTerm();
        left = op == '+' ? (left + right) : (left - right);
      } else {
        break;
      }
    }
    return left;
  }

  double parseTerm() {
    var left = parseFactor();
    while (true) {
      skipWhitespace();
      if (pos < src.length && (src[pos] == '*' || src[pos] == '×' || src[pos] == '/')) {
        final op = src[pos];
        pos++;
        final right = parseFactor();
        left = op == '/' ? (left / right) : (left * right);
      } else {
        break;
      }
    }
    return left;
  }

  double parseFactor() {
    skipWhitespace();
    if (pos >= src.length) {
      throw const FormatException('Unexpected end of expression');
    }

    if (src[pos] == '+' || src[pos] == '-' || src[pos] == '−') {
      final neg = src[pos] != '+';
      pos++;
      final v = parseFactor();
      return neg ? -v : v;
    }

    if (src[pos] == '(') {
      pos++;
      final val = parseExpression();
      skipWhitespace();
      if (pos >= src.length || src[pos] != ')') {
        throw const FormatException('Missing closing parenthesis');
      }
      pos++;
      return val;
    }

    final start = pos;
    // Number literal
    if (_isDigit(src[pos]) || src[pos] == '.') {
      while (pos < src.length && (_isDigit(src[pos]) || src[pos] == '.')) {
        pos++;
      }
      return double.parse(src.substring(start, pos));
    }

    // Variable identifier (e.g. W, H, H1, H_t, W1, W2, W_f, N, SashW, SashH)
    if (_isIdentStart(src[pos])) {
      while (pos < src.length && _isIdentPart(src[pos])) {
        pos++;
      }
      final name = src.substring(start, pos);
      if (!vars.containsKey(name)) {
        throw FormatException('Unknown variable: $name');
      }
      return vars[name]!;
    }

    throw FormatException('Unexpected character at $pos: ${src[pos]}');
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  bool _isIdentStart(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || c == '_';
  }

  bool _isIdentPart(String c) => _isIdentStart(c) || _isDigit(c);
}
