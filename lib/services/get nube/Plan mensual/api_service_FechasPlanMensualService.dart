
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'dart:convert';

import 'package:i_miner/models/FechasPlanMensual.dart';


class FechasPlanMensualService {
  Future<FechasPlanMensual?> getUltimaFecha() async {
    try {
      final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.fechasPlanMensualEndpoint}ultima'));
      if (response.statusCode == 200) {
        return FechasPlanMensual.fromJson(jsonDecode(response.body));
      } else {
        // No lanza excepción, solo devuelve null
        print('Error: status code ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error de conexión: $e');
      return null; // evita que la app se trabe
    }
  }
}