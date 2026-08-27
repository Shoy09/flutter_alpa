import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/checklist_item.dart';


class ApiServiceCheckList {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtener checklist desde la API y guardarlo localmente
  Future<List<CheckListItem>> fetchCheckList(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.checklistEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<CheckListItem> items = responseData
            .map((data) => CheckListItem.fromJson(data))
            .toList();

        // Eliminar datos antiguos antes de insertar nuevos
        await _dbHelper.deleteAll('checklist_items');

        // Guardar en DB local sin el id
        await saveCheckListToLocalDB(items);

        return items;
      } else {
        throw Exception('Error al cargar el checklist. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  /// Guardar checklist en la base de datos local
  Future<void> saveCheckListToLocalDB(List<CheckListItem> items) async {
    for (var item in items) {
      Map<String, dynamic> itemData = item.toMap();
      itemData.remove('id'); // No insertar id si es autoincremental local
      await _dbHelper.insert('checklist_items', itemData);
    }
  }
}
