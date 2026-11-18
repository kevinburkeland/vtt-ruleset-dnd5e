import 'dart:math';
import 'package:meta/meta.dart';

/// Represents a single signed term in a [DiceExpression].
@immutable
sealed class DiceExpressionTerm {
  final bool isNegative;

  const DiceExpressionTerm({this.isNegative = false});

  /// Formats this term without a sign (e.g. "2d6", "5", "mod").
  String toUnsignedString();

  /// Returns a copy of this term with the specified sign.
  DiceExpressionTerm withNegative(bool negative);
}

/// A dice term representing a roll of [count] dice with [sides] sides.
@immutable
final class DiceRollTerm extends DiceExpressionTerm {
  final int count;
  final int sides;

  const DiceRollTerm({
    required this.count,
    required this.sides,
    super.isNegative,
  });

  DiceRollTerm copyWith({int? count, int? sides, bool? isNegative}) {
    return DiceRollTerm(
      count: count ?? this.count,
      sides: sides ?? this.sides,
      isNegative: isNegative ?? this.isNegative,
    );
  }

  @override
  DiceRollTerm withNegative(bool negative) => copyWith(isNegative: negative);

  @override
  String toUnsignedString() => '${count}d$sides';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiceRollTerm &&
          runtimeType == other.runtimeType &&
          count == other.count &&
          sides == other.sides &&
          isNegative == other.isNegative;

  @override
  int get hashCode => Object.hash(count, sides, isNegative);

  @override
  String toString() => (isNegative ? '-' : '') + toUnsignedString();
}

/// A constant integer modifier term.
@immutable
final class DiceConstantTerm extends DiceExpressionTerm {
  final int value;

  const DiceConstantTerm({
    required this.value,
    super.isNegative,
  });

  DiceConstantTerm copyWith({int? value, bool? isNegative}) {
    return DiceConstantTerm(
      value: value ?? this.value,
      isNegative: isNegative ?? this.isNegative,
    );
  }

  @override
  DiceConstantTerm withNegative(bool negative) => copyWith(isNegative: negative);

  @override
  String toUnsignedString() => '$value';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiceConstantTerm &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          isNegative == other.isNegative;

  @override
  int get hashCode => Object.hash(value, isNegative);

  @override
  String toString() => (isNegative ? '-' : '') + toUnsignedString();
}

/// A term representing the dynamic ability modifier (`mod`).
@immutable
final class DiceModTerm extends DiceExpressionTerm {
  const DiceModTerm({super.isNegative});

  DiceModTerm copyWith({bool? isNegative}) {
    return DiceModTerm(
      isNegative: isNegative ?? this.isNegative,
    );
  }

  @override
  DiceModTerm withNegative(bool negative) => copyWith(isNegative: negative);

  @override
  String toUnsignedString() => 'mod';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiceModTerm &&
          runtimeType == other.runtimeType &&
          isNegative == other.isNegative;

  @override
  int get hashCode => Object.hash(runtimeType, isNegative);

  @override
  String toString() => (isNegative ? '-' : '') + toUnsignedString();
}

/// An immutable, ordered list of signed terms parsed from a standard tabletop dice expression.
@immutable
class DiceExpression {
  final List<DiceExpressionTerm> terms;

  const DiceExpression(this.terms);

  /// All terms that represent dice rolls (e.g. 2d6).
  ///
  /// Used by: `character_sheet_controller.dart`, `homebrew_persistence_service.dart`,
  /// `monster_codex_data.dart`, `stat_block_acl_parser.dart`.
  List<DiceRollTerm> get diceTerms => terms.whereType<DiceRollTerm>().toList();

  /// The net sum of all constant terms in this expression.
  ///
  /// Used by: `character_sheet_controller.dart`, `monster_codex_data.dart`,
  /// `stat_block_acl_parser.dart`, `homebrew_persistence_service.dart`.
  int get constantSum => terms.whereType<DiceConstantTerm>().fold(
      0, (sum, t) => sum + (t.isNegative ? -t.value : t.value));

  /// The largest number of sides among all dice terms, or 0 if none.
  ///
  /// Used by: `monster_codex_data.dart`, `homebrew_persistence_service.dart`.
  int get largestDie =>
      diceTerms.isEmpty ? 0 : diceTerms.map((t) => t.sides).reduce(max);

  /// The total count of all dice in this expression.
  ///
  /// Used by: `monster_codex_data.dart`, `homebrew_persistence_service.dart`.
  int get totalDiceCount => diceTerms.fold(0, (sum, t) => sum + t.count);

  /// Whether this expression contains at least one dice roll term.
  ///
  /// Used by: `homebrew_other_category.dart`, `ingestion_field_descriptor.dart`.
  bool get hasDice => diceTerms.isNotEmpty;

  /// Returns the sole [DiceRollTerm] if and only if this expression contains
  /// exactly one dice group and it is non-negative (`!isNegative`), otherwise `null`.
  ///
  /// Used by: `dnd5e_class_field_extractor.dart`, `dnd5e_ingestion_capability.dart`,
  /// `stat_block_acl_parser.dart`, `dpr_models.dart`, `monster_codex_data.dart`.
  DiceRollTerm? get singleDieGroup {
    final dt = diceTerms;
    if (dt.length != 1) return null;
    final only = dt.first;
    return only.isNegative ? null : only;
  }

  /// Formats terms in canonical order joined by ` + ` or ` - `, dice as `NdS`, `mod` as `mod`,
  /// and a negative first term with a leading `-` and no space.
  String format() {
    if (terms.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < terms.length; i++) {
      final term = terms[i];
      if (i == 0) {
        if (term.isNegative) {
          buffer.write('-');
        }
        buffer.write(term.toUnsignedString());
      } else {
        if (term.isNegative) {
          buffer.write(' - ');
        } else {
          buffer.write(' + ');
        }
        buffer.write(term.toUnsignedString());
      }
    }
    return buffer.toString();
  }

  /// Parses a tabletop dice formula according to the grammar:
  /// `['-'] term (('+' | '-') term)*`
  /// Throws [FormatException] if the input cannot be strictly parsed.
  static DiceExpression parse(String input) {
    int pos = 0;
    final len = input.length;

    void skipWhitespace() {
      while (pos < len && (input[pos] == ' ' || input[pos] == '\t')) {
        pos++;
      }
    }

    skipWhitespace();
    if (pos >= len) {
      throw FormatException('Expression cannot be empty or blank', input, 0);
    }

    bool firstIsNegative = false;
    if (input[pos] == '+') {
      throw FormatException('Leading "+" is not allowed', input, pos);
    } else if (input[pos] == '-') {
      firstIsNegative = true;
      pos++;
      skipWhitespace();
      if (pos >= len) {
        throw FormatException('Trailing "-" without a term', input, pos);
      }
      if (input[pos] == '+' || input[pos] == '-') {
        throw FormatException('Doubled sign', input, pos);
      }
    }

    bool isDigit(String c) {
      final code = c.codeUnitAt(0);
      return code >= 48 && code <= 57;
    }

    bool isAlphanumeric(String c) {
      final code = c.codeUnitAt(0);
      return (code >= 48 && code <= 57) ||
          (code >= 65 && code <= 90) ||
          (code >= 97 && code <= 122);
    }

    DiceExpressionTerm parseTerm(bool isNegative) {
      skipWhitespace();
      if (pos >= len) {
        throw FormatException('Expected a term', input, pos);
      }

      final startPos = pos;
      final char = input[pos];

      // Case A: mod (case insensitive)
      if ((char == 'm' || char == 'M') &&
          pos + 2 < len &&
          (input[pos + 1] == 'o' || input[pos + 1] == 'O') &&
          (input[pos + 2] == 'd' || input[pos + 2] == 'D')) {
        pos += 3;
        if (pos < len) {
          final next = input[pos];
          if (isAlphanumeric(next) || next == '_' || next == '.') {
            throw FormatException(
                'Invalid token starting with "mod"', input, startPos);
          }
        }
        return DiceModTerm(isNegative: isNegative);
      }

      // Case B: starts with 'd' or 'D' (implicit count 1)
      if (char == 'd' || char == 'D') {
        pos++;
        if (pos >= len || !isDigit(input[pos])) {
          throw FormatException(
              'Dice term missing sides after "d"', input, pos);
        }
        final sidesStart = pos;
        while (pos < len && isDigit(input[pos])) {
          pos++;
        }
        if (pos < len && (isAlphanumeric(input[pos]) || input[pos] == '.')) {
          throw FormatException(
              'Invalid character after dice sides', input, pos);
        }
        final sidesStr = input.substring(sidesStart, pos);
        final sides = int.parse(sidesStr);
        if (sides < 1 || sides > 1000) {
          throw FormatException(
              'Sides must be between 1 and 1000, got $sides',
              input,
              sidesStart);
        }
        return DiceRollTerm(count: 1, sides: sides, isNegative: isNegative);
      }

      // Case C: starts with digit
      if (isDigit(char)) {
        final numStart = pos;
        while (pos < len && isDigit(input[pos])) {
          pos++;
        }
        if (pos < len && input[pos] == '.') {
          throw FormatException('Decimals are not allowed', input, pos);
        }
        if (pos < len && (input[pos] == 'd' || input[pos] == 'D')) {
          // Dice term NdS
          final countStr = input.substring(numStart, pos);
          final count = int.parse(countStr);
          if (count < 1 || count > 999) {
            throw FormatException(
                'Dice count must be between 1 and 999, got $count',
                input,
                numStart);
          }
          pos++; // skip 'd'
          if (pos >= len || !isDigit(input[pos])) {
            throw FormatException(
                'Dice term missing sides after "d"', input, pos);
          }
          final sidesStart = pos;
          while (pos < len && isDigit(input[pos])) {
            pos++;
          }
          if (pos < len && (isAlphanumeric(input[pos]) || input[pos] == '.')) {
            throw FormatException(
                'Invalid character after dice sides', input, pos);
          }
          final sidesStr = input.substring(sidesStart, pos);
          final sides = int.parse(sidesStr);
          if (sides < 1 || sides > 1000) {
            throw FormatException(
                'Sides must be between 1 and 1000, got $sides',
                input,
                sidesStart);
          }
          return DiceRollTerm(count: count, sides: sides, isNegative: isNegative);
        } else {
          // Constant term
          if (pos < len && (isAlphanumeric(input[pos]) || input[pos] == '.')) {
            throw FormatException(
                'Invalid character after number', input, pos);
          }
          final valStr = input.substring(numStart, pos);
          final val = int.parse(valStr);
          if (val < 0 || val > 9999) {
            throw FormatException(
                'Constant must be between 0 and 9999, got $val',
                input,
                numStart);
          }
          return DiceConstantTerm(value: val, isNegative: isNegative);
        }
      }

      throw FormatException('Unexpected character "${input[pos]}"', input, pos);
    }

    final terms = <DiceExpressionTerm>[];
    terms.add(parseTerm(firstIsNegative));

    while (true) {
      skipWhitespace();
      if (pos >= len) break;
      final opChar = input[pos];
      bool nextIsNegative;
      if (opChar == '+') {
        nextIsNegative = false;
        pos++;
      } else if (opChar == '-') {
        nextIsNegative = true;
        pos++;
      } else {
        throw FormatException(
            'Expected "+" or "-", found "$opChar"', input, pos);
      }

      skipWhitespace();
      if (pos >= len) {
        throw FormatException('Trailing operator without a term', input, pos);
      }
      if (input[pos] == '+' || input[pos] == '-') {
        throw FormatException('Doubled operator', input, pos);
      }

      terms.add(parseTerm(nextIsNegative));
    }

    return DiceExpression(List.unmodifiable(terms));
  }

  /// Parses a tabletop dice formula according to the grammar.
  /// Returns `null` instead of throwing [FormatException] if the input cannot be strictly parsed.
  static DiceExpression? tryParse(String input) {
    try {
      return parse(input);
    } on FormatException {
      return null;
    }
  }

  /// Scans [text] and returns all longest runs of text that [parse] accepts and
  /// that contain at least one dice term ([DiceRollTerm]).
  static List<DiceMatch> findAll(String text) {
    final matches = <DiceMatch>[];
    int pos = 0;
    final len = text.length;

    bool isDigit(int code) => code >= 48 && code <= 57;
    bool isLetter(int code) =>
        (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    bool isAlphanumericCode(int code) => isDigit(code) || isLetter(code);

    while (pos < len) {
      final code = text.codeUnitAt(pos);

      // A candidate match cannot begin immediately inside an alphanumeric word
      if (pos > 0 && isAlphanumericCode(text.codeUnitAt(pos - 1))) {
        pos++;
        continue;
      }

      // Check if current character can start an expression:
      // Can be: digit, 'd'/'D' (if followed by digit), or '-' (if followed by digit or 'd'/'D')
      bool canStart = false;
      if (isDigit(code)) {
        canStart = true;
      } else if (code == 100 || code == 68) { // 'd' or 'D'
        if (pos + 1 < len && isDigit(text.codeUnitAt(pos + 1))) {
          canStart = true;
        }
      } else if (code == 45) { // '-'
        int next = pos + 1;
        while (next < len && (text.codeUnitAt(next) == 32 || text.codeUnitAt(next) == 9)) {
          next++;
        }
        if (next < len) {
          final nextCode = text.codeUnitAt(next);
          if (isDigit(nextCode) ||
              ((nextCode == 100 || nextCode == 68) &&
                  next + 1 < len &&
                  isDigit(text.codeUnitAt(next + 1)))) {
            canStart = true;
          }
        }
      }

      if (!canStart) {
        pos++;
        continue;
      }

      // Scan forward while characters belong to the allowed dice expression alphabet:
      // digits, d/D, +, -, spaces, tabs, m/M, o/O
      int scanEnd = pos;
      while (scanEnd < len) {
        final c = text.codeUnitAt(scanEnd);
        if (isDigit(c) ||
            c == 100 || c == 68 || // d, D
            c == 43 || c == 45 || // +, -
            c == 32 || c == 9 ||  // space, tab
            c == 109 || c == 77 || // m, M
            c == 111 || c == 79) { // o, O
          scanEnd++;
        } else {
          break;
        }
      }

      // Search for the longest candidate substring from scanEnd down to pos+1
      DiceMatch? bestMatch;
      for (int end = scanEnd; end > pos; end--) {
        final lastChar = text.codeUnitAt(end - 1);
        // An expression can only end on a digit or 'd'/'D' (from mod)
        if (!isDigit(lastChar) && lastChar != 100 && lastChar != 68) {
          continue;
        }
        // If end < len, text[end] cannot be alphanumeric (cannot end in the middle of a word)
        if (end < len && isAlphanumericCode(text.codeUnitAt(end))) {
          continue;
        }

        final candidate = text.substring(pos, end);
        final expr = tryParse(candidate);
        if (expr != null && expr.diceTerms.isNotEmpty) {
          bestMatch = DiceMatch(
            start: pos,
            end: end,
            expression: expr,
          );
          break;
        }
      }

      if (bestMatch != null) {
        matches.add(bestMatch);
        pos = bestMatch.end;
      } else {
        pos++;
      }
    }

    return List.unmodifiable(matches);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DiceExpression) return false;
    if (terms.length != other.terms.length) return false;
    for (var i = 0; i < terms.length; i++) {
      if (terms[i] != other.terms[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(terms);

  @override
  String toString() => format();
}

/// A match produced by [DiceExpression.findAll] within a source text.
@immutable
class DiceMatch {
  /// The inclusive start character index of this match in the source text.
  final int start;

  /// The exclusive end character index of this match in the source text.
  final int end;

  /// The parsed [DiceExpression] corresponding to `text.substring(start, end)`.
  final DiceExpression expression;

  const DiceMatch({
    required this.start,
    required this.end,
    required this.expression,
  });

  /// Returns the matched slice of [source].
  String text(String source) => source.substring(start, end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiceMatch &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          expression == other.expression;

  @override
  int get hashCode => Object.hash(start, end, expression);

  @override
  String toString() => 'DiceMatch($start..$end: $expression)';
}
