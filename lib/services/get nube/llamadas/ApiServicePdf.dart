import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/models/CarpetaModel.dart';
import 'package:i_miner/models/PdfModel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ApiServicePdf {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ──────────────────────────────────────────────
  // SINCRONIZACIÓN COMPLETA: carpetas + PDFs
  // ──────────────────────────────────────────────

  /// Descarga todas las carpetas y PDFs desde la API y los guarda localmente.
  Future<void> sincronizarTodo(String token) async {
    final carpetas = await fetchCarpetas(token);
    await _guardarCarpetasEnLocal(carpetas);

    final pdfs = await fetchTodosLosPdfs(token);
    await _guardarPdfsEnLocal(pdfs);
  }

  // ──────────────────────────────────────────────
  // CARPETAS
  // ──────────────────────────────────────────────

  Future<List<CarpetaModel>> fetchCarpetas(String token) async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.carpetasEndpoint}';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('📁 Carpetas recibidas: ${data.length}');
        return data.map((d) => CarpetaModel.fromJson(d)).toList();
      } else {
        throw Exception('Error al cargar carpetas. Código: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error en fetchCarpetas: $e');
    }
  }

  Future<void> _guardarCarpetasEnLocal(List<CarpetaModel> carpetas) async {
    await _dbHelper.deleteAllShared('CarpetaModel');
    for (final carpeta in carpetas) {
      await _dbHelper.insertShared('CarpetaModel', carpeta.toMap());
      print('💾 Carpeta guardada: ${carpeta.nombre}');
    }
  }

  // ──────────────────────────────────────────────
  // PDFs
  // ──────────────────────────────────────────────

  /// Obtiene todos los PDFs desde la API
  Future<List<PdfModel>> fetchTodosLosPdfs(String token) async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.pdfEndpoint}';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('📄 PDFs recibidos: ${data.length}');
        return data.map((d) => PdfModel.fromJson(d)).toList();
      } else {
        throw Exception('Error al cargar PDFs. Código: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error en fetchTodosLosPdfs: $e');
    }
  }

  /// Obtiene los PDFs de una carpeta específica
  Future<List<PdfModel>> fetchPdfsPorCarpeta(String token, int carpetaId) async {
    try {
      final url =
          '${ApiConfig.baseUrl}${ApiConfig.pdfEndpoint}/carpeta/$carpetaId';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((d) => PdfModel.fromJson(d)).toList();
      } else {
        throw Exception(
            'Error al cargar PDFs de carpeta. Código: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error en fetchPdfsPorCarpeta: $e');
    }
  }

  Future<void> _guardarPdfsEnLocal(List<PdfModel> pdfs) async {
    await _dbHelper.deleteAllShared('PdfModel');

    for (final pdf in pdfs) {
      final localPath = await _descargarPdfLocal(pdf);

      if (localPath.isNotEmpty) {
        final Map<String, dynamic> data = {
          'id': pdf.id,
          'nombre': pdf.nombre,
          'url_pdf': localPath,
          'carpeta_id': pdf.carpetaId,
          'createdAt': pdf.createdAt.toIso8601String(),
          'updatedAt': pdf.updatedAt.toIso8601String(),
        };

        print('💾 Guardando PDF local: ${pdf.nombre}');
        await _dbHelper.insertShared('PdfModel', data);
      } else {
        print('❌ No se guardó PDF con id ${pdf.id}: fallo en descarga');
      }
    }
  }

  /// Descarga el PDF desde Cloudinary y devuelve la ruta local
  Future<String> _descargarPdfLocal(PdfModel pdf) async {
    try {
      final response = await http.get(Uri.parse(pdf.urlPdf));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final pdfDir = Directory('${directory.path}/pdf');

        if (!await pdfDir.exists()) {
          await pdfDir.create(recursive: true);
        }

        // Nombre de archivo basado en id para evitar colisiones
        final filename = 'pdf_${pdf.id}_${pdf.nombre.replaceAll(RegExp(r'[^\w]'), '_')}.pdf';
        final filePath = path.join(pdfDir.path, filename);
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error al descargar PDF ${pdf.nombre}: $e');
      return '';
    }
  }
}
