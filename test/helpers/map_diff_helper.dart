import 'package:test/test.dart';

/// Recursively compares two serialized maps/lists and fails with the seed,
/// type name, dotted/indexed path of the first differing key, and both values.
void expectMapsEqualWithDiff(
  Map<String, dynamic> actual,
  Map<String, dynamic> expected, {
  required int seed,
  required String typeName,
}) {
  final mismatch = _firstDiff(actual, expected, path: '');
  if (mismatch != null) {
    fail(
      'Seed $seed ($typeName) mismatch at "${mismatch.path}": '
      'expected=${mismatch.expected}, actual=${mismatch.actual}',
    );
  }
}

class _DiffResult {
  final String path;
  final Object? expected;
  final Object? actual;
  const _DiffResult(this.path, this.expected, this.actual);
}

_DiffResult? _firstDiff(
  Object? actual,
  Object? expected, {
  required String path,
}) {
  if (expected is Map && actual is Map) {
    for (final key in expected.keys) {
      final keyPath = path.isEmpty ? '$key' : '$path.$key';
      if (!actual.containsKey(key)) {
        return _DiffResult(keyPath, expected[key], '<missing key>');
      }
      final inner = _firstDiff(actual[key], expected[key], path: keyPath);
      if (inner != null) return inner;
    }
    for (final key in actual.keys) {
      if (!expected.containsKey(key)) {
        final keyPath = path.isEmpty ? '$key' : '$path.$key';
        return _DiffResult(keyPath, '<missing key>', actual[key]);
      }
    }
    return null;
  }

  if (expected is List && actual is List) {
    final lenPath = path.isEmpty ? 'length' : '$path.length';
    if (actual.length != expected.length) {
      return _DiffResult(
        lenPath,
        '${expected.length} ($expected)',
        '${actual.length} ($actual)',
      );
    }
    for (var i = 0; i < expected.length; i++) {
      final elemPath = '$path[$i]';
      final inner = _firstDiff(actual[i], expected[i], path: elemPath);
      if (inner != null) return inner;
    }
    return null;
  }

  if (actual != expected) {
    return _DiffResult(path.isEmpty ? '<root>' : path, expected, actual);
  }
  return null;
}
