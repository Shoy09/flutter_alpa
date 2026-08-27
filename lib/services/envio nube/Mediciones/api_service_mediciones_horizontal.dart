import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';

class ApiServiceMedicionesHorizontal {
  Future<bool> postMedicionHorizontal(Map<String, dynamic> medicionData) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.medicionesHorizontalEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(medicionData), // Ya viene como Map correcto
      );

      if (response.statusCode == 201) {
        print('✅ Medición Horizontal creada con éxito.');
        return true;
      } else if (response.statusCode == 409) {
        print('⚠️ Ya existe una medición horizontal con ese idnube.');
        return false;
      } else {
        print('❌ Error al crear medición horizontal. Código: ${response.statusCode}');
        print('Respuesta: ${response.body}');
        return false;
      }
    } catch (error) {
      print('❌ Error en postMedicionHorizontal: $error');
      return false;
    }
  }
}