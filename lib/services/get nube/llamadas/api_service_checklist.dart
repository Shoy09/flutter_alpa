import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/checklist_item.dart';

class ApiServiceCheckList {
  final http.Client? _client;
  final Future<void> Function(List<CheckListItem>)? _guardarCatalogo;

  ApiServiceCheckList({
    http.Client? client,
    Future<void> Function(List<CheckListItem>)? guardarCatalogo,
  }) : _client = client,
       _guardarCatalogo = guardarCatalogo;

  Future<List<CheckListItem>> fetchCheckList(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.checklistEndpoint}');
    final headers = {'Authorization': 'Bearer $token'};
    final response =
        await (_client?.get(uri, headers: headers) ??
            http.get(uri, headers: headers));
    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar el checklist. Código: ${response.statusCode}',
      );
    }
    final data = json.decode(response.body);
    if (data is! List) {
      throw const FormatException('La API no devolvió una lista de checklist.');
    }
    final items = data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Ítem de checklist inválido.');
      }
      return CheckListItem.fromJson(item);
    }).toList();
    await saveCheckListToLocalDB(items);
    return items;
  }

  /// Sustituye el catálogo y sus asignaciones en una sola transacción.
  /// No borra ni actualiza las respuestas de operaciones ya registradas.
  Future<void> saveCheckListToLocalDB(List<CheckListItem> items) async {
    if (_guardarCatalogo != null) {
      return _guardarCatalogo(items);
    }
    await DatabaseHelper().reemplazarChecklistCatalogo(items);
  }
}
