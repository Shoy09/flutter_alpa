import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanProduccion.dart';

class ApiServicePlanProduccion {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<PlanProduccion>> fetchPlanesProduccion(String token, int anio, String mes) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.PlanProduccionEndpoint}anio/$anio/mes/$mes'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<PlanProduccion> planes = responseData
            .map((data) => PlanProduccion.fromJson(data))
            .toList();

        await _dbHelper.deleteAll('PlanProduccion');
        await savePlanesToLocalDB(planes);

        return planes;
      } else {
        throw Exception('Error al obtener los planes de producción. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  Future<void> savePlanesToLocalDB(List<PlanProduccion> planes) async {
    for (var plan in planes) {
      Map<String, dynamic> planData = plan.toJson();
      planData.remove('id');
      await _dbHelper.insert('PlanProduccion', planData);
    }
  }
}
