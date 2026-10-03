/// Helpers de parseo JSON tolerantes a `null` y a tipos dinámicos.
///
/// Se usan tanto en el backend como en la app para mantener DTOs robustos.
library;

String jsonString(Map<String, dynamic> json, String key, {String? fallback}) {
  final value = json[key];
  if (value == null) {
    if (fallback != null) return fallback;
    throw JsonFieldException(key, 'requerido');
  }
  return value.toString();
}

String? jsonStringOrNull(Map<String, dynamic> json, String key) =>
    json[key]?.toString();

int jsonInt(Map<String, dynamic> json, String key, {int? fallback}) {
  final value = json[key];
  if (value == null) {
    if (fallback != null) return fallback;
    throw JsonFieldException(key, 'requerido');
  }
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse(value.toString());
}

int? jsonIntOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double jsonDouble(Map<String, dynamic> json, String key, {double? fallback}) {
  final value = json[key];
  if (value == null) {
    if (fallback != null) return fallback;
    throw JsonFieldException(key, 'requerido');
  }
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}

bool jsonBool(Map<String, dynamic> json, String key, {bool fallback = false}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is bool) return value;
  return value.toString().toLowerCase() == 'true';
}

DateTime jsonDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) throw JsonFieldException(key, 'requerido');
  return DateTime.parse(value.toString()).toLocal();
}

DateTime? jsonDateOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

Map<String, dynamic> jsonMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map<dynamic, dynamic>) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<Map<String, dynamic>> jsonList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List<dynamic>) {
    return value
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }
  return const [];
}

/// Error de parseo que identifica el campo problemático.
class JsonFieldException implements Exception {
  JsonFieldException(this.field, this.reason);

  final String field;
  final String reason;

  @override
  String toString() => 'JsonFieldException($field: $reason)';
}
