/// Un dato de la operación de cada estado, tal como lo guarda el formulario
/// manual del módulo (por ejemplo `tal_prod` en Tal horizontal).
class PhotoCampo {
  final String key;
  final String label;
  final bool numero;

  /// Opciones fijas del formulario (ej. MINERAL / DESMONTE).
  final List<String> opciones;

  /// Catálogo de la BD local que da las opciones: ver [PhotoCatalogo].
  final PhotoCatalogo? catalogo;

  /// Lo que se escribe en la hoja → valor del formulario (ej. "M" → MINERAL).
  final Map<String, String> equivalencias;

  /// Si falta en un estado que lleva datos, se avisa para completarlo después.
  final bool pendienteSiFalta;

  /// El formulario lo guarda como número decimal (vacío = 0.0), no como texto.
  final bool decimal;

  /// El desplegable del formulario falla con valores fuera del catálogo: si
  /// lo leído no coincide, se deja vacío para elegirlo.
  final bool soloCatalogo;

  /// Buscador con texto libre (como la labor), en vez de desplegable.
  final bool autocompletar;

  /// Clave con la que lo guarda el formulario, si difiere de [key] (Scissor:
  /// la letra de "Tipo de labor" se lee en tipo_perforacion y se guarda en
  /// tipo_labor, que en las demás hojas compone la labor).
  final String? guardarComo;

  /// El formulario también guarda el id de la opción elegida (ej. tipo_labor_id).
  final String? idComo;

  /// Empernador: la columna es una fila de la lista perno/malla/perforación.
  final PhotoGrupo? grupo;

  /// Tipo y longitud que representa la columna (ej. "SS 7'" → SS, 7 pies);
  /// la pantalla los busca en el catálogo de pernos o mallas.
  final String tipo;
  final double? pies;

  const PhotoCampo(
    this.key,
    this.label, {
    this.numero = false,
    this.opciones = const [],
    this.catalogo,
    this.equivalencias = const {},
    this.pendienteSiFalta = false,
    this.decimal = false,
    this.soloCatalogo = false,
    this.autocompletar = false,
    this.guardarComo,
    this.idComo,
    this.grupo,
    this.tipo = '',
    this.pies,
  });
}

enum PhotoCatalogo {
  tiposPerforacion,
  tiposLabor,
  longitudBarras,
  materiales,

  /// Labores de los planes (como el buscador de labor).
  labores,

  /// Labores de los planes + orígenes / destinos del proceso.
  origenes,
  destinos,
}

enum PhotoGrupo { perforacion, perno, malla }

/// Cómo guarda cada módulo los datos de perforación de un estado.
enum PhotoFormato {
  /// Taladro largo: lista de barras por fila.
  barras,

  /// Tal horizontal: campos sueltos.
  campos,

  /// Empernador: listas perforacion, perno y malla.
  empernador,

  /// Scoop: un viaje (origen, destino, cucharas) por estado.
  scoop,
}

/// Qué hoja se lee y cómo se guarda en cada módulo de operación.
class PhotoProceso {
  /// Ruta de la API: `<baseUrl>/<ruta>/preview`.
  final String ruta;

  /// Proceso en la BD local (estados, equipos, checklist y catálogos).
  final String nombre;
  final String tabla;
  final List<String> horometros;
  final PhotoFormato formato;

  /// Estados OPERATIVO cuyo formulario oculta los datos de perforación.
  final Set<String> codigosSinDatos;

  /// Si no está vacío, solo estos códigos OPERATIVO llevan datos (Scalamin: 101).
  final Set<String> codigosConDatos;
  final bool sinDatosSerie200a599;

  /// Estados cuyo formulario muestra perforación pero no pernos ni malla.
  final Set<String> codigosSoloPerforacion;
  final List<PhotoCampo> campos;

  /// Mover datos escritos junto a un estado sin datos al estado anterior. No
  /// aplica cuando cada fila trae lo suyo (Scoop: el traslado tiene su viaje).
  final bool reubicar;

  /// Repetir la labor escrita en los estados con datos que no la tienen. No
  /// aplica cuando el trabajo se hace en el destino del traslado (Scissor).
  final bool propagarLabor;

  /// Proceso del que el formulario carga los tipos de perforación, si no es
  /// [nombre] (el formulario de Scissor usa los de PERFORACIÓN HORIZONTAL).
  final String? procesoTipos;

  const PhotoProceso({
    required this.ruta,
    required this.nombre,
    required this.tabla,
    required this.horometros,
    this.formato = PhotoFormato.campos,
    this.codigosSinDatos = const {},
    this.codigosConDatos = const {},
    this.sinDatosSerie200a599 = false,
    this.codigosSoloPerforacion = const {},
    this.campos = const [],
    this.reubicar = true,
    this.propagarLabor = true,
    this.procesoTipos,
  });

  bool get usaBarras => formato == PhotoFormato.barras;

  /// Si el campo se muestra y se guarda para ese código (pernos y malla no
  /// van en los códigos de solo perforación).
  bool usaCampo(PhotoCampo campo, String codigo) =>
      !(codigosSoloPerforacion.contains(codigo.trim()) &&
          (campo.grupo == PhotoGrupo.perno || campo.grupo == PhotoGrupo.malla));

  /// Igual que el formulario de perforación del módulo: solo OPERATIVO lleva
  /// datos, salvo [codigosSinDatos].
  bool llevaDatos(String? estado, String codigo) {
    final numero = int.tryParse(codigo.trim());
    return estado == 'OPERATIVO' &&
        (codigosConDatos.isEmpty || codigosConDatos.contains(codigo.trim())) &&
        !codigosSinDatos.contains(codigo.trim()) &&
        !(sinDatosSerie200a599 &&
            numero != null &&
            numero >= 200 &&
            numero < 600);
  }

  static const talLargo = PhotoProceso(
    ruta: 'tal-largo',
    nombre: 'PERFORACIÓN TALADROS LARGOS',
    tabla: 'Operacion_tal_largo',
    horometros: ['diesel', 'electrico', 'percusion'],
    formato: PhotoFormato.barras,
    codigosSinDatos: {'107', '108', '109', '110'},
    sinDatosSerie200a599: true,
  );

  /// Hoja "Reporte diario de perforación de Jumbo Frontonero".
  static const talHorizontal = PhotoProceso(
    ruta: 'tal-horizontal',
    nombre: 'PERFORACIÓN HORIZONTAL',
    tabla: 'Operacion_tal_horizontal',
    horometros: ['diesel', 'electrico', 'percusion', 'electrico2', 'percusion2'],
    codigosSinDatos: {'103', '104', '105', '106', '107'},
    campos: [
      PhotoCampo('tal_prod', 'Tal. producción', numero: true, pendienteSiFalta: true),
      PhotoCampo('tal_rimados', 'Tal. rimados', numero: true),
      PhotoCampo('tal_alivio', 'Tal. alivio', numero: true),
      PhotoCampo(
        'long_barras',
        'Longitud (pies)',
        numero: true,
        catalogo: PhotoCatalogo.longitudBarras,
        pendienteSiFalta: true,
      ),
      PhotoCampo(
        'tipo_perforacion',
        'Tipo perforación',
        catalogo: PhotoCatalogo.tiposPerforacion,
        idComo: 'tipo_perforacion_id',
        // Leyenda "TIPO DE LABOR" de la hoja.
        equivalencias: {
          'F': 'FRENTE',
          'B': 'BREASTING',
          'R': 'REALCE',
          'D': 'DESQUINCHE',
          'S': 'SELLADA',
          'C': 'CUNETA',
          'N': 'NICHO',
          'O': 'OTROS',
        },
      ),
      PhotoCampo(
        'material',
        'Material',
        opciones: ['MINERAL', 'DESMONTE'],
        equivalencias: {'M': 'MINERAL', 'D': 'DESMONTE'},
      ),
    ],
  );

  /// Hoja "Reporte diario de perforación de Empernador - Boltec". Cada columna
  /// de pernos y mallas es una fila de su lista en el formulario.
  static const empernador = PhotoProceso(
    ruta: 'empernador',
    nombre: 'EMPERNADOR',
    tabla: 'Operacion_empernador',
    horometros: ['diesel', 'electrico', 'percusion', 'empernador'],
    formato: PhotoFormato.empernador,
    codigosSinDatos: {'103', '104', '105', '106'},
    codigosSoloPerforacion: {'102'},
    campos: [
      PhotoCampo(
        'tald_perf',
        'N° tal. perf.',
        numero: true,
        grupo: PhotoGrupo.perforacion,
        pendienteSiFalta: true,
      ),
      PhotoCampo(
        'long_perf',
        'Long. perf.',
        numero: true,
        grupo: PhotoGrupo.perforacion,
      ),
      PhotoCampo("ss3", "SS 3' (pernos)", numero: true, grupo: PhotoGrupo.perno, tipo: 'SS', pies: 3),
      PhotoCampo("ss7", "SS 7' (pernos)", numero: true, grupo: PhotoGrupo.perno, tipo: 'SS', pies: 7),
      PhotoCampo("sw7", "SW 7' (pernos)", numero: true, grupo: PhotoGrupo.perno, tipo: 'SW', pies: 7),
      PhotoCampo("ph7", "PH 7' (pernos)", numero: true, grupo: PhotoGrupo.perno, tipo: 'PH', pies: 7),
      PhotoCampo('malla_c10', 'Malla C-10 (m²)', numero: true, grupo: PhotoGrupo.malla, tipo: 'C-10'),
      PhotoCampo('malla_c8', 'Malla C-8 (m²)', numero: true, grupo: PhotoGrupo.malla, tipo: 'C-8'),
      PhotoCampo(
        'malla_eslabonada',
        'Malla eslabonada (m²)',
        numero: true,
        grupo: PhotoGrupo.malla,
        tipo: 'ESLABONADA',
      ),
      PhotoCampo(
        'tipo_perforacion',
        'Tipo perforación',
        catalogo: PhotoCatalogo.tiposPerforacion,
      ),
    ],
  );

  /// Hoja "Reporte diario de equipo desatador". Solo el 101 (desatado con
  /// percusión) lleva datos, igual que su formulario.
  static const scalamin = PhotoProceso(
    ruta: 'scalamin',
    nombre: 'SCALAMIN',
    tabla: 'Operacion_Scalamin',
    horometros: ['diesel', 'percusion'],
    codigosConDatos: {'101'},
    campos: [
      PhotoCampo('metros_lineales', 'Metros lineales', numero: true, decimal: true),
      PhotoCampo('area_m2', 'Área (m²)', numero: true, decimal: true),
      PhotoCampo(
        'tipo_labor_texto',
        'Tipo de labor',
        catalogo: PhotoCatalogo.tiposLabor,
        // Leyenda "TIPO DE LABOR" de la hoja.
        equivalencias: {
          'F': 'FRENTE',
          'B': 'BREASTING',
          'R': 'REALCE',
          'D': 'DESQUINCHE',
          'S': 'SELLADA',
          'I': 'INTERSECCIÓN',
        },
      ),
    ],
  );

  /// Hoja "Reporte diario de Scooptram". Cada viaje (origen → destino con sus
  /// cucharas) es un estado; 111 y 112 no llevan datos, igual que el formulario.
  static const scoop = PhotoProceso(
    ruta: 'scoop',
    nombre: 'SCOOPTRAM',
    tabla: 'Operacion_carguio',
    horometros: ['horometro'],
    formato: PhotoFormato.scoop,
    codigosSinDatos: {'111', '112'},
    reubicar: false,
    campos: [
      PhotoCampo(
        'labor_inicio',
        'Labor inicio (origen)',
        catalogo: PhotoCatalogo.origenes,
        autocompletar: true,
      ),
      PhotoCampo(
        'ubicacion_destino',
        'Destino',
        catalogo: PhotoCatalogo.destinos,
        autocompletar: true,
      ),
      PhotoCampo('n_cucharas', 'N° cucharas', numero: true, pendienteSiFalta: true),
      PhotoCampo(
        'material',
        'Material',
        catalogo: PhotoCatalogo.materiales,
        soloCatalogo: true,
      ),
      PhotoCampo('numero_volquete', 'N° volquete'),
    ],
  );

  /// Hoja "Reporte diario de equipo utilitario". Cada fila guarda su labor y
  /// su destino tal como están escritos: el trabajo se hace en el destino del
  /// traslado, así que la labor no se repite.
  static const scissor = PhotoProceso(
    ruta: 'scissor',
    nombre: 'SCISSOR',
    tabla: 'Operacion_scissor',
    horometros: ['diesel'],
    propagarLabor: false,
    procesoTipos: 'PERFORACIÓN HORIZONTAL',
    campos: [
      PhotoCampo(
        'destino',
        'Destino',
        catalogo: PhotoCatalogo.labores,
        autocompletar: true,
      ),
      PhotoCampo('ducto', 'Ducto (m)', numero: true),
      PhotoCampo('cable', 'Cable (m)', numero: true),
      PhotoCampo('tuberia', 'Tubería (m)', numero: true),
      PhotoCampo(
        'tipo_perforacion',
        'Tipo de labor',
        catalogo: PhotoCatalogo.tiposPerforacion,
        guardarComo: 'tipo_labor',
        idComo: 'tipo_labor_id',
        // Leyenda "TIPO DE LABOR" de la hoja; la R se repite (Realce y
        // Rehabilitación): se toma Realce.
        equivalencias: {
          'F': 'FRENTE',
          'B': 'BREASTING',
          'R': 'REALCE',
          'D': 'DESQUINCHE',
          'S': 'SELLADA',
          'M': 'MANTENIMIENTO',
          'TL': 'TALADROS LARGOS',
          'O': 'OTROS',
        },
      ),
    ],
  );

  /// Leyenda "TIPO DE LABOR" de la hoja de Scoop (no tiene campo propio en el
  /// formulario: va a las observaciones).
  static const tiposLaborScoop = {
    'F': 'FRENTE',
    'B': 'BREASTING',
    'R': 'REALCE',
    'D': 'DESQUINCHE',
    'S': 'SELLADA',
    'TL': 'TALADROS LARGOS',
    'O': 'OTROS',
  };
}
