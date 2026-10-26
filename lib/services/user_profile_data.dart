import 'dart:convert';

/// Accepts both API objects and JSON stored in SQLite, including older
/// records that were encoded twice. Invalid data must never replace the cache.
Map<String, dynamic> parseUserOperations(dynamic value) {
  for (var depth = 0; depth < 2 && value is String; depth++) {
    value = jsonDecode(value);
  }
  if (value is! Map) {
    throw const FormatException('Permisos de operaciones no disponibles');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> mergeUserProfile(
  Map<String, dynamic> incoming,
  Map<String, dynamic>? cached,
) {
  final merged = <String, dynamic>{...?cached};
  for (final entry in incoming.entries) {
    if (entry.value != null) merged[entry.key] = entry.value;
  }
  // An explicit empty map is authoritative (permissions revoked).
  merged['operaciones_autorizadas'] = parseUserOperations(
    incoming['operaciones_autorizadas'] ?? cached?['operaciones_autorizadas'],
  );
  return merged;
}
