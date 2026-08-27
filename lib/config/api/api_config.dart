class ApiConfig {
static const String baseUrl = 
'https://api-seminco-catalina-huanca.vercel.app/api';
//'https://backend-seminco-pro-02.vercel.app/api';
      //'https://backend-seminco-mina-02.onrender.com/api';
      // 'https://backendseminco-production.up.railway.app/api';
  static const String loginEndpoint = '/auth/login'; 
  static const String estadosEndpoint = '/estado/';
  static const String checklistEndpoint = '/check-list';
  static const String fechasPlanMensualEndpoint = '/fechas-plan-mensual/';
  static const String jefe_guardias= '/usuarios/guardia/';
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

}