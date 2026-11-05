import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LaborPorVoz {
  static const _canal = MethodChannel('i_miner/labor_voz');

  static bool get disponible =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<String> escuchar() async =>
      await _canal.invokeMethod<String>('escuchar') ?? '';

  static Future<void> cancelar() => _canal.invokeMethod<void>('cancelar');

  /// Convierte códigos dictados sin exigir que existan en el catálogo local.
  static String normalizar(String voz) {
    var texto = voz.toLowerCase();
    const acentos = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
    };
    acentos.forEach((a, b) => texto = texto.replaceAll(a, b));
    final palabras = texto.replaceAll(RegExp(r'[^a-zñ0-9]+'), ' ').trim();
    if (palabras.isEmpty) return '';
    final tokens = palabras.split(RegExp(r'\s+'));
    const tipos = {'tajo': 'TJ', 'tj': 'TJ'};
    final salida = <String>[];
    var numeros = <String>[];
    void agregarNumeros() {
      if (numeros.isEmpty) return;
      salida.add(_numero(numeros));
      numeros = [];
    }

    for (final token in tokens) {
      if (_valores.containsKey(token) ||
          RegExp(r'^\d+$').hasMatch(token) ||
          (token == 'y' && numeros.isNotEmpty)) {
        numeros.add(token);
      } else {
        agregarNumeros();
        salida.add(tipos[token] ?? token.toUpperCase());
      }
    }
    agregarNumeros();
    return salida.join('_');
  }

  static const _valores = <String, int>{
    'cero': 0,
    'un': 1,
    'uno': 1,
    'una': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
    'veinte': 20,
    'veintiuno': 21,
    'veintidos': 22,
    'veintitres': 23,
    'veinticuatro': 24,
    'veinticinco': 25,
    'veintiseis': 26,
    'veintisiete': 27,
    'veintiocho': 28,
    'veintinueve': 29,
    'treinta': 30,
    'cuarenta': 40,
    'cincuenta': 50,
    'sesenta': 60,
    'setenta': 70,
    'ochenta': 80,
    'noventa': 90,
    'cien': 100,
    'ciento': 100,
    'doscientos': 200,
    'trescientos': 300,
    'cuatrocientos': 400,
    'quinientos': 500,
    'seiscientos': 600,
    'setecientos': 700,
    'ochocientos': 800,
    'novecientos': 900,
    'mil': 1000,
  };

  static String _numero(List<String> tokens) {
    final grupos = <String>[];
    var actual = 0;
    var tieneActual = false;
    var ultimo = -1;
    for (final token in tokens) {
      if (token == 'y') continue;
      if (RegExp(r'^\d+$').hasMatch(token)) {
        if (tieneActual) grupos.add('$actual');
        grupos.add(
          token,
        ); // Conserva los ceros iniciales dictados como dígitos.
        actual = 0;
        tieneActual = false;
        ultimo = -1;
        continue;
      }
      final valor = _valores[token]!;
      if (valor == 1000) {
        actual = (tieneActual ? actual : 1) * 1000;
      } else if (tieneActual &&
          !((ultimo >= 1000 && valor > 0 && valor < 1000) ||
              (ultimo >= 100 && valor > 0 && valor < 100) ||
              (ultimo >= 20 &&
                  ultimo < 100 &&
                  ultimo % 10 == 0 &&
                  valor > 0 &&
                  valor < 10))) {
        grupos.add('$actual');
        actual = valor;
      } else {
        actual += valor;
      }
      tieneActual = true;
      ultimo = valor;
    }
    if (tieneActual) grupos.add('$actual');
    return grupos.join();
  }
}
