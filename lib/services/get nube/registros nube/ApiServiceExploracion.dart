import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_miner/config/api/api_config.dart';
import 'package:i_miner/config/data/database_helper.dart';

class ApiServiceExploracion_Mina2 {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Método para obtener las exploraciones desde la API
  Future<List<dynamic>> fetchExploracionesMina2(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.datosExploracionesEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> exploraciones = json.decode(response.body);
        
        // Eliminar los datos antiguos antes de insertar los nuevos
        await _cleanLocalDatabase();
        
        // Guardar los datos en la base de datos local
        await _saveExploracionesToLocalDB(exploraciones);
        
        return exploraciones;
      } else {
        throw Exception('Error al obtener exploraciones. Código: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error en la solicitud: $error');
    }
  }

  // Limpiar todas las tablas relacionadas con exploraciones
  Future<void> _cleanLocalDatabase() async {
    await _dbHelper.deleteAll('nube_DetalleDevolucionesExplosivos');
    await _dbHelper.deleteAll('nube_DetalleDespachoExplosivos');
    await _dbHelper.deleteAll('nube_DevolucionDetalle');
    await _dbHelper.deleteAll('nube_DespachoDetalle');
    await _dbHelper.deleteAll('nube_Devoluciones');
    await _dbHelper.deleteAll('nube_Despacho');
    await _dbHelper.deleteAll('nube_Datos_trabajo_exploraciones');
  }

  // Guardar exploraciones en la base de datos local
  Future<void> _saveExploracionesToLocalDB(List<dynamic> exploraciones) async {
    for (var exploracion in exploraciones) {
      // Guardar datos principales de la exploración
      final int localId = await _saveDatosTrabajo(exploracion);
      
      // Guardar despachos relacionados
      if (exploracion['despachos'] != null && exploracion['despachos'].isNotEmpty) {
        for (var despacho in exploracion['despachos']) {
          final int localDespachoId = await _saveDespacho(despacho, localId);
          
          // Guardar detalles del despacho
          if (despacho['detalles'] != null && despacho['detalles'].isNotEmpty) {
            for (var detalle in despacho['detalles']) {
              await _saveDespachoDetalle(detalle, localDespachoId);
            }
          }
          
          // Guardar detalles de explosivos del despacho
          if (despacho['detalles_explosivos'] != null && despacho['detalles_explosivos'].isNotEmpty) {
            for (var detalle in despacho['detalles_explosivos']) {
              await _saveDetalleDespachoExplosivos(detalle, localDespachoId);
            }
          }
        }
      }
      
      // Guardar devoluciones relacionadas
      if (exploracion['devoluciones'] != null && exploracion['devoluciones'].isNotEmpty) {
        for (var devolucion in exploracion['devoluciones']) {
          final int localDevolucionId = await _saveDevolucion(devolucion, localId);
          
          // Guardar detalles de la devolución
          if (devolucion['detalles'] != null && devolucion['detalles'].isNotEmpty) {
            for (var detalle in devolucion['detalles']) {
              await _saveDevolucionDetalle(detalle, localDevolucionId);
            }
          }
          
          // Guardar detalles de explosivos de la devolución
          if (devolucion['detalles_explosivos'] != null && devolucion['detalles_explosivos'].isNotEmpty) {
            for (var detalle in devolucion['detalles_explosivos']) {
              await _saveDetalleDevolucionExplosivos(detalle, localDevolucionId);
            }
          }
        }
      }
    }
  }

  // Métodos auxiliares para guardar cada tipo de dato

  Future<int> _saveDatosTrabajo(Map<String, dynamic> datos) async {
    final Map<String, dynamic> datosTrabajo = {
      'fecha': datos['fecha'],
      'turno': datos['turno'],
      'taladro': datos['taladro'],
      'pies_por_taladro': datos['pies_por_taladro'],
      'zona': datos['zona'],
      'tipo_labor': datos['tipo_labor'],
      'labor': datos['labor'],
      'ala': datos['ala'],
      'veta': datos['veta'],
      'nivel': datos['nivel'],
      'tipo_perforacion': datos['tipo_perforacion'],
      'estado': datos['estado'],
      'cerrado': datos['cerrado'],
      'envio': datos['envio'],
      'semanaDefault': datos['semanaDefault'],
      'semanaSelect': datos['semanaSelect'],
      'empresa': datos['empresa'],
      'seccion': datos['seccion'],
      'idnube': datos['id'].toString(), // Guardamos el ID de la API como idnube
      'medicion': datos['medicion'],
    };
    
    return await _dbHelper.insert('nube_Datos_trabajo_exploraciones', datosTrabajo);
  }

  Future<int> _saveDespacho(Map<String, dynamic> despacho, int localDatosTrabajoId) async {
    final Map<String, dynamic> despachoData = {
      'datos_trabajo_id': localDatosTrabajoId,
      'mili_segundo': despacho['mili_segundo'],
      'medio_segundo': despacho['medio_segundo'],
      'observaciones': despacho['observaciones'],
    };
    
    return await _dbHelper.insert('nube_Despacho', despachoData);
  }

  Future<int> _saveDespachoDetalle(Map<String, dynamic> detalle, int localDespachoId) async {
    final Map<String, dynamic> detalleData = {
      'despacho_id': localDespachoId,
      'nombre_material': detalle['nombre_material'],
      'cantidad': detalle['cantidad'],
    };
    
    return await _dbHelper.insert('nube_DespachoDetalle', detalleData);
  }

  Future<int> _saveDetalleDespachoExplosivos(Map<String, dynamic> detalle, int localDespachoId) async {
    final Map<String, dynamic> detalleData = {
      'id_despacho': localDespachoId,
      'numero': detalle['numero'],
      'ms_cant1': detalle['ms_cant1'],
      'lp_cant1': detalle['lp_cant1'],
    };
    
    return await _dbHelper.insert('nube_DetalleDespachoExplosivos', detalleData);
  }

  Future<int> _saveDevolucion(Map<String, dynamic> devolucion, int localDatosTrabajoId) async {
    final Map<String, dynamic> devolucionData = {
      'datos_trabajo_id': localDatosTrabajoId,
      'mili_segundo': devolucion['mili_segundo'],
      'medio_segundo': devolucion['medio_segundo'],
      'observaciones': devolucion['observaciones'],
    };
    
    return await _dbHelper.insert('nube_Devoluciones', devolucionData);
  }

  Future<int> _saveDevolucionDetalle(Map<String, dynamic> detalle, int localDevolucionId) async {
    final Map<String, dynamic> detalleData = {
      'devolucion_id': localDevolucionId,
      'nombre_material': detalle['nombre_material'],
      'cantidad': detalle['cantidad'],
    };
    
    return await _dbHelper.insert('nube_DevolucionDetalle', detalleData);
  }

  Future<int> _saveDetalleDevolucionExplosivos(Map<String, dynamic> detalle, int localDevolucionId) async {
    final Map<String, dynamic> detalleData = {
      'id_devolucion': localDevolucionId,
      'numero': detalle['numero'],
      'ms_cant1': detalle['ms_cant1'],
      'lp_cant1': detalle['lp_cant1'],
    };
    
    return await _dbHelper.insert('nube_DetalleDevolucionesExplosivos', detalleData);
  }
}