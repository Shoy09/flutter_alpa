import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/services/labor_por_voz.dart';

void main() {
  final casos = {
    'Tajo setecientos treinta': 'TJ_730',
    'Tajo siete treinta': 'TJ_730',
    'Tajo siete tres cero': 'TJ_730',
    'Tajo siete treinta y uno': 'TJ_731',
    'Tajo 730': 'TJ_730',
    'Tajo mil setecientos treinta': 'TJ_1730',
    'TJ_730': 'TJ_730',
    'Tajo cero siete treinta norte': 'TJ_0730_NORTE',
    'Tajo novecientos noventa y nueve sur': 'TJ_999_SUR',
    'Labor nueva 012 este': 'LABOR_NUEVA_012_ESTE',
    '': '',
  };
  for (final caso in casos.entries) {
    test('Dictado: ${caso.key}', () {
      expect(LaborPorVoz.normalizar(caso.key), caso.value);
    });
  }
}
