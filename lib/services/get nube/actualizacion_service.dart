import 'package:flutter/material.dart';
import 'package:i_miner/screens/Dash/actualizacion_dialog.dart';
import 'package:i_miner/services/get%20nube/Plan%20mensual/api_service_plan_mensual.dart';
import 'package:i_miner/services/get%20nube/Plan%20mensual/api_service_plan_mensual_metraje.dart';
import 'package:i_miner/services/get%20nube/Plan%20mensual/api_service_plan_mensual_produccion.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceAccesorio.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceChecklistTelemando.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceEmpresa.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceExplosivo.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceHorometros%20.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceJefeGuardia.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceMaterial.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceNumeroRetardos.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServicePdf.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceSeccion.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceTipoEquipo.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceTipoPerforacion.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceUsuario.dart';
import 'package:i_miner/services/get%20nube/llamadas/ApiServiceUsuarios.dart';
import 'package:i_miner/services/get%20nube/llamadas/api_service_checklist.dart';
import 'package:i_miner/services/get%20nube/llamadas/api_service_estado.dart';
import 'package:i_miner/services/get%20nube/llamadas/api_service_explosivos.dart';
import 'package:i_miner/services/get%20nube/llamadas/api_service_guardia.dart';
import 'package:i_miner/services/get%20nube/llamadas/api_service_longitud_barras.dart';
import 'package:i_miner/services/get%20nube/llamadas/api_service_mallas.dart';
import 'package:i_miner/services/get%20nube/llamadas/api_service_origen_destino.dart';
import 'package:i_miner/services/get%20nube/llamadas/api_service_pernos.dart';
import 'package:i_miner/services/get%20nube/llamadas/api_service_tipo_labor.dart';
import 'package:i_miner/services/get%20nube/llamadas/api_services_Equipo.dart';

class ActualizacionService {
  final BuildContext context;
  final String token;
  final int anio;
  final String? mes;

  ActualizacionService({
    required this.context,
    required this.token,
    required this.anio,
    this.mes,
  });

  // Mapeo de funciones de actualización
  late final Map<String, Future<void> Function()> _requests;

  void _inicializarRequests() {
    _requests = {
      "Estados": fetchEstados,
      "Checklist": fetchCheckList,
      "Checklist Carguio": fetchChecklistTelemando,
      "Tipos Perforación": fetchTiposPerforacion,
      "Secciones": fetchSecciones,
      "Equipos": fetchEquipo,
      "Tipos Equipo": () => fetchTiposEquipo(token),
      "Longitud Barras": fetchLongitudBarras,
      "Pernos": fetchPernos,
      "Mallas": fetchMallas,
      "Horometros": fetchHorometros,
      "Plan Mensual": () => fetchPlanMensualConFecha(),
      "Plan Metraje": () => fetchPlanMetrajeConFecha(),
      "Plan Producción": () => fetchPlanProduccionConFecha(),
      "Origen y Destino":() => fetchOrigenDestino(),
      "Accesorios":() => fetchAccesorios(),
      "Explosivos":() => fetchExplosivos(),
      "Explosivos Uni":() => fetchExplosivosUni(),
      "Numero de retardos":() => fetchNumeroRetardos(),
      "Materiales":() => fetchMateriales(),
      "Jefes Guardia":
          fetchJefesGuardia,
          "Guardias": fetchGuardias,
      "Empresas":() => fetchEmpresas(),
      "Documentos":() => fetchPdfsDelMes(),
      // "Procesos Acero": fetchProcesosAcero,
      // "Operadores Acero": fetchOperadores,
      "Operadores":() => fetchNombresUsuarios(),
      "Usuarios":() => syncUsuariosMaestros(),
      "Tipo Labor":() => fetchTiposLabor(),
    };
  }

  // Método principal para ejecutar la actualización
  Future<void> ejecutarActualizacion(
    Map<String, bool> opcionesSeleccionadas,
  ) async {
    _inicializarRequests();

    final int total = opcionesSeleccionadas.values.where((v) => v).length;
    final controller = ProgressDialogController();

    // Mostrar diálogo de progreso (una sola vez)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProgressDialog(
        message: 'Iniciando actualización...',
        total: total,
        controller: controller,
        primaryColor: Colors.blue[700],
      ),
    );

    // Pequeña pausa para que el diálogo se monte antes de actualizar
    await Future.delayed(const Duration(milliseconds: 120));

    try {
      int completadas = 0;
      bool huboError = false;
      List<String> errores = [];

      // Ejecutar cada opción seleccionada
      for (var entry in _requests.entries) {
        if (opcionesSeleccionadas[entry.key] == true) {
          controller.update(
            message: 'Actualizando ${entry.key}...',
            subtitulo: '$completadas de $total completadas',
            completadas: completadas,
            total: total,
          );

          try {
            await entry.value();
            completadas++;
          } catch (e) {
            huboError = true;
            completadas++;
            errores.add('${entry.key}: $e');
            print("❌ Error en ${entry.key}: $e");
          }

          // Actualizar progreso tras completar
          controller.update(
            message: completadas < total
                ? 'Actualizando ${entry.key}...'
                : 'Finalizando...',
            subtitulo: '$completadas de $total completadas',
            completadas: completadas,
            total: total,
          );
        }
      }

      // Pequeña pausa para mostrar el 100%
      await Future.delayed(const Duration(milliseconds: 350));

      // Cerrar diálogo de progreso
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _mostrarResultadoFinal(completadas, total, huboError, errores);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _mostrarError('Error general: $e');
      }
    }
  }

  void _mostrarResultadoFinal(
    int completadas,
    int total,
    bool huboError,
    List<String> errores,
  ) {
    showDialog(
      context: context,
      builder: (_) => ResultadoActualizacionDialog(
        completadas: completadas,
        total: total,
        errores: errores,
        primaryColor: Colors.blue[700],
      ),
    );
  }

  void _mostrarError(String mensaje) {
    showDialog(
      context: context,
      builder: (_) => ResultadoActualizacionDialog(
        completadas: 0,
        total: 1,
        errores: [mensaje],
        primaryColor: Colors.blue[700],
      ),
    );
  }

  Future<void> fetchEstados() async {
    final apiService = ApiServiceEstado();

    try {
      final estados = await apiService.fetchEstados(token);

      print("✅ Estados guardados en SQLite:");

      for (var estado in estados) {
        print("Estado: ${estado.estadoPrincipal}");
      }
    } catch (e) {
      print("❌ Error al actualizar estados: $e");
      throw e;
    }
  }

  Future<void> fetchEmpresas() async {
  final apiService = ApiServiceEmpresa();

  try {
    final empresas = await apiService.fetchEmpresas(token);

    print("✅ Empresas guardadas en SQLite:");

    for (var empresa in empresas) {
      print("Empresa: ${empresa.nombre}");
    }
  } catch (e) {
    print("❌ Error al actualizar empresas: $e");
    throw e;
  }
}

  Future<void> fetchTiposPerforacion() async {
    final apiService = ApiServiceTipoPerforacion();

    try {
      final tipos = await apiService.fetchTiposPerforacion(token);

      print("✅ Tipos de perforación guardados en SQLite:");

      for (var tipo in tipos) {
        print("Tipo: ${tipo.nombre}");
      }
    } catch (e) {
      print("❌ Error al actualizar tipos de perforación: $e");
      throw e;
    }
  }

  Future<void> fetchSecciones() async {
    final apiService = ApiServiceSeccion();

    try {
      final secciones = await apiService.fetchSecciones(token);

      print("✅ Secciones guardadas en SQLite:");

      for (var seccion in secciones) {
        print("Sección: ${seccion.nombre} | Proceso: ${seccion.proceso}");
      }
    } catch (e) {
      print("❌ Error al actualizar secciones: $e");
      throw e;
    }
  }

  Future<void> fetchTiposLabor() async {
  final apiService = ApiServiceTipoLabor();

  try {
    final tiposLabor = await apiService.fetchTiposLabor(token);

    print("✅ Tipos de Labor guardados en SQLite:");

    for (var tipo in tiposLabor) {
      print("Tipo: ${tipo.nombre} | Proceso: ${tipo.proceso ?? 'Sin proceso'}");
    }
  } catch (e) {
    print("❌ Error al actualizar tipos de labor: $e");
    throw e;
  }
}

  Future<void> fetchEquipo() async {
    final apiService = ApiServiceEquipo();

    try {
      final equipos = await apiService.fetchEquipos(token);

      print("✅ Equipos guardados en SQLite:");

      for (var equipo in equipos) {
        print("Equipo: ${equipo.nombre}");
      }
    } catch (e) {
      print("❌ Error al actualizar equipos: $e");
      throw e;
    }
  }

  Future<void> fetchTiposEquipo(String token) async {
    final apiService = ApiServiceTipoEquipo();

    try {
      final tipos = await apiService.fetchTiposEquipo(token);

      print("✅ Tipos de equipo guardados en SQLite:");

      for (var tipo in tipos) {
        print("Tipo de Equipo: ${tipo.nombre}");
      }
    } catch (e) {
      print("❌ Error al actualizar tipos de equipo: $e");
      throw e;
    }
  }

  Future<void> fetchLongitudBarras() async {
    final apiService = ApiServiceLongitudBarras();

    try {
      final lista = await apiService.fetchLongitudBarras(token);

      print("✅ Longitud Barras guardadas en SQLite:");

      for (var item in lista) {
        print("Proceso: ${item.proceso} | Longitud: ${item.longitudPies}");
      }
    } catch (e) {
      print("❌ Error al actualizar Longitud Barras: $e");
      throw e;
    }
  }

  Future<void> fetchPernos() async {
    final apiService = ApiServicePernos();

    try {
      final lista = await apiService.fetchPernos(token);

      print("✅ Pernos guardados en SQLite:");

      for (var item in lista) {
        print("Tipo: ${item.tipoPerno} | Longitud: ${item.longitud}");
      }
    } catch (e) {
      print("❌ Error al actualizar Pernos: $e");
      throw e;
    }
  }

  Future<void> fetchMallas() async {
    final apiService = ApiServiceMallas();

    try {
      final lista = await apiService.fetchMallas(token);

      print("✅ Mallas guardadas en SQLite:");

      for (var item in lista) {
        print("Tipo: ${item.tipoMalla}");
      }
    } catch (e) {
      print("❌ Error al actualizar Mallas: $e");
      throw e;
    }
  }

  Future<void> fetchHorometros() async {
    final apiService = ApiServiceHorometros();

    try {
      await apiService.fetchHorometros(token);

      print("✅ Horómetros guardados en SQLite correctamente");
    } catch (e) {
      print("❌ Error al actualizar horómetros: $e");
      throw e;
    }
  }

  Future<void> fetchAccesorios() async {
  final apiService = ApiServiceAccesorio();

  try {
    await apiService.fetchAccesorios(token);

    print("✅ Accesorios guardados en SQLite correctamente");
  } catch (e) {
    print("❌ Error al actualizar accesorios: $e");
    throw e;
  }
}

Future<void> fetchMateriales() async {
  final apiService = ApiServiceMaterial();

  try {
    await apiService.fetchMateriales(token);

    print("✅ Materiales guardados en SQLite correctamente");
  } catch (e) {
    print("❌ Error al actualizar materiales: $e");
    throw e;
  }
}

Future<void> fetchExplosivos() async {
  final apiService = ApiServiceExplosivo();

  try {
    await apiService.fetchExplosivos(token);

    print("✅ Explosivos guardados en SQLite correctamente");
  } catch (e) {
    print("❌ Error al actualizar explosivos: $e");
    throw e;
  }
}

Future<void> fetchExplosivosUni() async {
  final apiService = ApiServiceExplosivosUni();

  try {
    await apiService.fetchExplosivos(token);

    print("✅ ExplosivosUni guardados en SQLite correctamente");
  } catch (e) {
    print("❌ Error al actualizar ExplosivosUni: $e");
    throw e;
  }
}

Future<void> fetchNumeroRetardos() async {
  final apiService = ApiServiceNumeroRetardos();

  try {
    final data = await apiService.fetchUltimo(token);

    if (data != null) {
      print("✅ Último NumeroRetardos guardado en SQLite correctamente");
    } else {
      print("⚠️ No hay registros de NumeroRetardos en el servidor");
    }

  } catch (e) {
    print("❌ Error al actualizar NumeroRetardos: $e");
    throw e;
  }
}

  Future<void> fetchDestinatarios() async {
    // Tu implementación
  }

  Future<void> fetchPlanMensualConFecha() async {
    final apiService = ApiServicePlanMensual();

    try {
      final planes = await apiService.fetchPlanesMensuales(token, anio, mes!);

      print("✅ Plan Mensual actualizado:");

      for (var plan in planes) {
        print("Plan: ${plan.toMap()}");
      }
    } catch (e) {
      print("❌ Error al actualizar Plan Mensual: $e");
      throw e;
    }
  }

  Future<void> fetchPlanMetrajeConFecha() async {
    final apiService = ApiServicePlanMetraje();

    try {
      final planes = await apiService.fetchPlanesMetraje(token, anio, mes!);

      print("✅ Plan Metraje actualizado:");

      for (var plan in planes) {
        print("Plan: ${plan.toMap()}");
      }
    } catch (e) {
      print("❌ Error al actualizar Plan Metraje: $e");
      throw e;
    }
  }

  Future<void> fetchPlanProduccionConFecha() async {
    final apiService = ApiServicePlanProduccion();

    try {
      final planes = await apiService.fetchPlanesProduccion(token, anio, mes!);

      print("✅ Plan Producción actualizado:");

      for (var plan in planes) {
        print("Plan: ${plan.toJson()}");
      }
    } catch (e) {
      print("❌ Error al actualizar Plan Producción: $e");
      throw e;
    }
  }

  Future<void> fetchToneladas() async {
    // Tu implementación
  }

  Future<void> fetchCheckList() async {
    final apiService = ApiServiceCheckList();

    try {
      final items = await apiService.fetchCheckList(token);

      print("✅ Checklist guardado en SQLite:");

      for (var item in items) {
        print(
          "Item: ${item.nombre}",
        ); // reemplaza `nombre` con el campo que quieras mostrar
      }
    } catch (e) {
      print("❌ Error al actualizar checklist: $e");
      throw e;
    }
  }

  Future<void> fetchChecklistTelemando() async {
    final apiService = ApiServiceChecklistTelemando();

    try {
      final items = await apiService.fetchChecklistTelemando(token);

      print("✅ Checklist Telemando guardado en SQLite:");

      for (var item in items) {
        print("Item: ${item.nombre}");
      }
    } catch (e) {
      print("❌ Error al actualizar checklist telemando: $e");
      throw e;
    }
  }

  Future<void> fetchOrigenDestino() async {
  final apiService = ApiServiceOrigenDestino();

  try {
    final items = await apiService.fetchOrigenDestino(token);

    print("✅ OrigenDestino guardado en SQLite:");

    for (var item in items) {
      print("Proceso: ${item.proceso} | Tipo: ${item.tipo} | Nombre: ${item.nombre}");
    }

  } catch (e) {
    print("❌ Error al actualizar origen_destino: $e");
    throw e;
  }
}
  Future<void> fetchPdfsDelMes() async {
  final apiService = ApiServicePdf();

  try {
    await apiService.sincronizarTodo(token);

    print("✅ PDFs y carpetas sincronizados correctamente");
  } catch (e) {
    print("❌ Error al actualizar PDFs y carpetas: $e");
    throw e;
  }
}

Future<void> fetchNombresUsuarios() async {
  final apiService = ApiServiceUsuarios();

  try {
    final usuarios = await apiService.fetchNombresUsuarios(token);

    print("✅ Nombres de usuarios guardados en SQLite:");

    for (var usuario in usuarios) {
      print("Usuario: ${usuario.nombreCompleto} (ID: ${usuario.usuarioId})");
    }
  } catch (e) {
    print("❌ Error al actualizar nombres de usuarios: $e");
    throw e;
  }
}


Future<void> syncUsuariosMaestros() async {
  final apiServiceUsuario = ApiServiceUsuario();

  try {
    final usuarios = await apiServiceUsuario.fetchUsuarios(token);

    print("✅ ${usuarios.length} usuarios maestros sincronizados en SQLite:");

    for (var usuario in usuarios) {
      print("Usuario: ${usuario.nombres} ${usuario.apellidos} (DNI: ${usuario.codigoDni})");
    }
  } catch (e) {
    print("❌ Error al sincronizar usuarios maestros: $e");
    throw e;
  }
}
  Future<void> fetchJefesGuardia() async {
    final apiService = ApiServiceJefeGuardia();

    try {
      final jefes = await apiService.fetchJefesGuardia(token);

      print("✅ Jefes de guardia guardados en SQLite:");

      for (var jefe in jefes) {
        print("Jefe: ${jefe.nombres} ${jefe.apellidos}");
      }
    } catch (e) {
      print("❌ Error al actualizar jefes de guardia: $e");
      throw e;
    }
  }

  Future<void> fetchGuardias() async {
  final apiService = ApiServiceGuardia();

  try {
    final guardias = await apiService.fetchGuardias(token);

    print("✅ Guardias guardadas en SQLite:");

    for (var guardia in guardias) {
      print("Guardia: ${guardia.guardia}");
    }
  } catch (e) {
    print("❌ Error al actualizar guardias: $e");
    throw e;
  }
}

  Future<void> fetchProcesosAcero() async {}

  Future<void> fetchOperadores() async {
    // Tu implementación
  }
}
