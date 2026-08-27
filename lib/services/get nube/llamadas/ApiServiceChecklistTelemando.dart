import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/ChecklistTelemando.dart';

class ApiServiceChecklistTelemando {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtener checklist desde la API y guardarlos localmente
  Future<List<ChecklistTelemando>> fetchChecklistTelemando(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.checklistTelemandoEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        List<ChecklistTelemando> checklist = responseData
            .map((data) => ChecklistTelemando.fromJson(data))
            .toList();

        /// Eliminar datos antiguos
        await _dbHelper.deleteAll('checklists_telemando');

        /// Guardar en DB local
        await saveChecklistToLocalDB(checklist);

        return checklist;
      } else {
        throw Exception(
            'Error al cargar checklist telemando. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  /// Guardar checklist en base de datos local
  Future<void> saveChecklistToLocalDB(List<ChecklistTelemando> checklist) async {
    for (var item in checklist) {
      Map<String, dynamic> data = item.toMap();

      data.remove('id'); // evitar conflicto con autoincrement

      await _dbHelper.insert('checklists_telemando', data);
    }
  }
}