import 'package:flutter_test/flutter_test.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/core/transfer/transfer_content.dart';
import 'package:i_miner/services/envio%20nube/largo/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/horizontal/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Sostenimiento/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Carguio/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Rompebancos/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/SCISSOR/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/AnfoChanger/exportar_service.dart';
import 'package:i_miner/services/envio%20nube/Scalamin/ExportarScalaminService.dart';
import 'package:i_miner/services/envio%20nube/Dumper/ExportarDumperService.dart';
import 'package:i_miner/services/envio%20nube/Volquetes/exportar_service.dart';

void main() {
  final helper = DatabaseHelper();
  final exporters = <String, dynamic>{
    'tal_largo': ExportarService(helper),
    'tal_horizontal': ExportarHorizontalService(helper),
    'empernador': ExportarEmpernadorService(helper),
    'carguio': ExportarCarguioService(helper),
    'rompebanco': ExportarRompebancoService(helper),
    'scissor': ExportarScissorService(helper),
    'anfochanger': ExportarAnfoChangerService(helper),
    'scalamin': ExportarScalaminService(helper),
    'dumper': ExportarDumperService(helper),
    'volquetes': ExportarVolquetesService(helper),
  };
  for (final entry in exporters.entries) {
    test(
      '${entry.key}: actual exporter satisfies full transfer contract',
      () async {
        final input = <String, dynamic>{
          'id': 1,
          'idNube': 0,
          'sync_uuid': 'c734e68b-9fad-4f42-9711-920cc2d4b84e',
          'estado': 'cerrado',
          'envio': 0,
          'operador': 'PRUEBA',
          'registros': '[{"horas":3.5}]',
          'horometros': '{"inicio":10}',
          'condiciones_equipo': '{}',
          'control_llantas': '{}',
          'check_list': '[]',
          'check_list_telemando': '[]',
          'programa_trabajo': '{}',
          'tipo_equipo': '{}',
        };
        final payload = Map<String, dynamic>.from(
          (await entry.value.prepararDatosParaExportar({1}, [input]) as List)
                  .single
              as Map,
        );
        final content = TransferContent.content(entry.key, payload);
        expect(content.keys, containsAll(TransferContent.fields(entry.key)));
        expect(content['registros'], [
          {'horas': 3.5},
        ]);
        expect(content['operador'], 'PRUEBA');
        expect(content.containsKey('check_list_telemando'), isFalse);
        expect(content.containsKey('Hora_envio'), isFalse);
        expect(content.containsKey('idNube'), isFalse);
        expect(
          TransferContent.fingerprint(entry.key, payload),
          matches(RegExp(r'^[0-9a-f]{64}$')),
        );
      },
    );
  }
}
