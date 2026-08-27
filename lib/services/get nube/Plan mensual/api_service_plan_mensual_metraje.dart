import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/PlanMetraje.dart';

class ApiServicePlanMetraje {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<PlanMetraje>> fetchPlanesMetraje(
      String token, int anio, String mes) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.PlanMetrajeEndpoint}anio/$anio/mes/$mes'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<PlanMetraje> planes =
            responseData.map((data) => PlanMetraje.fromJson(data)).toList();

        await _dbHelper.deleteAll('PlanMetraje');
        await savePlanesToLocalDB(planes);

        return planes;
      } else {
        throw Exception(
            'Error al obtener los planes de metraje. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  Future<void> savePlanesToLocalDB(List<PlanMetraje> planes) async {
    for (var plan in planes) {
      Map<String, dynamic> planData = plan.toMap();
      planData.remove('id');
      await _dbHelper.insert('PlanMetraje', planData);
    }
  }
}
