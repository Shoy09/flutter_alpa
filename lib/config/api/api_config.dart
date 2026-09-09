class ApiConfig {
static const String baseUrl = 
'https://api-catalina-b7fhctc3e7gaf5ca.canadacentral-01.azurewebsites.net/api';
//'https://backend-seminco-pro-02.vercel.app/api';
      //'https://backend-seminco-mina-02.onrender.com/api';
      // 'https://backendseminco-production.up.railway.app/api';
  static const String loginEndpoint = '/auth/login'; 
  static const String estadosEndpoint = '/estado/';
  static const String checklistEndpoint = '/check-list';
  static const String fechasPlanMensualEndpoint = '/fechas-plan-mensual/';
  static const String jefe_guardias= '/usuarios/guardia/';
  // En api_config.dart
static const String usuariosNombresEndpoint = '/usuarios/nombres';
  static const String EquipoEndpoint = '/Equipo/';
  static const String tipoPerforacionEndpoint = '/TipoPerfpo/';
  
  static const String PlanProduccionEndpoint = '/PlanProduccion/';
  static const String PlanMetrajeEndpoint = '/PlanMetraje/';

  static const String PlanMensualEndpoint = '/PlanMensual/';
  static const String TipoEquipoEndpoint = '/tipo-equipos/';
  static const String checklistTelemandoEndpoint = '/checklists-telemando';
  static const String SeccionEndpoint = '/secciones/';
  static const String longitudBarrasEndpoint = '/longitud-barras/';
  static const String pernosEndpoint = '/pernos/';
  static const String mallasEndpoint = '/mallas/';
  static const String OrigenDestinoEndpoint = '/origen-destino/';
  static const String MaterialEndpoint = '/materiales/';
  static const String EmpresaEndpoint = '/empresas/';

  
  static const String ExplosivoEndpoint = '/Explosivos/';
  static const String AccesorioEndpoint = '/Accesorios/';
  static const String explosivosUniEndpoint = '/Explo-uni/';
  static const String datosExploracionesEndpoint = '/NubeDatosExploraciones';
      static const String datosExploracionesmedionesEndpoint = '/NubeDatosExploraciones/Explo-medicion';
      static const String medicionesHorizontalEndpoint = '/medicion-tal-horizontal';
static const String pdfEndpoint = '/pdf-operacion';
    static const String carpetasEndpoint = '/carpetas';
    static const String usuariosEndpoint = '/usuarios/usuarios/';
    static const String tipoLaborEndpoint = '/tipo-Labor';
}