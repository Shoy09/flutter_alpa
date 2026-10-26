import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/services/user_profile_data.dart';

void main() {
  final cached = <String, dynamic>{
    'codigo_dni': '123',
    'nombres': 'Usuario',
    'autorizado_equipo': 'Equipo A',
    'operaciones_autorizadas': '{"tal_largo":true}',
  };

  test('JWT without permissions preserves cached profile and equipment', () {
    final merged = mergeUserProfile({'codigo_dni': '123'}, cached);
    expect(merged['operaciones_autorizadas'], {'tal_largo': true});
    expect(merged['autorizado_equipo'], 'Equipo A');
    expect(merged['nombres'], 'Usuario');
  });

  test('Server revocations replace cached permissions', () {
    expect(mergeUserProfile({'operaciones_autorizadas': {}}, cached)
        ['operaciones_autorizadas'], isEmpty);
    expect(mergeUserProfile({
      'operaciones_autorizadas': {'tal_largo': false},
    }, cached)['operaciones_autorizadas'], {'tal_largo': false});
  });

  test('API JSON strings and legacy double encoding are decoded', () {
    expect(parseUserOperations(cached['operaciones_autorizadas']),
        {'tal_largo': true});
    expect(parseUserOperations(jsonEncode(cached['operaciones_autorizadas'])),
        {'tal_largo': true});
  });

  test('Missing or invalid permissions cannot silently erase local access', () {
    expect(() => mergeUserProfile({'codigo_dni': '123'}, null),
        throwsFormatException);
    expect(() => mergeUserProfile({'operaciones_autorizadas': 'broken'}, cached),
        throwsFormatException);
    expect(parseUserOperations(cached['operaciones_autorizadas']),
        {'tal_largo': true});
  });
}
