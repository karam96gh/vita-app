import 'dart:convert';
import '../errors/api_failure.dart';

/// Explicit integration mapping for response shapes absent from the supplied
/// contract. Keys are internal model names; values are confirmed JSON pointers.
/// No guessed wire-field aliases or permissive shape fallbacks are used.
class PatientContract {
  PatientContract(this.paths);
  factory PatientContract.fromEnvironment() {
    const source = String.fromEnvironment('PATIENT_SCHEMA', defaultValue: '{}');
    return PatientContract(Map<String, String>.from(jsonDecode(source) as Map));
  }
  final Map<String, String> paths;

  Object? value(Object? json, String key) {
    if (!paths.containsKey(key)) throw const ApiFailure('CONTRACT_REQUIRED');
    final pointer = paths[key]!;
    if (pointer.isEmpty) return json;
    if (!pointer.startsWith('/')) throw const ApiFailure('INVALID_RESPONSE');
    Object? current = json;
    for (final raw in pointer.substring(1).split('/')) {
      final part = raw.replaceAll('~1', '/').replaceAll('~0', '~');
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        throw const ApiFailure('INVALID_RESPONSE');
      }
    }
    return current;
  }

  String text(Object? json, String key) {
    final result = value(json, key);
    if (result is! String) throw const ApiFailure('INVALID_RESPONSE');
    return result;
  }

  String? optionalText(Object? json, String key) {
    if (!paths.containsKey(key)) return null;
    final result = value(json, key);
    if (result != null && result is! String) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    return result as String?;
  }

  bool flag(Object? json, String key) {
    final result = value(json, key);
    if (result is! bool) throw const ApiFailure('INVALID_RESPONSE');
    return result;
  }

  int count(Object? json, String key) {
    final result = value(json, key);
    if (result is! int || result < 0) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    return result;
  }

  List<Object?> list(Object? json, String key) {
    final result = value(json, key);
    if (result is! List) throw const ApiFailure('INVALID_RESPONSE');
    return result.cast<Object?>();
  }
}
