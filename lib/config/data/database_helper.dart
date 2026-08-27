import 'dart:convert';
import 'dart:io';


import 'package:crypt/crypt.dart';
import 'package:i_miner/models/Empresa.dart';
import 'package:i_miner/models/guardia.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:i_miner/models/Accesorio.dart';
import 'package:i_miner/models/Equipo.dart';
import 'package:i_miner/models/Explosivo.dart';
import 'package:i_miner/models/PlanMensual.dart';
import 'package:i_miner/models/PlanMetraje.dart';
import 'package:i_miner/models/PlanProduccion.dart';
import 'package:i_miner/models/Seccion.dart';
import 'package:i_miner/models/TipoEquipo.dart';
import 'package:i_miner/models/TipoPerforacion.dart';
import 'package:i_miner/models/explosivos_uni.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;
  static String? _currentUserDni;
  static bool _isInitialized = false;
  static const int _currentDbVersion = 28;

  DatabaseHelper._internal() {
    // Inicialización única para evitar múltiples llamadas
    if (!_isInitialized) {
      _initializeDatabaseFactory();
      _isInitialized = true;
    }
  }

  /// Inicializa el database factory según la plataforma
  static void _initializeDatabaseFactory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<void> setCurrentUserDni(String dni) async {
    _currentUserDni = dni;
    _database = await _initDatabase();
  }

  Future<String?> getCurrentUserDni() async {
  return _currentUserDni;
}

  /// Obtiene la instancia de la base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_currentUserDni == null) {
      throw Exception('DNI de usuario no establecido');
    }
    _database = await _initDatabase();
    return _database!;
  }


  /// Inicializa la base de datos
  Future<Database> _initDatabase() async {
    Directory documentsDirectory;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        documentsDirectory = await getApplicationDocumentsDirectory();
      } else {
        // Para Windows/Linux/MacOS
        documentsDirectory = await getApplicationSupportDirectory();
        // Alternativa: Guardar en AppData
        // documentsDirectory = Directory(join(Platform.environment['APPDATA']!, 'Seminco'));
      }

      if (!await documentsDirectory.exists()) {
        await documentsDirectory.create(recursive: true);
      }

      String path =
          join(documentsDirectory.path, 'Seminco_db_catalina_huanca_${_currentUserDni!}.db');

      return await openDatabase(
        path,
        version: _currentDbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
    } catch (e) {
      print('Error al inicializar la base de datos: $e');
      rethrow;
    }
  }

  // Método de creación de tablas
  Future<void> _onCreate(Database db, int version) async {

    //Tabla de usuarios
        await db.execute('''
  CREATE TABLE Usuario (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    codigo_dni TEXT NOT NULL UNIQUE,
    apellidos TEXT NOT NULL,
    nombres TEXT NOT NULL,
    cargo TEXT,
    empresa TEXT,
    guardia TEXT,
    autorizado_equipo TEXT,
    area TEXT,
    clasificacion TEXT,
    correo TEXT,
    password TEXT NOT NULL,
    firma TEXT,
    rol TEXT,
    operaciones_autorizadas TEXT,
    createdAt TEXT NOT NULL,
    updatedAt TEXT NOT NULL
  )
''');

// Tabla de planes mensuales
    await db.execute('''
  CREATE TABLE PlanMensual(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    anio INTEGER,
    mes TEXT,
    minado_tipo TEXT, 
    empresa TEXT,
    zona TEXT,
    area TEXT,
    tipo_mineral TEXT,
    fase TEXT,
    estructura_veta TEXT,
    nivel TEXT,
    tipo_labor TEXT,
    labor TEXT,
    ala TEXT,
    avance_m REAL,
    ancho_m REAL,
    alto_m REAL,
    tms REAL,
    ${List.generate(28, (i) => "col_${i + 1}A TEXT").join(", ")},
    ${List.generate(28, (i) => "col_${i + 1}B TEXT").join(", ")}
  )
''');

    await db.execute('''
  CREATE TABLE PlanProduccion (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    anio INTEGER,
    mes TEXT NOT NULL,
    semana TEXT NOT NULL,
    mina TEXT NOT NULL,
    zona TEXT NOT NULL,
    area TEXT NOT NULL,
    fase TEXT NOT NULL,
    minado_tipo TEXT NOT NULL,
    tipo_labor TEXT NOT NULL,
    tipo_mineral TEXT NOT NULL,
    estructura_veta TEXT NOT NULL,
    nivel TEXT,
    block TEXT,
    labor TEXT NOT NULL,
    ala TEXT,
    ancho_veta REAL,
    ancho_minado_sem REAL,
    ancho_minado_mes REAL,
    ag_gr REAL,
    porcentaje_cu REAL,
    porcentaje_pb REAL,
    porcentaje_zn REAL,
    vpt_act REAL,
    vpt_final REAL,
    cut_off_1 REAL,
    cut_off_2 REAL,
    
    programado TEXT CHECK(programado IN ('Programado', 'No Programado')) NOT NULL DEFAULT 'Programado',

    ${List.generate(28, (i) => "columna_${i + 1}A TEXT").join(", ")},
    ${List.generate(28, (i) => "columna_${i + 1}B TEXT").join(", ")},

    createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )
''');

    await db.execute('''
  CREATE TABLE PlanMetraje (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    anio INTEGER,
    mes TEXT NOT NULL,
    semana TEXT NOT NULL,
    mina TEXT NOT NULL,
    zona TEXT NOT NULL,
    area TEXT NOT NULL,
    fase TEXT NOT NULL,
    minado_tipo TEXT NOT NULL,
    tipo_labor TEXT NOT NULL,
    tipo_mineral TEXT NOT NULL,
    estructura_veta TEXT NOT NULL,
    nivel TEXT,
    block TEXT,
    labor TEXT NOT NULL,
    ala TEXT,
    ancho_veta REAL,
    ancho_minado_sem REAL,
    ancho_minado_mes REAL,
    burden REAL,
    espaciamiento REAL,
    longitud_perforacion REAL,
    programado TEXT CHECK(programado IN ('Programado', 'No Programado')) NOT NULL DEFAULT 'Programado',
    ${List.generate(28, (i) => "columna_${i + 1}A TEXT").join(", ")},
    ${List.generate(28, (i) => "columna_${i + 1}B TEXT").join(", ")},
    createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )
''');

//tabla de equipos 
await db.execute('''
CREATE TABLE Equipo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT,
  proceso TEXT,
  codigo TEXT,
  marca TEXT,
  modelo TEXT,
  serie TEXT,
  tipo TEXT,
  capasidad TEXT,
  anioFabricacion INTEGER,
  fechaIngreso TEXT,
  capacidadYd3 REAL,
  capacidadM3 REAL
)
''');

await db.execute('''
CREATE TABLE Empresa (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT
)
''');

await db.execute('''
CREATE TABLE TipoEquipo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL
)
''');

await db.execute('''
CREATE TABLE Seccion (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  proceso TEXT,
  nombre TEXT
)
''');

await db.execute('''
CREATE TABLE Guardia (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guardia TEXT NOT NULL
)
''');

    await db.execute('''
  CREATE TABLE TipoPerforacion (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    proceso TEXT NULL,
    permitido_medicion INTEGER NOT NULL DEFAULT 0
  )
''');

    await db.execute('''
  CREATE TABLE Secciones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    proceso TEXT NULL
  )
''');

//Tabla de checklist
await db.execute('''
  CREATE TABLE IF NOT EXISTS checklist_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    proceso TEXT NOT NULL,
    categoria TEXT NOT NULL,
    nombre TEXT NOT NULL
  )
''');

//Tala de estados
    await db.execute('''CREATE TABLE EstadostBD(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    estado_principal TEXT,
    codigo TEXT,
    tipo_estado TEXT,
    categoria TEXT,
    proceso TEXT
  )''');

  await db.execute('''
CREATE TABLE jefe_guardias (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombres TEXT NOT NULL,
  apellidos TEXT NOT NULL
)
''');

await db.execute('''
CREATE TABLE checklists_telemando (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL
)
''');

await db.execute('''
CREATE TABLE longitud_barras (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  proceso TEXT NOT NULL,
  longitud_pies REAL NOT NULL
)
''');

await db.execute('''
CREATE TABLE pernos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tipo_perno TEXT NOT NULL,
  longitud REAL NOT NULL
)
''');

await db.execute('''
CREATE TABLE mallas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tipo_malla TEXT NOT NULL
)
''');

await db.execute('''
CREATE TABLE origen_destino(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  proceso TEXT,
  tipo TEXT,
  nombre TEXT
)
''');

await db.execute('''
CREATE TABLE horometros_nube (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  operacion TEXT NOT NULL,
  tipo_horometro TEXT NOT NULL, 
  inicio REAL,
  final REAL,
  op INTEGER,
  inop INTEGER
)
''');

  // perforacion taladro largo
  await db.execute('''
CREATE TABLE Operacion_tal_largo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT,
idNube INTEGER,
Hora_envio TEXT,
  turno TEXT,
  seccion TEXT,
  operador TEXT,
  jefe_guardia TEXT,
  equipo TEXT,
  n_equipo TEXT,
  modelo_equipo TEXT,
  registros TEXT,
  horometros TEXT,
  condiciones_equipo TEXT,
  check_list TEXT,
  control_llantas TEXT,
  estado TEXT DEFAULT 'activo',
  envio INTEGER DEFAULT 0
)
''');

// perforacion taladro horizoontal
  await db.execute('''
CREATE TABLE Operacion_tal_horizontal (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT,
idNube INTEGER,
Hora_envio TEXT,
  turno TEXT,
  seccion TEXT,
  operador TEXT,
  jefe_guardia TEXT,
  equipo TEXT,
  n_equipo TEXT,
  modelo_equipo TEXT,
  registros TEXT,
  horometros TEXT,
  condiciones_equipo TEXT,
  check_list TEXT,
  control_llantas TEXT,
  estado TEXT DEFAULT 'activo',
  envio INTEGER DEFAULT 0
)
''');

// perforacion empernador
  await db.execute('''
CREATE TABLE Operacion_empernador (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT,
idNube INTEGER,
Hora_envio TEXT,
  turno TEXT,
  seccion TEXT,
  operador TEXT,
  jefe_guardia TEXT,
  equipo TEXT,
  n_equipo TEXT,
  tipo_equipo TEXT,
  registros TEXT,
  horometros TEXT,
  condiciones_equipo TEXT,
  check_list TEXT,
  control_llantas TEXT,
  estado TEXT DEFAULT 'activo',
  envio INTEGER DEFAULT 0
)
''');


  await db.execute('''
CREATE TABLE Operacion_carguio (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT,
idNube INTEGER,
Hora_envio TEXT,
  turno TEXT,
  seccion TEXT,
  operador TEXT,
  jefe_guardia TEXT,
  equipo TEXT,
  n_equipo TEXT,
  capacidad TEXT,
  tipo_equipo TEXT,
  registros TEXT,
  horometros TEXT,
  condiciones_equipo TEXT,
  programa_trabajo TEXT,
  check_list TEXT,
  check_list_telemando TEXT,
  control_llantas TEXT,
  estado TEXT DEFAULT 'activo',
  envio INTEGER DEFAULT 0
)
''');

  await db.execute('''
CREATE TABLE Operacion_volquetes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  idNube INTEGER,
  fecha TEXT,
  turno TEXT,
  guardia TEXT,
  n_volquete TEXT,
  operador TEXT,
  empresa TEXT,
  jefe_guardia TEXT,
  registros TEXT,
  horometros TEXT,
  estado TEXT DEFAULT 'activo',
  envio INTEGER DEFAULT 0
)
''');


  await db.execute('''
CREATE TABLE Operacion_Dumper (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT,
idNube INTEGER,
Hora_envio TEXT,
  turno TEXT,
  seccion TEXT,
  operador TEXT,
  jefe_guardia TEXT,
  equipo TEXT,
  n_equipo TEXT,
  capacidad TEXT,
  tipo_equipo TEXT,
  registros TEXT,
  horometros TEXT,
  condiciones_equipo TEXT,
  programa_trabajo TEXT,
  check_list TEXT,
  check_list_telemando TEXT,
  control_llantas TEXT,
  estado TEXT DEFAULT 'activo',
  envio INTEGER DEFAULT 0
)
''');


  await db.execute('''
CREATE TABLE Operacion_rompebanco(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT,
idNube INTEGER,
Hora_envio TEXT,
  turno TEXT,
  operador TEXT,
  jefe_guardia TEXT,
  equipo TEXT,
  n_equipo TEXT,
  registros TEXT,
  horometros TEXT,
  condiciones_equipo TEXT,
  check_list TEXT,
  control_llantas TEXT,
  estado TEXT DEFAULT 'activo',
  envio INTEGER DEFAULT 0
)
''');

  await db.execute('''
CREATE TABLE Operacion_Scalamin(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT,
idNube INTEGER,
Hora_envio TEXT,
  turno TEXT,
  operador TEXT,
  jefe_guardia TEXT,
  equipo TEXT,
  n_equipo TEXT,
  registros TEXT,
  horometros TEXT,
  condiciones_equipo TEXT,
  check_list TEXT,
  control_llantas TEXT,
  estado TEXT DEFAULT 'activo',
  envio INTEGER DEFAULT 0
)
''');


  await db.execute('''
CREATE TABLE Operacion_scissor(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT,
idNube INTEGER,
Hora_envio TEXT,
  turno TEXT,
  operador TEXT,
  jefe_guardia TEXT,
  equipo TEXT,
  n_equipo TEXT,
  registros TEXT,
  horometros TEXT,
  condiciones_equipo TEXT,
  check_list TEXT,
  control_llantas TEXT,
  estado TEXT DEFAULT 'activo',
  envio INTEGER DEFAULT 0
)
''');


  await db.execute('''
CREATE TABLE Operacion_anfochanger(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT,
idNube INTEGER,
Hora_envio TEXT,
  turno TEXT,
  operador TEXT,
  jefe_guardia TEXT,
  equipo TEXT,
  n_equipo TEXT,
  registros TEXT,
  horometros TEXT,
  condiciones_equipo TEXT,
  check_list TEXT,
  control_llantas TEXT,
  estado TEXT DEFAULT 'activo',
  envio INTEGER DEFAULT 0
)
''');

//EXPLOSIVOS A MEJORAR------------------------------------------
await db.execute('''
  CREATE TABLE Datos_trabajo_exploraciones(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha TEXT,
    turno TEXT,
    taladro TEXT,
    pies_por_taladro TEXT,
    zona TEXT,
    tipo_labor TEXT,
    labor TEXT,
    ala TEXT,
    veta TEXT,
    nivel TEXT,
    tipo_perforacion TEXT,
    estado TEXT DEFAULT 'Creado',
    cerrado INTEGER DEFAULT 0,
    envio INTEGER DEFAULT 0,
    semanaDefault TEXT,
    semanaSelect TEXT,
    empresa TEXT,
    seccion TEXT,
    medicion INTEGER DEFAULT 0
  )
''');

    await db.execute('''
  CREATE TABLE Despacho (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    datos_trabajo_id INTEGER,
    mili_segundo REAL,
    medio_segundo REAL,
    observaciones TEXT,
    cantidad_retardos INTEGER,
    FOREIGN KEY(datos_trabajo_id) REFERENCES Datos_trabajo_exploraciones(id) ON DELETE CASCADE
  );
''');

    await db.execute('''
  CREATE TABLE DespachoDetalle (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    despacho_id INTEGER,
    nombre_material TEXT NOT NULL,  
    cantidad TEXT NOT NULL,
    FOREIGN KEY(despacho_id) REFERENCES Despacho(id) ON DELETE CASCADE
  );
''');

    await db.execute('''
  CREATE TABLE Devoluciones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    datos_trabajo_id INTEGER,
    mili_segundo REAL, 
    medio_segundo REAL,
    observaciones TEXT,
    cantidad_retardos INTEGER,
    FOREIGN KEY(datos_trabajo_id) REFERENCES Datos_trabajo_exploraciones(id) ON DELETE CASCADE
  );
''');

    await db.execute('''
  CREATE TABLE DevolucionDetalle (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    devolucion_id INTEGER,
    nombre_material TEXT NOT NULL,  
    cantidad TEXT NOT NULL,         
    FOREIGN KEY(devolucion_id) REFERENCES Devoluciones(id) ON DELETE CASCADE
  );
''');

    await db.execute('''
  CREATE TABLE DetalleDespachoExplosivos(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_despacho INTEGER,
    numero INTEGER,
    ms_cant1 TEXT,
    lp_cant1 TEXT,
    FOREIGN KEY (id_despacho) REFERENCES Despacho(id) ON DELETE CASCADE
  )
''');

    await db.execute('''
  CREATE TABLE DetalleDevolucionesExplosivos(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_devolucion INTEGER,
    numero INTEGER,
    ms_cant1 TEXT,
    lp_cant1 TEXT,
    FOREIGN KEY (id_devolucion) REFERENCES Devoluciones(id) ON DELETE CASCADE
  )
''');

await db.execute('''
  CREATE TABLE accesorios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo_accesorio TEXT NOT NULL,
    costo REAL NOT NULL,
    unidad_medida TEXT NOT NULL
  );
''');

await db.execute('''
  CREATE TABLE materiales (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    proceso TEXT NOT NULL,
    nombre TEXT NOT NULL
  );
''');

await db.execute('''
  CREATE TABLE explosivos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo_explosivo TEXT NOT NULL,
    cantidad_por_caja INTEGER NOT NULL,
    peso_unitario REAL NOT NULL,
    costo_por_kg REAL NOT NULL,
    unidad_medida TEXT NOT NULL
  );
''');

    await db.execute('''
  CREATE TABLE ExplosivosUni (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dato REAL NOT NULL,
    tipo TEXT NOT NULL
  )
''');

  await db.execute('''
  CREATE TABLE IF NOT EXISTS toneladas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha TEXT NOT NULL,
    turno TEXT,
    zona TEXT NOT NULL,
    tipo TEXT NOT NULL,
    labor TEXT NOT NULL,
    toneladas REAL NOT NULL
  )
''');

await db.execute('''
  CREATE TABLE nube_Datos_trabajo_exploraciones(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha TEXT,
    turno TEXT,
    taladro TEXT,
    pies_por_taladro TEXT,
    zona TEXT,
    tipo_labor TEXT,
    labor TEXT,
    ala TEXT,
    veta TEXT,
    nivel TEXT,
    tipo_perforacion TEXT,
    estado TEXT DEFAULT 'Creado',
    cerrado INTEGER DEFAULT 0,
    envio INTEGER DEFAULT 0,
    semanaDefault TEXT,
    semanaSelect TEXT,
    empresa TEXT,
    seccion TEXT,
    idnube TEXT,
    medicion INTEGER DEFAULT 0
  )
''');

    await db.execute('''
  CREATE TABLE nube_Despacho (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    datos_trabajo_id INTEGER,
    mili_segundo REAL,
    medio_segundo REAL,
    observaciones TEXT,
    FOREIGN KEY(datos_trabajo_id) REFERENCES nube_Datos_trabajo_exploraciones(id) ON DELETE CASCADE
  );
''');

    await db.execute('''
  CREATE TABLE nube_DespachoDetalle (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    despacho_id INTEGER,
    nombre_material TEXT NOT NULL,  
    cantidad TEXT NOT NULL,
    FOREIGN KEY(despacho_id) REFERENCES nube_Despacho(id) ON DELETE CASCADE
  );
''');

    await db.execute('''
  CREATE TABLE nube_Devoluciones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    datos_trabajo_id INTEGER,
    mili_segundo REAL,
    medio_segundo REAL,
    observaciones TEXT,
    FOREIGN KEY(datos_trabajo_id) REFERENCES nube_Datos_trabajo_exploraciones(id) ON DELETE CASCADE
  );
''');

    await db.execute('''
  CREATE TABLE nube_DevolucionDetalle (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    devolucion_id INTEGER,
    nombre_material TEXT NOT NULL,  
    cantidad TEXT NOT NULL,         
    FOREIGN KEY(devolucion_id) REFERENCES nube_Devoluciones(id) ON DELETE CASCADE
  );
''');

    await db.execute('''
  CREATE TABLE nube_DetalleDespachoExplosivos(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_despacho INTEGER,
    numero INTEGER,
    ms_cant1 TEXT,
    lp_cant1 TEXT,
    FOREIGN KEY (id_despacho) REFERENCES nube_Despacho(id) ON DELETE CASCADE
  )
''');

    await db.execute('''
  CREATE TABLE nube_DetalleDevolucionesExplosivos(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_devolucion INTEGER,
    numero INTEGER,
    ms_cant1 TEXT,
    lp_cant1 TEXT,
    FOREIGN KEY (id_devolucion) REFERENCES nube_Devoluciones(id) ON DELETE CASCADE
  )
''');

await db.execute('''
  CREATE TABLE mediciones_horizontal (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha TEXT NOT NULL,
    turno TEXT,
    empresa TEXT,
    zona TEXT,
    labor TEXT,
    veta TEXT,
    tipo_perforacion TEXT,
    kg_explosivos REAL,
    avance_programado REAL,
    ancho REAL,
    alto REAL,
    envio INTEGER DEFAULT 0,
    id_explosivo INTEGER,
    idnube INTEGER
  )
''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS mediciones_largo (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha TEXT NOT NULL,
      turno TEXT,
      empresa TEXT,
      zona TEXT,
      labor TEXT,
      veta TEXT,
      tipo_perforacion TEXT,
      kg_explosivos REAL,
      toneladas REAL,
      envio INTEGER DEFAULT 0,
      id_explosivo INTEGER,
      idnube INTEGER
    )
  ''');


  await db.execute('''
CREATE TABLE numero_retardos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  mes TEXT NOT NULL,
  anio INTEGER NOT NULL,
  cantidad INTEGER NOT NULL
)
''');

  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {

  if (oldVersion < 2) {

    /// Tabla TipoPerforacion
    if (!await _tablaExiste(db, 'TipoPerforacion')) {
      await db.execute('''
        CREATE TABLE TipoPerforacion (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL,
          proceso TEXT NULL,
          permitido_medicion INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }

    /// Tabla Secciones
    if (!await _tablaExiste(db, 'Secciones')) {
      await db.execute('''
        CREATE TABLE Secciones (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL,
          proceso TEXT NULL
        )
      ''');
    }
    }

  if (oldVersion < 3) {

    if (!await _tablaExiste(db, 'Operacion_tal_horizontal')) {
      await db.execute('''
        CREATE TABLE Operacion_tal_horizontal (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fecha TEXT,
          turno TEXT,
          seccion TEXT,
          operador TEXT,
          jefe_guardia TEXT,
          n_equipo TEXT,
          modelo_equipo TEXT,
          registros TEXT,
          horometros TEXT,
          condiciones_equipo TEXT,
          check_list TEXT,
          control_llantas TEXT,
          estado TEXT DEFAULT 'activo',
          envio INTEGER DEFAULT 0
        )
      ''');

      print("✅ Tabla Operacion_tal_horizontal creada en versión 3");
    }

  }
  if (oldVersion < 4) {

  // Operacion_tal_largo
  if (!await _columnaExiste(db, 'Operacion_tal_largo', 'equipo')) {
    await db.execute('ALTER TABLE Operacion_tal_largo ADD COLUMN equipo TEXT');
    print("✅ Columna equipo agregada en Operacion_tal_largo");
  }

  // Operacion_tal_horizontal
  if (!await _columnaExiste(db, 'Operacion_tal_horizontal', 'equipo')) {
    await db.execute('ALTER TABLE Operacion_tal_horizontal ADD COLUMN equipo TEXT');
    print("✅ Columna equipo agregada en Operacion_tal_horizontal");
  }

}if (oldVersion < 5) {

  /// Crear tabla Operacion_empernador
  if (!await _tablaExiste(db, 'Operacion_empernador')) {
    await db.execute('''
      CREATE TABLE Operacion_empernador (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT,
        turno TEXT,
        seccion TEXT,
        operador TEXT,
        jefe_guardia TEXT,
        equipo TEXT,
        n_equipo TEXT,
        tipo_equipo TEXT,
        registros TEXT,
        horometros TEXT,
        condiciones_equipo TEXT,
        check_list TEXT,
        control_llantas TEXT,
        estado TEXT DEFAULT 'activo',
        envio INTEGER DEFAULT 0
      )
    ''');

    print("✅ Tabla Operacion_empernador creada en versión 5");
  }

  /// Migración segura de columna tipo en tabla Equipo
  if (!await _columnaExiste(db, 'Equipo', 'tipo')) {
    await db.execute(
      'ALTER TABLE Equipo ADD COLUMN tipo TEXT'
    );

    print("✅ Columna tipo agregada en tabla Equipo");
  }

}if (oldVersion < 6) {

  /// Tabla TipoEquipo
  if (!await _tablaExiste(db, 'TipoEquipo')) {
    await db.execute('''
      CREATE TABLE TipoEquipo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');

    print("✅ Tabla TipoEquipo creada en versión 6");
  }

}if (oldVersion < 7) {

  if (!await _tablaExiste(db, 'checklists_telemando')) {
    await db.execute('''
    CREATE TABLE checklists_telemando (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL
    )
    ''');
  }

  if (!await _tablaExiste(db, 'Operacion_carguio')) {
    await db.execute('''
    CREATE TABLE Operacion_carguio (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha TEXT,
      turno TEXT,
      seccion TEXT,
      operador TEXT,
      jefe_guardia TEXT,
      equipo TEXT,
      n_equipo TEXT,
      capacidad TEXT,
      tipo_equipo TEXT,
      registros TEXT,
      horometros TEXT,
      condiciones_equipo TEXT,
      programa_trabajo TEXT,
      check_list TEXT,
      check_list_telemando TEXT,
      control_llantas TEXT,
      estado TEXT DEFAULT 'activo',
      envio INTEGER DEFAULT 0
    )
    ''');
  }

}if (oldVersion < 8) {

  if (!await _tablaExiste(db, 'Operacion_rompebanco')) {
    await db.execute('''
    CREATE TABLE Operacion_rompebanco(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha TEXT,
      turno TEXT,
      operador TEXT,
      jefe_guardia TEXT,
      equipo TEXT,
      n_equipo TEXT,
      registros TEXT,
      horometros TEXT,
      condiciones_equipo TEXT,
      check_list TEXT,
      control_llantas TEXT,
      estado TEXT DEFAULT 'activo',
      envio INTEGER DEFAULT 0
    )
    ''');
  }

}if (oldVersion < 9) {

    if (await _tablaExiste(db, 'Operacion_rompebanco')) {
      await db.delete('Operacion_rompebanco');
      // o también:
      // await db.execute('DELETE FROM Operacion_rompebanco');
    }

  }if (oldVersion < 10) {

  /// Tabla Operacion_scissor
  if (!await _tablaExiste(db, 'Operacion_scissor')) {
    await db.execute('''
    CREATE TABLE Operacion_scissor(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha TEXT,
      turno TEXT,
      operador TEXT,
      jefe_guardia TEXT,
      equipo TEXT,
      n_equipo TEXT,
      registros TEXT,
      horometros TEXT,
      condiciones_equipo TEXT,
      check_list TEXT,
      control_llantas TEXT,
      estado TEXT DEFAULT 'activo',
      envio INTEGER DEFAULT 0
    )
    ''');
  }

  /// Tabla Operacion_anfochanger
  if (!await _tablaExiste(db, 'Operacion_anfochanger')) {
    await db.execute('''
    CREATE TABLE Operacion_anfochanger(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha TEXT,
      turno TEXT,
      operador TEXT,
      jefe_guardia TEXT,
      equipo TEXT,
      n_equipo TEXT,
      registros TEXT,
      horometros TEXT,
      condiciones_equipo TEXT,
      check_list TEXT,
      control_llantas TEXT,
      estado TEXT DEFAULT 'activo',
      envio INTEGER DEFAULT 0
    )
    ''');
  }

}if (oldVersion < 11) {

  /// Tabla Seccion
  if (!await _tablaExiste(db, 'Seccion')) {
    await db.execute('''
    CREATE TABLE Seccion (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proceso TEXT,
      nombre TEXT
    )
    ''');
  }

}if (oldVersion < 12) {

  /// Tabla Operacion_Dumper
  if (!await _tablaExiste(db, 'Operacion_Dumper')) {
    await db.execute('''
    CREATE TABLE Operacion_Dumper (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha TEXT,
      turno TEXT,
      seccion TEXT,
      operador TEXT,
      jefe_guardia TEXT,
      equipo TEXT,
      n_equipo TEXT,
      capacidad TEXT,
      tipo_equipo TEXT,
      registros TEXT,
      horometros TEXT,
      condiciones_equipo TEXT,
      programa_trabajo TEXT,
      check_list TEXT,
      check_list_telemando TEXT,
      control_llantas TEXT,
      estado TEXT DEFAULT 'activo',
      envio INTEGER DEFAULT 0
    )
    ''');
  }

  /// Tabla Operacion_Scalamin
  if (!await _tablaExiste(db, 'Operacion_Scalamin')) {
    await db.execute('''
    CREATE TABLE Operacion_Scalamin(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha TEXT,
      turno TEXT,
      operador TEXT,
      jefe_guardia TEXT,
      equipo TEXT,
      n_equipo TEXT,
      registros TEXT,
      horometros TEXT,
      condiciones_equipo TEXT,
      check_list TEXT,
      control_llantas TEXT,
      estado TEXT DEFAULT 'activo',
      envio INTEGER DEFAULT 0
    )
    ''');
  }

}if (oldVersion < 13) {

  /// Tabla longitud_barras
  if (!await _tablaExiste(db, 'longitud_barras')) {
    await db.execute('''
    CREATE TABLE longitud_barras (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proceso TEXT NOT NULL,
      longitud_pies REAL NOT NULL
    )
    ''');
  }

  /// Tabla pernos
  if (!await _tablaExiste(db, 'pernos')) {
    await db.execute('''
    CREATE TABLE pernos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tipo_perno TEXT NOT NULL,
      longitud REAL NOT NULL
    )
    ''');
  }

  /// Tabla mallas
  if (!await _tablaExiste(db, 'mallas')) {
    await db.execute('''
    CREATE TABLE mallas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tipo_malla TEXT NOT NULL
    )
    ''');
  }

}if (oldVersion < 14) {

  /// Tabla horometros_nube
  if (!await _tablaExiste(db, 'horometros_nube')) {
    await db.execute('''
    CREATE TABLE horometros_nube (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      operacion TEXT NOT NULL,
      tipo_horometro TEXT NOT NULL, 
      inicio REAL,
      final REAL,
      op INTEGER,
      inop INTEGER
    )
    ''');
  }

}if (oldVersion < 15) {

  if (!await _tablaExiste(db, 'origen_destino')) {
    await db.execute('''
    CREATE TABLE origen_destino (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proceso TEXT,
      tipo TEXT,
      nombre TEXT
    )
    ''');
  }

}
if (oldVersion < 16) {

  // 🔹 Tabla principal
  if (!await _tablaExiste(db, 'Datos_trabajo_exploraciones')) {
    await db.execute('''
      CREATE TABLE Datos_trabajo_exploraciones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT,
        turno TEXT,
        taladro TEXT,
        pies_por_taladro TEXT,
        zona TEXT,
        tipo_labor TEXT,
        labor TEXT,
        ala TEXT,
        veta TEXT,
        nivel TEXT,
        tipo_perforacion TEXT,
        estado TEXT DEFAULT 'Creado',
        cerrado INTEGER DEFAULT 0,
        envio INTEGER DEFAULT 0,
        semanaDefault TEXT,
        semanaSelect TEXT,
        empresa TEXT,
        seccion TEXT,
        medicion INTEGER DEFAULT 0
      )
    ''');
  }

  // 🔹 Despacho
  if (!await _tablaExiste(db, 'Despacho')) {
    await db.execute('''
      CREATE TABLE Despacho (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        datos_trabajo_id INTEGER,
        mili_segundo REAL,
        medio_segundo REAL,
        observaciones TEXT,
        FOREIGN KEY(datos_trabajo_id) REFERENCES Datos_trabajo_exploraciones(id) ON DELETE CASCADE
      )
    ''');
  }

  // 🔹 DespachoDetalle
  if (!await _tablaExiste(db, 'DespachoDetalle')) {
    await db.execute('''
      CREATE TABLE DespachoDetalle (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        despacho_id INTEGER,
        nombre_material TEXT NOT NULL,  
        cantidad TEXT NOT NULL,
        FOREIGN KEY(despacho_id) REFERENCES Despacho(id) ON DELETE CASCADE
      )
    ''');
  }

  // 🔹 Devoluciones
  if (!await _tablaExiste(db, 'Devoluciones')) {
    await db.execute('''
      CREATE TABLE Devoluciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        datos_trabajo_id INTEGER,
        mili_segundo REAL,
        medio_segundo REAL,
        observaciones TEXT,
        FOREIGN KEY(datos_trabajo_id) REFERENCES Datos_trabajo_exploraciones(id) ON DELETE CASCADE
      )
    ''');
  }

  // 🔹 DevolucionDetalle
  if (!await _tablaExiste(db, 'DevolucionDetalle')) {
    await db.execute('''
      CREATE TABLE DevolucionDetalle (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        devolucion_id INTEGER,
        nombre_material TEXT NOT NULL,  
        cantidad TEXT NOT NULL,         
        FOREIGN KEY(devolucion_id) REFERENCES Devoluciones(id) ON DELETE CASCADE
      )
    ''');
  }

  // 🔹 Explosivos despacho
  if (!await _tablaExiste(db, 'DetalleDespachoExplosivos')) {
    await db.execute('''
      CREATE TABLE DetalleDespachoExplosivos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_despacho INTEGER,
        numero INTEGER,
        ms_cant1 TEXT,
        lp_cant1 TEXT,
        FOREIGN KEY (id_despacho) REFERENCES Despacho(id) ON DELETE CASCADE
      )
    ''');
  }

  // 🔹 Explosivos devoluciones
  if (!await _tablaExiste(db, 'DetalleDevolucionesExplosivos')) {
    await db.execute('''
      CREATE TABLE DetalleDevolucionesExplosivos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_devolucion INTEGER,
        numero INTEGER,
        ms_cant1 TEXT,
        lp_cant1 TEXT,
        FOREIGN KEY (id_devolucion) REFERENCES Devoluciones(id) ON DELETE CASCADE
      )
    ''');
  }
  // 🔹 NUEVAS TABLAS =======================

  // Accesorios
  if (!await _tablaExiste(db, 'accesorios')) {
    await db.execute('''
      CREATE TABLE accesorios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo_accesorio TEXT NOT NULL,
        costo REAL NOT NULL,
        unidad_medida TEXT NOT NULL
      )
    ''');
  }

  // Explosivos
  if (!await _tablaExiste(db, 'explosivos')) {
    await db.execute('''
      CREATE TABLE explosivos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo_explosivo TEXT NOT NULL,
        cantidad_por_caja INTEGER NOT NULL,
        peso_unitario REAL NOT NULL,
        costo_por_kg REAL NOT NULL,
        unidad_medida TEXT NOT NULL
      )
    ''');
  }

  // ExplosivosUni
  if (!await _tablaExiste(db, 'ExplosivosUni')) {
    await db.execute('''
      CREATE TABLE ExplosivosUni (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dato REAL NOT NULL,
        tipo TEXT NOT NULL
      )
    ''');
  }


}if (oldVersion < 17) {

  // 🔹 TONELADAS
  if (!await _tablaExiste(db, 'toneladas')) {
    await db.execute('''
      CREATE TABLE toneladas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        turno TEXT,
        zona TEXT NOT NULL,
        tipo TEXT NOT NULL,
        labor TEXT NOT NULL,
        toneladas REAL NOT NULL
      )
    ''');
  }

  // 🔹 NUBE DATOS TRABAJO (nueva versión con idnube)
  if (!await _tablaExiste(db, 'nube_Datos_trabajo_exploraciones')) {
    await db.execute('''
      CREATE TABLE nube_Datos_trabajo_exploraciones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT,
        turno TEXT,
        taladro TEXT,
        pies_por_taladro TEXT,
        zona TEXT,
        tipo_labor TEXT,
        labor TEXT,
        ala TEXT,
        veta TEXT,
        nivel TEXT,
        tipo_perforacion TEXT,
        estado TEXT DEFAULT 'Creado',
        cerrado INTEGER DEFAULT 0,
        envio INTEGER DEFAULT 0,
        semanaDefault TEXT,
        semanaSelect TEXT,
        empresa TEXT,
        seccion TEXT,
        idnube TEXT,
        medicion INTEGER DEFAULT 0
      )
    ''');
  }

  // 🔹 NUBE DESPACHO
  if (!await _tablaExiste(db, 'nube_Despacho')) {
    await db.execute('''
      CREATE TABLE nube_Despacho (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        datos_trabajo_id INTEGER,
        mili_segundo REAL,
        medio_segundo REAL,
        observaciones TEXT,
        FOREIGN KEY(datos_trabajo_id) REFERENCES nube_Datos_trabajo_exploraciones(id) ON DELETE CASCADE
      )
    ''');
  }

  // 🔹 NUBE DESPACHO DETALLE
  if (!await _tablaExiste(db, 'nube_DespachoDetalle')) {
    await db.execute('''
      CREATE TABLE nube_DespachoDetalle (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        despacho_id INTEGER,
        nombre_material TEXT NOT NULL,
        cantidad TEXT NOT NULL,
        FOREIGN KEY(despacho_id) REFERENCES nube_Despacho(id) ON DELETE CASCADE
      )
    ''');
  }

  // 🔹 NUBE DEVOLUCIONES
  if (!await _tablaExiste(db, 'nube_Devoluciones')) {
    await db.execute('''
      CREATE TABLE nube_Devoluciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        datos_trabajo_id INTEGER,
        mili_segundo REAL,
        medio_segundo REAL,
        observaciones TEXT,
        FOREIGN KEY(datos_trabajo_id) REFERENCES nube_Datos_trabajo_exploraciones(id) ON DELETE CASCADE
      )
    ''');
  }

  // 🔹 NUBE DEVOLUCION DETALLE
  if (!await _tablaExiste(db, 'nube_DevolucionDetalle')) {
    await db.execute('''
      CREATE TABLE nube_DevolucionDetalle (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        devolucion_id INTEGER,
        nombre_material TEXT NOT NULL,
        cantidad TEXT NOT NULL,
        FOREIGN KEY(devolucion_id) REFERENCES nube_Devoluciones(id) ON DELETE CASCADE
      )
    ''');
  }

  // 🔹 DETALLE DESPACHO EXPLOSIVOS
  if (!await _tablaExiste(db, 'nube_DetalleDespachoExplosivos')) {
    await db.execute('''
      CREATE TABLE nube_DetalleDespachoExplosivos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_despacho INTEGER,
        numero INTEGER,
        ms_cant1 TEXT,
        lp_cant1 TEXT,
        FOREIGN KEY (id_despacho) REFERENCES nube_Despacho(id) ON DELETE CASCADE
      )
    ''');
  }

  // 🔹 DETALLE DEVOLUCIONES EXPLOSIVOS
  if (!await _tablaExiste(db, 'nube_DetalleDevolucionesExplosivos')) {
    await db.execute('''
      CREATE TABLE nube_DetalleDevolucionesExplosivos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_devolucion INTEGER,
        numero INTEGER,
        ms_cant1 TEXT,
        lp_cant1 TEXT,
        FOREIGN KEY (id_devolucion) REFERENCES nube_Devoluciones(id) ON DELETE CASCADE
      )
    ''');
  }

  // 🔹 MEDICIONES HORIZONTAL
  if (!await _tablaExiste(db, 'mediciones_horizontal')) {
    await db.execute('''
      CREATE TABLE mediciones_horizontal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        turno TEXT,
        empresa TEXT,
        zona TEXT,
        labor TEXT,
        veta TEXT,
        tipo_perforacion TEXT,
        kg_explosivos REAL,
        avance_programado REAL,
        ancho REAL,
        alto REAL,
        envio INTEGER DEFAULT 0,
        id_explosivo INTEGER,
        idnube INTEGER
      )
    ''');
  }

  // 🔹 MEDICIONES LARGO
  if (!await _tablaExiste(db, 'mediciones_largo')) {
    await db.execute('''
      CREATE TABLE mediciones_largo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        turno TEXT,
        empresa TEXT,
        zona TEXT,
        labor TEXT,
        veta TEXT,
        tipo_perforacion TEXT,
        kg_explosivos REAL,
        toneladas REAL,
        envio INTEGER DEFAULT 0,
        id_explosivo INTEGER,
        idnube INTEGER
      )
    ''');
  }

}if (oldVersion < 19) {

  // 🔹 AGREGAR cantidad_retardos EN Despacho
  if (!await _columnaExiste(db, 'Despacho', 'cantidad_retardos')) {
    await db.execute('''
      ALTER TABLE Despacho ADD COLUMN cantidad_retardos INTEGER DEFAULT 0
    ''');
  }

  // 🔹 AGREGAR cantidad_retardos EN Devoluciones
  if (!await _columnaExiste(db, 'Devoluciones', 'cantidad_retardos')) {
    await db.execute('''
      ALTER TABLE Devoluciones ADD COLUMN cantidad_retardos INTEGER DEFAULT 0
    ''');
  }

}if (oldVersion < 20) {

  // 🔹 CREAR TABLA Guardia
  if (!await _tablaExiste(db, 'Guardia')) {
    await db.execute('''
      CREATE TABLE Guardia (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        guardia TEXT NOT NULL
      )
    ''');
  }

}if (oldVersion < 21) {

  // 🔹 AGREGAR idNube A TODAS LAS TABLAS

  final tablas = [
    'Operacion_tal_largo',
    'Operacion_tal_horizontal',
    'Operacion_empernador',
    'Operacion_carguio',
    'Operacion_Dumper',
    'Operacion_rompebanco',
    'Operacion_Scalamin',
    'Operacion_scissor',
    'Operacion_anfochanger',
  ];

  for (final tabla in tablas) {
    if (!await _columnaExiste(db, tabla, 'idNube')) {
      await db.execute('''
        ALTER TABLE $tabla ADD COLUMN idNube INTEGER DEFAULT 0
      ''');
    }
  }
  }if (oldVersion < 23) {

  // 🔹 CREAR TABLA materiales
  if (!await _tablaExiste(db, 'materiales')) {
    await db.execute('''
      CREATE TABLE materiales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');
  }

}if (oldVersion < 24) {

  // 🔹 CREAR TABLA Operacion_volquetes
  if (!await _tablaExiste(db, 'Operacion_volquetes')) {
    await db.execute('''
      CREATE TABLE Operacion_volquetes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        idNube INTEGER,
        fecha TEXT,
        turno TEXT,
        guardia TEXT,
        n_volquete TEXT,
        operador TEXT,
        empresa TEXT,
        jefe_guardia TEXT,
        registros TEXT,
        horometros TEXT,
        estado TEXT DEFAULT 'activo',
        envio INTEGER DEFAULT 0
      )
    ''');
  }

}if (oldVersion < 25) {

  // 🔹 CREAR TABLA Empresa
  if (!await _tablaExiste(db, 'Empresa')) {
    await db.execute('''
      CREATE TABLE Empresa (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT
      )
    ''');
  }

}if (oldVersion < 26) {

  // 🔹 RECREAR TABLA materiales
  if (await _tablaExiste(db, 'materiales')) {
    await db.execute('DROP TABLE materiales');
  }

  await db.execute('''
    CREATE TABLE materiales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proceso TEXT NOT NULL,
      nombre TEXT NOT NULL
    )
  ''');
}if (oldVersion < 27) {

  // 🔹 RECREAR TABLA materiales
  if (await _tablaExiste(db, 'materiales')) {
    await db.execute('DROP TABLE materiales');
  }

  await db.execute('''
    CREATE TABLE materiales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proceso TEXT NOT NULL,
      nombre TEXT NOT NULL
    )
  ''');
}if (oldVersion < 28) {
  // 🔹 AGREGAR Hora_envio A TODAS LAS TABLAS

  final tablas = [
    'Operacion_tal_largo',
    'Operacion_tal_horizontal',
    'Operacion_empernador',
    'Operacion_carguio',
    'Operacion_Dumper',
    'Operacion_rompebanco',
    'Operacion_Scalamin',
    'Operacion_scissor',
    'Operacion_anfochanger',
    'Operacion_volquetes'
  ];

  for (final tabla in tablas) {
    if (!await _columnaExiste(db, tabla, 'Hora_envio')) {
      await db.execute('''
        ALTER TABLE $tabla ADD COLUMN Hora_envio TEXT
      ''');
    }
  }
}
  
  }
  
Future<bool> _tablaExiste(Database db, String tableName) async {
  final result = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    [tableName]
  );
  return result.isNotEmpty;
}

  Future<bool> _columnaExiste(Database db, String tabla, String columna) async {
    final result = await db.rawQuery("PRAGMA table_info($tabla)");
    return result.any((col) => col['name'] == columna);
  }

  // Insertar datos en cualquier tabla
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  // Obtener todos los registros de cualquier tabla
  Future<List<Map<String, dynamic>>> getAll(String table) async {
    final db = await database;
    return await db.query(table);
  }

// Eliminar un registro de cualquier tabla
  Future<int> delete(String table, int id) async {
    final db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // Método para eliminar todos los registros de una tabla
  Future<int> deleteAll(String table) async {
    final db = await database;
    return await db.delete(table); // Elimina todos los registros de la tabla
  }

  // Actualizar un registro en cualquier tabla
  Future<int> update(String table, Map<String, dynamic> data, int id) async {
    final db = await database;
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

//USUARIOS
// **Guardar Usuario en SQLite**
  Future<void> saveUser(Map<String, dynamic> userData, String password) async {
    final db = await database;
    final hashedPassword =
        Crypt.sha256(password).toString(); // Encriptar la contraseña

    await db.insert(
      'Usuario',
      {
        'codigo_dni': userData['codigo_dni'],
        'apellidos': userData['apellidos'],
        'nombres': userData['nombres'],
        'cargo': userData['cargo'],
        'empresa': userData['empresa'],
        'guardia': userData['guardia'],
        'autorizado_equipo': userData['autorizado_equipo'],
        'area': userData['area'], // Nuevo campo
        'clasificacion': userData['clasificacion'],
        'correo': userData['correo'],
        'password': hashedPassword,
        'firma': userData['firma'] ?? '',
        'rol': userData['rol']?.toString() ?? '',
        'createdAt': userData['createdAt'] ??
            DateTime.now().toIso8601String(), // Fecha de creación
        'updatedAt': userData['updatedAt'] ??
            DateTime.now().toIso8601String(), // Fecha de actualización

        'operaciones_autorizadas':
            jsonEncode(userData['operaciones_autorizadas'] ?? {}),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  //Login cuando no hay conexion
  Future<bool> loginOffline(String dni, String password) async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> result = await db.query(
      'Usuario',
      where: 'codigo_dni = ?',
      whereArgs: [dni],
    );

    if (result.isNotEmpty) {
      final storedPassword = result.first['password'];
      return Crypt(storedPassword).match(password); // <- Usa `.match()`
    }

    return false;
  }

  Future<Map<String, dynamic>?> getUserByDni(String dni) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'Usuario',
      where: 'codigo_dni = ?',
      whereArgs: [dni],
    );

    if (result.isNotEmpty) {
      return result.first; // Devuelve el primer usuario encontrado
    }
    return null; // Devuelve null si no hay usuario con ese DNI
  }

  //ESTADOS
    Future<List<Map<String, dynamic>>> getEstadosBD(String proceso) async {
    final db = await database; // Obtiene la instancia de la base de datos
    return await db.query(
      'EstadostBD',
      where: 'proceso = ?',
      whereArgs: [proceso], // Filtra por el valor del proceso
    );
  }

  Future<List<Map<String, dynamic>>> getOrigenDestino(String proceso, String tipo) async {
  final db = await database;

  return await db.query(
    'origen_destino',
    where: 'proceso = ? AND tipo = ?',
    whereArgs: [proceso, tipo],
  );
}

//CHECKLIST
Future<List<Map<String, dynamic>>> getCheckListByProceso(String proceso) async {
  final db = await database;
  final result = await db.query(
    'checklist_items',
    where: 'proceso = ?',
    whereArgs: [proceso],
  );
  return result;
}

Future<List<Map<String, dynamic>>> getChecklistTelemando() async {
  final db = await database;
  final result = await db.query('checklists_telemando');
  return result;
}

Future<List<TipoEquipo>> getTiposEquipo() async {
  final db = await database; // Obtenemos la instancia de la DB
  final List<Map<String, dynamic>> maps = await db.query('TipoEquipo');

  return List.generate(
    maps.length,
    (i) => TipoEquipo.fromJson(maps[i]),
  );
}

Future<List<Empresa>> getEmpresas() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query('Empresa');

  return List.generate(
    maps.length,
    (i) => Empresa.fromJson(maps[i]),
  );
}

//PARA TODOS LAS OPERACIONES------------------------------------------------------------

Future<List<String>> getJefesGuardiaNombres() async {
  final db = await database;

  try {
    final result = await db.query(
      'jefe_guardias',
      columns: ['nombres', 'apellidos'],
      orderBy: 'apellidos ASC, nombres ASC',
    );

    final nombresCompletos = result.map((row) {
      final nombres = row['nombres'] as String? ?? '';
      final apellidos = row['apellidos'] as String? ?? '';
      return '$nombres $apellidos'.trim();
    }).toList();

    return nombresCompletos;
  } catch (e) {
    print("Error al obtener nombres de jefes de guardia: $e");
    return [];
  }
}


Future<List<Equipo>> getEquipos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Equipo');
    return List.generate(maps.length, (i) => Equipo.fromJson(maps[i]));
  }

  Future<List<Seccion>> getSeccionesByProceso(String proceso) async {
  final db = await database;

  final List<Map<String, dynamic>> maps = await db.query(
    'Seccion',
    where: 'proceso = ?',
    whereArgs: [proceso],
  );

  return List.generate(maps.length, (i) => Seccion.fromJson(maps[i]));
}

Future<List<Guardia>> getGuardias() async {
  final db = await database;

  final List<Map<String, dynamic>> maps = await db.query('Guardia');

  return List.generate(
    maps.length,
    (i) => Guardia.fromJson(maps[i]),
  );
}

Future<List<TipoPerforacion>> getTiposPerforacionByProceso(String proceso) async {
  final db = await database;

  final List<Map<String, dynamic>> maps = await db.query(
    'TipoPerforacion',
    where: 'proceso = ?',
    whereArgs: [proceso],
  );

  return List.generate(maps.length, (i) => TipoPerforacion.fromJson(maps[i]));
}

Future<List<PlanMensual>> getPlanesMensual() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('PlanMensual');
    return List.generate(maps.length, (i) => PlanMensual.fromJson(maps[i]));
  }

  Future<List<PlanProduccion>> getPlanesProduccion() async {
  final db = await database;
  final List<Map<String, dynamic>> maps =
      await db.query('PlanProduccion');

  return List.generate(
    maps.length,
    (i) => PlanProduccion.fromJson(maps[i]),
  );
}

Future<List<PlanMetraje>> getPlanesMetraje() async {
  final db = await database;
  final List<Map<String, dynamic>> maps =
      await db.query('PlanMetraje');

  return List.generate(
    maps.length,
    (i) => PlanMetraje.fromJson(maps[i]),
  );
}

  Future<List<Map<String, dynamic>>> getLongitudBarrasPorProceso(String proceso) async {
  final db = await database;

  return await db.query(
    'longitud_barras',
    where: 'proceso = ?',
    whereArgs: [proceso],
  );
}

Future<List<Map<String, dynamic>>> getPernos() async {
  final db = await database;

  return await db.query('pernos');
}

Future<List<Map<String, dynamic>>> getMallas() async {
  final db = await database;

  return await db.query('mallas');
}

Future<List<Map<String, dynamic>>> getHorometrosPorOperacion(String operacion) async {
  final db = await database;

  final result = await db.query(
    'horometros_nube',
    columns: ['tipo_horometro', 'final'], // 🔥 solo lo necesario
    where: 'operacion = ?',
    whereArgs: [operacion],
  );

  return result;
}


//OPERACION TALADRO LARGO  INICIO--------------------------------------------------------------------------------------------------------------
Future<int> insertOperacionTalLargo(
  String fecha,
  String turno,
  String seccion,
  String operador,
  String jefeGuardia,
  String equipo,
  String nEquipo,
  String modeloEquipo, {
  List<Map<String, dynamic>>? checkListJson,
  List<Map<String, dynamic>>? horometrosBase, // 🔥 NUEVO
}) async {
  final db = await database;

  // 🔥 estructura base (fallback seguro)
  Map<String, dynamic> horometrosJson = {
    'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'electrico': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'percusion': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  };

  // 🔥 si vienen datos de la nube, los usamos
  if (horometrosBase != null && horometrosBase.isNotEmpty) {

    for (var item in horometrosBase) {
      final tipo = item['tipo_horometro'];
      final finalValor = (item['final'] ?? 0).toDouble();

      if (horometrosJson.containsKey(tipo)) {
        horometrosJson[tipo]['inicio'] = finalValor;
      }
    }
  }

  // 🔹 resto igual
  Map<String, dynamic> condicionesEquipoJson = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '',
  };

  Map<String, dynamic> controlLlantasJson = {
    'numero1': false,
    'numero2': false,
    'numero3': false,
    'numero4': false,
  };

  String checkListStr = jsonEncode(checkListJson ?? []);

  return await db.insert(
    'Operacion_tal_largo',
    {
      'fecha': fecha,
      'turno': turno,
      'seccion': seccion,
      'operador': operador,
      'jefe_guardia': jefeGuardia,
      'equipo': equipo,
      'n_equipo': nEquipo,
      'modelo_equipo': modeloEquipo,
      'horometros': jsonEncode(horometrosJson),
      'condiciones_equipo': jsonEncode(condicionesEquipoJson),
      'check_list': checkListStr,
      'control_llantas': jsonEncode(controlLlantasJson),
    },
  );
}

Future<int> eliminarOperacionTalLargoFisico(int id) async {
  final db = await database;

  final result = await db.delete(
    'Operacion_tal_largo',
    where: 'id = ?',
    whereArgs: [id],
  );

  return result; // devuelve el número de filas eliminadas
}

Future<List<Map<String, dynamic>>> getOperacionTalLargoByTurnoAndFechaMaster(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_tal_largo',
    where: 'turno = ? AND fecha = ? AND estado IN (?, ?)',
    whereArgs: [turno, fecha, 'activo', 'parciales'],
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionTalLargoByTurnoAndFecha(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_tal_largo',
    where: 'turno = ? AND fecha = ?',
    whereArgs: [turno, fecha],
  );

  return result;
}

// Función para cerrar un estado (actualizar hora_final de un estado específico)
Future<bool> updateHoraFinal(int operacionId, int estadoId, String horaFinal) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  bool encontrado = false;
  String tipoEstado = "";

  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'].toString() == estadoId.toString()) {
      tipoEstado = registros[i]['estado']; // Guardar el tipo para log
      registros[i]['hora_final'] = horaFinal;
      encontrado = true;
      break;
    }
  }

  if (!encontrado) {
    print("⚠ Estado no encontrado en JSON");
    return false;
  }

  int updated = await db.update(
    'Operacion_tal_largo',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("✔ Hora final actualizada para estado $tipoEstado: $horaFinal");
  return updated > 0;
}

// Función para crear un nuevo estado en una operación existente
Future<Map<String, dynamic>?> createEstado(
  int operacionId,
  String estado,
  String codigo,
  String horaInicio, {
  String? horaFinal,
  Map<String, dynamic>? operacion,
}) async {
  final db = await database;

  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return null;
  }

  // 2. Parsear el JSON de registros existentes
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  // 3. Determinar el próximo número
  int nuevoNumero = 1;
  if (registros.isNotEmpty) {
    int ultimoNumero = registros.last['numero'] ?? 0;
    nuevoNumero = ultimoNumero + 1;
  }

  // 4. Crear el nuevo estado con ID único
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  // 5. Construir la lista de barras
  List<Map<String, dynamic>> barras = [];

  if (operacion?['barras'] != null) {
    barras = List<Map<String, dynamic>>.from(
      operacion!['barras'],
    );
  } else {
    barras = [
      {
        'n_fila': 0,
         'n_taladro': 0,
        'longitud_perforacion': 0.0,
         'n_barras': 0,
        'tipo_perforacion': operacion?['tipo_perforacion'] ?? '',
      }
    ];
  }

  // 6. Estructura completa del objeto operación
  Map<String, dynamic> operacionCompleta = {
    // Ubicación
    'nivel': operacion?['nivel'] ?? '',
    'tipo_labor': operacion?['tipo_labor'] ?? '',
    'labor': operacion?['labor'] ?? '',
    'ala': operacion?['ala'] ?? '',

    // Barras
    //'long_barras': operacion?['long_barras'] ?? '',
    'barras': barras,


    // Observaciones
    'observaciones': operacion?['observaciones'] ?? '',
  };

  // 7. Crear el nuevo estado
  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': nuevoNumero,
    'estado': estado,
    'codigo': codigo,
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': operacionCompleta,
  };

  // 8. Agregar al array
  registros.add(nuevoEstado);

  // 9. Guardar en la base de datos
  await db.update(
    'Operacion_tal_largo',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

// Función para actualizar un estado completo
Future<bool> updateEstado(
  int operacionId,
  int estadoId, {
  int? numero,
  String? estado,
  String? codigo,
  String? horaInicio,
  String? horaFinal,
  Map<String, String>? operacion,
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return false;
  }
  
  // 2. Parsear el JSON de registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Buscar y actualizar el estado específico
  bool encontrado = false;
  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'] == estadoId) {
      // Actualizar solo los campos proporcionados
      if (numero != null) registros[i]['numero'] = numero;
      if (estado != null) registros[i]['estado'] = estado;
      if (codigo != null) registros[i]['codigo'] = codigo;
      if (horaInicio != null) registros[i]['hora_inicio'] = horaInicio;
      if (horaFinal != null) registros[i]['hora_final'] = horaFinal;
      if (operacion != null) {
        registros[i]['operacion'] = {
          ...registros[i]['operacion'] as Map,
          ...operacion,
        };
      }
      encontrado = true;
      break;
    }
  }
  
  if (!encontrado) {
    return false;
  }
  
  // 4. Guardar los cambios
  int updated = await db.update(
    'Operacion_tal_largo',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

// Función para obtener todos los estados de una operación
Future<List<Map<String, dynamic>>> getEstadosByOperacionId(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return [];
  }
  
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  return registros.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<bool> deleteEstado(int operacionId, int estadoId) async {
  final db = await database;

  // 1. Obtener registros
  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return false;

  // 2. Parsear JSON
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  if (registros.isEmpty) return false;

  // 3. Convertir todo a Map seguro
  List<Map<String, dynamic>> lista =
      registros.map((e) => Map<String, dynamic>.from(e)).toList();

  // 4. Ordenar por numero (orden real)
  lista.sort((a, b) {
    return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
  });

  // 5. Buscar el estado a eliminar
  Map<String, dynamic>? estadoAEliminar;
  for (var e in lista) {
    if (e['id'] == estadoId) {
      estadoAEliminar = e;
      break;
    }
  }

  if (estadoAEliminar == null) return false;

  int numeroEliminar = estadoAEliminar['numero'] ?? 0;

  // 6. Filtrar (eliminar en cascada desde ese numero)
  List<Map<String, dynamic>> nuevosRegistros = [];
  List<Map<String, dynamic>> eliminados = [];

  for (var e in lista) {
    int numero = e['numero'] ?? 0;

    if (numero < numeroEliminar) {
      nuevosRegistros.add(e);
    } else {
      eliminados.add({
        'id': e['id'],
        'estado': e['estado'],
        'numero': numero,
        'hora_inicio': e['hora_inicio']
      });
    }
  }

  // Debug
  print("🗑️ Eliminados: ${eliminados.length}");
  for (var e in eliminados) {
    print("   - ${e['estado']} #${e['numero']} (${e['hora_inicio']})");
  }

  // 7. Renumerar secuencialmente
  for (int i = 0; i < nuevosRegistros.length; i++) {
    nuevosRegistros[i]['numero'] = i + 1;
  }

  // 8. Reconstruir horas finales (solo encadenar)
  for (int i = 0; i < nuevosRegistros.length; i++) {
    if (i < nuevosRegistros.length - 1) {
      nuevosRegistros[i]['hora_final'] =
          nuevosRegistros[i + 1]['hora_inicio'] ?? '';
    } else {
      nuevosRegistros[i]['hora_final'] = "";
    }
  }

  // 9. Guardar
  int updated = await db.update(
    'Operacion_tal_largo',
    {
      'registros': jsonEncode(nuevosRegistros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("📊 Final: ${nuevosRegistros.length} registros");

  return updated > 0;
}


//horometros -taladro largo
// Función para obtener los horómetros de una operación
Future<Map<String, dynamic>> getHorometrosByOperacionId(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['horometros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    // Si no hay datos, devolver estructura por defecto
    return {
      'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
      'electrico': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
      'percusion': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    };
  }
  
  String horometrosJson = result.first['horometros'] as String? ?? '{}';
  
  try {
    Map<String, dynamic> horometros = jsonDecode(horometrosJson);
    return horometros;
  } catch (e) {
    print('Error decodificando horómetros: $e');
    // Si hay error, devolver estructura por defecto
    return {
      'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
      'electrico': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
      'percusion': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    };
  }
}

// Función para actualizar los horómetros de una operación
Future<bool> updateHorometros(int operacionId, Map<String, dynamic> horometros) async {
  final db = await database;
  
  int updated = await db.update(
    'Operacion_tal_largo',
    {
      'horometros': jsonEncode(horometros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

// Obtener condiciones de equipo por operacionId
Future<Map<String, dynamic>> getCondicionesEquipoByOperacionId(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['condiciones_equipo'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultData = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '', // ✅ nuevo campo
  };

  if (result.isEmpty) {
    return defaultData;
  }

  String condicionesJson = result.first['condiciones_equipo'] as String? ?? '{}';

  try {
    Map<String, dynamic> condiciones = jsonDecode(condicionesJson);

    // 🔥 asegurar que el nuevo campo exista
    condiciones.putIfAbsent('horaLlenado', () => '');

    return condiciones;
  } catch (e) {
    print('Error decodificando condiciones de equipo: $e');
    return defaultData;
  }
}

// Actualizar condiciones de equipo de una operación
Future<bool> updateCondicionesEquipo(int operacionId, Map<String, dynamic> condiciones) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_tal_largo',
    {
      'condiciones_equipo': jsonEncode(condiciones),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

// Obtener checklist por operacionId
Future<List<Map<String, dynamic>>> getCheckListByOperacionId(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['check_list'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos, devolver lista vacía
    return [];
  }

  String checkListJson = result.first['check_list'] as String? ?? '[]';

  try {
    List<dynamic> lista = jsonDecode(checkListJson);
    // Asegurarse de que cada item sea Map<String, dynamic>
    return lista.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    print('Error decodificando checklist: $e');
    return [];
  }
}
// Actualizar checklist de una operación
Future<bool> updateCheckList(int operacionId, List<Map<String, dynamic>> checkList) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_tal_largo',
    {
      'check_list': jsonEncode(checkList),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}


// Obtener control de llantas por operacionId
Future<Map<String, dynamic>> getControlLlantasByOperacionId(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['control_llantas'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos devolver estructura por defecto
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }

  String controlJson = result.first['control_llantas'] as String? ?? '{}';

  try {
    Map<String, dynamic> control = jsonDecode(controlJson);
    return control;
  } catch (e) {
    print('Error decodificando control de llantas: $e');
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }
}

// Actualizar control de llantas de una operación
Future<bool> updateControlLlantas(
  int operacionId,
  Map<String, dynamic> controlLlantas,
) async {

  final db = await database;

  int updated = await db.update(
    'Operacion_tal_largo',
    {
      'control_llantas': jsonEncode(controlLlantas),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<Map<String, dynamic>> getOperacionByEstadoId(
  int operacionId,
  int estadoId,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      //'long_barras': '',
      'tipo_perforacion': '',
      'tipo_perforacion_id': null,
      'observaciones': '',
      'barras': [],
    };
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';

  try {
    List<dynamic> registros = jsonDecode(registrosJson);

    var estadoEncontrado = registros.firstWhere(
      (estado) => estado['id'] == estadoId,
      orElse: () => null,
    );

    if (estadoEncontrado != null &&
        estadoEncontrado.containsKey('operacion')) {

      final operacion =
          Map<String, dynamic>.from(estadoEncontrado['operacion']);

      // Compatibilidad con registros antiguos
      operacion.putIfAbsent('barras', () => []);

      return operacion;
    }

    return {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      //'long_barras': '',
      'tipo_perforacion': '',
      'tipo_perforacion_id': null,
      'observaciones': '',
      'barras': [],
    };
  } catch (e) {
    print('Error decodificando registros: $e');

    return {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      //'long_barras': '',
      'tipo_perforacion': '',
      'tipo_perforacion_id': null,
      'observaciones': '',
      'barras': [],
    };
  }
}

// Actualizar los datos de perforación de un estado específico
Future<bool> updateOperacionByEstadoId(
  int operacionId,
  int estadoId,
  Map<String, dynamic> operacionData,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    bool encontrado = false;
    
    // Buscar y actualizar el estado específico
    for (var i = 0; i < registros.length; i++) {
      if (registros[i]['id'] == estadoId) {
        // Mantener todos los datos del estado, solo actualizar el campo 'operacion'
        registros[i]['operacion'] = operacionData;
        encontrado = true;
        break;
      }
    }
    
    if (!encontrado) {
      print('⚠ Estado no encontrado en JSON');
      return false;
    }
    
    // Guardar en la base de datos
    int updated = await db.update(
      'Operacion_tal_largo',
      {
        'registros': jsonEncode(registros),
      },
      where: 'id = ?',
      whereArgs: [operacionId],
    );
    
    print('✔ Datos de perforación actualizados para estado $estadoId');
    return updated > 0;
  } catch (e) {
    print('Error actualizando datos de perforación: $e');
    return false;
  }
}

  Future<void> cerrarOperacion(int operacionId) async {
    final Database db = await DatabaseHelper().database;

    await db.update(
      'Operacion_tal_largo',
      {'estado': 'cerrado'}, // Nuevo estado
      where: 'id = ?',
      whereArgs: [operacionId], // Parámetro para evitar SQL Injection
    );
  }

  // Crear estado RESERVA (código 401)
Future<Map<String, dynamic>?> createReservaEstado(
  int operacionId,
  int numero,
  String horaInicio,
  String horaFinal,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  // Crear nuevo estado RESERVA
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;
  
  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': numero,
    'estado': 'RESERVA',
    'codigo': '401', // Código para RESERVA
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      //'long_barras': '',
      'tipo_perforacion': '',
      'observaciones': '',
    },
  };

  registros.add(nuevoEstado);

  await db.update(
    'Operacion_tal_largo',
    {'registros': jsonEncode(registros)},
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<Map<String, dynamic>?> getUltimoEstadoByOperacionId(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_largo',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';

  try {
    List<dynamic> registros = jsonDecode(registrosJson);

    if (registros.isEmpty) return null;

    // ✅ SIMPLE: el último insertado es el último real
    return Map<String, dynamic>.from(registros.last);

  } catch (e) {
    print('Error obteniendo último estado: $e');
    return null;
  }
}

//TALADRO HORIZONTAL INICIO--------------------------------------------------------------------------------------------------------------
Future<int> insertOperacionTalHorizontal(
  String fecha, 
  String turno,
  String seccion,
  String operador,
  String jefeGuardia,
  String equipo,
  String nEquipo,
  String modeloEquipo, {
  List<Map<String, dynamic>>? checkListJson,
  //List<Map<String, dynamic>>? horometrosBase, // 🔥 NUEVO
}) async {
  final db = await database;

  // 🔥 estructura base segura
  Map<String, dynamic> horometrosJson = {
    'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'electrico': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'percusion': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'electrico2': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'percusion2': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  };

  // 🔥 aplicar valores de nube si existen
  // if (horometrosBase != null && horometrosBase.isNotEmpty) {
  //   for (var item in horometrosBase) {
  //     final tipo = item['tipo_horometro'];
  //     final finalValor = (item['final'] ?? 0).toDouble();

  //     if (horometrosJson.containsKey(tipo)) {
  //       horometrosJson[tipo]['inicio'] = finalValor;
  //     }
  //   }
  // }

  // 🔹 resto igual
  Map<String, dynamic> condicionesEquipoJson = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '',
  };

  Map<String, dynamic> controlLlantasJson = {
    'numero1': false,
    'numero2': false,
    'numero3': false,
    'numero4': false,
  };

  String checkListStr = jsonEncode(checkListJson ?? []);

  return await db.insert(
    'Operacion_tal_horizontal',
    {
      'fecha': fecha,
      'turno': turno,
      'seccion': seccion,
      'operador': operador,
      'jefe_guardia': jefeGuardia,
      'equipo': equipo,
      'n_equipo': nEquipo,
      'modelo_equipo': modeloEquipo,
      'horometros': jsonEncode(horometrosJson),
      'condiciones_equipo': jsonEncode(condicionesEquipoJson),
      'check_list': checkListStr,
      'control_llantas': jsonEncode(controlLlantasJson),
    },
  );
}

Future<List<Map<String, dynamic>>> getOperacionTalHorizontalByTurnoAndFechaMaster(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_tal_horizontal',
    where: 'turno = ? AND fecha = ? AND estado IN (?, ?)',
    whereArgs: [turno, fecha, 'activo', 'parciales'],
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionTalHorizontalByTurnoAndFecha(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_tal_horizontal',
    where: 'turno = ? AND fecha = ?',
    whereArgs: [turno, fecha],
  );

  return result;
}

// Función para obtener todos los estados de una operación
Future<List<Map<String, dynamic>>> getEstadosByOperacionIdHorizontal(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return [];
  }
  
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  return registros.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<int> eliminarOperacionTalHorizontalFisico(int id) async {
  final db = await database;

  final result = await db.delete(
    'Operacion_tal_horizontal',
    where: 'id = ?',
    whereArgs: [id],
  );

  return result; // devuelve el número de filas eliminadas
}

Future<bool> updateHoraFinalHorizontal(int operacionId, int estadoId, String horaFinal) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  bool encontrado = false;
  String tipoEstado = "";

  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'].toString() == estadoId.toString()) {
      tipoEstado = registros[i]['estado']; // Guardar el tipo para log
      registros[i]['hora_final'] = horaFinal;
      encontrado = true;
      break;
    }
  }

  if (!encontrado) {
    print("⚠ Estado no encontrado en JSON");
    return false;
  }

  int updated = await db.update(
    'Operacion_tal_horizontal',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("✔ Hora final actualizada para estado $tipoEstado: $horaFinal");
  return updated > 0;
}

Future<Map<String, dynamic>?> createEstadoHorizontal(
  int operacionId, 
  String estado,
  String codigo, 
  String horaInicio, {
  String? horaFinal,
  Map<String, dynamic>? operacion, // Ahora acepta todos los campos de perforación
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return null;
  }
  
  // 2. Parsear el JSON de registros existentes
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Determinar el próximo número
  int nuevoNumero = 1;
  if (registros.isNotEmpty) {
    int ultimoNumero = registros.last['numero'] ?? 0;
    nuevoNumero = ultimoNumero + 1;
  }
  
  // 4. Crear el nuevo estado con ID único
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;
  
  // Estructura completa del objeto operacion con todos los campos
  Map<String, dynamic> operacionCompleta = {
    'nivel': operacion?['nivel'] ?? '',
    'tipo_labor': operacion?['tipo_labor'] ?? '',
    'labor': operacion?['labor'] ?? '',
    'ala': operacion?['ala'] ?? '',
    'tal_prod': operacion?['tal_prod'] ?? '',
    'tal_rimados': operacion?['tal_rimados'] ?? '',
    'tal_alivio': operacion?['tal_alivio'] ?? '',
    'long_barras': operacion?['long_barras'] ?? '',
    'material': operacion?['material'] ?? '', 
    'tipo_perforacion': operacion?['tipo_perforacion'] ?? '',
    'observaciones': operacion?['observaciones'] ?? '',
  };
  
  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': nuevoNumero,
    'estado': estado,
    'codigo': codigo,
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': operacionCompleta,
  };
  
  // 5. Agregar al array
  registros.add(nuevoEstado);
  
  // 6. Guardar en la base de datos
  await db.update(
    'Operacion_tal_horizontal',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return nuevoEstado;
}

Future<bool> updateEstadoHorizontal(
  int operacionId,
  int estadoId, {
  int? numero,
  String? estado,
  String? codigo,
  String? horaInicio,
  String? horaFinal,
  Map<String, String>? operacion,
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return false;
  }
  
  // 2. Parsear el JSON de registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Buscar y actualizar el estado específico
  bool encontrado = false;
  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'] == estadoId) {
      // Actualizar solo los campos proporcionados
      if (numero != null) registros[i]['numero'] = numero;
      if (estado != null) registros[i]['estado'] = estado;
      if (codigo != null) registros[i]['codigo'] = codigo;
      if (horaInicio != null) registros[i]['hora_inicio'] = horaInicio;
      if (horaFinal != null) registros[i]['hora_final'] = horaFinal;
      if (operacion != null) {
        registros[i]['operacion'] = {
          ...registros[i]['operacion'] as Map,
          ...operacion,
        };
      }
      encontrado = true;
      break;
    }
  }
  
  if (!encontrado) {
    return false;
  }
  
  // 4. Guardar los cambios
  int updated = await db.update(
    'Operacion_tal_horizontal',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

Future<Map<String, dynamic>> getOperacionByEstadoIdHorizontal(int operacionId, int estadoId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos, devolver estructura por defecto
    return {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      'tal_prod': '',
      'tal_rimados': '',
      'tal_alivio': '',
      'long_barras': '',
      'material': '',
      'tipo_perforacion': '',
      'observaciones': '',
    };
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';

  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    
    // Buscar el estado específico por su ID
    var estadoEncontrado = registros.firstWhere(
      (estado) => estado['id'] == estadoId,
      orElse: () => null,
    );
    
    if (estadoEncontrado != null && estadoEncontrado.containsKey('operacion')) {
      return estadoEncontrado['operacion'] as Map<String, dynamic>;
    } else {
      // Si no se encuentra o no tiene operacion, devolver estructura por defecto
      return {
        'nivel': '',
        'tipo_labor': '',
        'labor': '',
        'ala': '',
        'tal_prod': '',
        'tal_rimados': '',
        'tal_alivio': '',
        'long_barras': '',
        'material': '',
        'tipo_perforacion': '',
        'observaciones': '',
      };
    }
  } catch (e) {
    print('Error decodificando registros: $e');
    return {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      'tal_prod': '',
      'tal_rimados': '',
      'tal_alivio': '',
      'long_barras': '',
      'material': '',
      'tipo_perforacion': '',
      'observaciones': '',
    };
  }
}

Future<bool> updateOperacionByEstadoIdHorizontal(
  int operacionId,
  int estadoId,
  Map<String, dynamic> operacionData,
) async { 
  final db = await database;

  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    bool encontrado = false;
    
    // Buscar y actualizar el estado específico
    for (var i = 0; i < registros.length; i++) {
      if (registros[i]['id'] == estadoId) {
        // Mantener todos los datos del estado, solo actualizar el campo 'operacion'
        registros[i]['operacion'] = operacionData;
        encontrado = true;
        break;
      }
    }
    
    if (!encontrado) {
      print('⚠ Estado no encontrado en JSON');
      return false;
    }
    
    // Guardar en la base de datos
    int updated = await db.update(
      'Operacion_tal_horizontal',
      {
        'registros': jsonEncode(registros),
      },
      where: 'id = ?',
      whereArgs: [operacionId],
    );
    
    print('✔ Datos de perforación actualizados para estado $estadoId');
    return updated > 0;
  } catch (e) {
    print('Error actualizando datos de perforación: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> getCheckListByOperacionIdHorizontal(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['check_list'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos, devolver lista vacía
    return [];
  }

  String checkListJson = result.first['check_list'] as String? ?? '[]';

  try {
    List<dynamic> lista = jsonDecode(checkListJson);
    // Asegurarse de que cada item sea Map<String, dynamic>
    return lista.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    print('Error decodificando checklist: $e');
    return [];
  }
}

Future<Map<String, dynamic>> getHorometrosByOperacionIdHorizontal(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['horometros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    // Si no hay datos, devolver estructura por defecto
    return {
      'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
      'electrico': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
      'percusion': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    };
  }
  
  String horometrosJson = result.first['horometros'] as String? ?? '{}';
  
  try {
    Map<String, dynamic> horometros = jsonDecode(horometrosJson);
    return horometros;
  } catch (e) {
    print('Error decodificando horómetros: $e');
    // Si hay error, devolver estructura por defecto
    return {
      'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
      'electrico': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
      'percusion': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    };
  }
}

Future<Map<String, dynamic>?> getUltimoEstadoByOperacionIdHorizontal(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);

    if (registros.isEmpty) return null;

    // ✅ SIMPLE: el último insertado es el último real
    return Map<String, dynamic>.from(registros.last);

  } catch (e) {
    print('Error obteniendo último estado: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> createReservaEstadoHorizontal(
  int operacionId,
  int numero,
  String horaInicio,
  String horaFinal,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  // Crear nuevo estado RESERVA
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;
  
  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': numero,
    'estado': 'DEMORA',
    'codigo': '303', // Código para DEMORA
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      'tal_prod': '',
      'tal_rimados': '',
      'tal_alivio': '',
      'long_barras': '',
      'material': '',
      'tipo_perforacion': '',
      'observaciones': '',
    },
  };

  registros.add(nuevoEstado);

  await db.update(
    'Operacion_tal_horizontal',
    {'registros': jsonEncode(registros)},
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<void> cerrarOperacionHorizontal(int operacionId) async {
    final Database db = await DatabaseHelper().database;

    await db.update(
      'Operacion_tal_horizontal',
      {'estado': 'cerrado'}, // Nuevo estado
      where: 'id = ?',
      whereArgs: [operacionId], // Parámetro para evitar SQL Injection
    );
  }

  Future<Map<String, dynamic>> getCondicionesEquipoByOperacionIdHorizontal(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['condiciones_equipo'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultData = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '', // ✅ nuevo campo
  };

  if (result.isEmpty) {
    return defaultData;
  }

  String condicionesJson = result.first['condiciones_equipo'] as String? ?? '{}';

  try {
    Map<String, dynamic> condiciones = jsonDecode(condicionesJson);

    // 🔥 asegurar que el nuevo campo exista
    condiciones.putIfAbsent('horaLlenado', () => '');

    return condiciones;
  } catch (e) {
    print('Error decodificando condiciones de equipo: $e');
    return defaultData;
  }
}

Future<Map<String, dynamic>> getControlLlantasByOperacionIdHorizontal(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['control_llantas'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos devolver estructura por defecto
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }

  String controlJson = result.first['control_llantas'] as String? ?? '{}';

  try {
    Map<String, dynamic> control = jsonDecode(controlJson);
    return control;
  } catch (e) {
    print('Error decodificando control de llantas: $e');
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }
}

Future<bool> deleteEstadoHorizontal(int operacionId, int estadoId) async {
  final db = await database;

  // 1. Obtener registros
  final result = await db.query(
    'Operacion_tal_horizontal',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return false;

  // 2. Parsear JSON
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  if (registros.isEmpty) return false;

  // 3. Convertir todo a Map seguro
  List<Map<String, dynamic>> lista =
      registros.map((e) => Map<String, dynamic>.from(e)).toList();

  // 4. Ordenar por numero (orden real)
  lista.sort((a, b) {
    return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
  });

  // 5. Buscar el estado a eliminar
  Map<String, dynamic>? estadoAEliminar;
  for (var e in lista) {
    if (e['id'] == estadoId) {
      estadoAEliminar = e;
      break;
    }
  }

  if (estadoAEliminar == null) return false;

  int numeroEliminar = estadoAEliminar['numero'] ?? 0;

  // 6. Filtrar (eliminar en cascada desde ese numero)
  List<Map<String, dynamic>> nuevosRegistros = [];
  List<Map<String, dynamic>> eliminados = [];

  for (var e in lista) {
    int numero = e['numero'] ?? 0;

    if (numero < numeroEliminar) {
      nuevosRegistros.add(e);
    } else {
      eliminados.add({
        'id': e['id'],
        'estado': e['estado'],
        'numero': numero,
        'hora_inicio': e['hora_inicio']
      });
    }
  }

  // Debug
  print("🗑️ Eliminados: ${eliminados.length}");
  for (var e in eliminados) {
    print("   - ${e['estado']} #${e['numero']} (${e['hora_inicio']})");
  }

  // 7. Renumerar secuencialmente
  for (int i = 0; i < nuevosRegistros.length; i++) {
    nuevosRegistros[i]['numero'] = i + 1;
  }

  // 8. Reconstruir horas finales (solo encadenar)
  for (int i = 0; i < nuevosRegistros.length; i++) {
    if (i < nuevosRegistros.length - 1) {
      nuevosRegistros[i]['hora_final'] =
          nuevosRegistros[i + 1]['hora_inicio'] ?? '';
    } else {
      nuevosRegistros[i]['hora_final'] = "";
    }
  }

  // 9. Guardar
  int updated = await db.update(
    'Operacion_tal_horizontal',
    {
      'registros': jsonEncode(nuevosRegistros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("📊 Final: ${nuevosRegistros.length} registros");

  return updated > 0;
}

Future<bool> updateControlLlantasHorizontal(
  int operacionId,
  Map<String, dynamic> controlLlantas,
) async {

  final db = await database;

  int updated = await db.update(
    'Operacion_tal_horizontal',
    {
      'control_llantas': jsonEncode(controlLlantas),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCheckListHorizontal(int operacionId, List<Map<String, dynamic>> checkList) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_tal_horizontal',
    {
      'check_list': jsonEncode(checkList),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCondicionesEquipoHorizontal(int operacionId, Map<String, dynamic> condiciones) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_tal_horizontal',
    {
      'condiciones_equipo': jsonEncode(condiciones),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateHorometrosHorizontal(int operacionId, Map<String, dynamic> horometros) async {
  final db = await database;
  
  int updated = await db.update(
    'Operacion_tal_horizontal',
    {
      'horometros': jsonEncode(horometros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

//SOSTENIMIENTO INICIO---------------------------------------------------------------------------------------------------------------------------------------------
Future<int> insertOperacionEmpernador(
  String fecha,
  String turno,
  String seccion,
  String operador,
  String jefeGuardia,
  String equipo,
  String nEquipo,
  String tipoEquipo, {
  List<Map<String, dynamic>>? checkListJson,
  List<Map<String, dynamic>>? horometrosBase, // 🔥 NUEVO
}) async {
  final db = await database;

  // 🔥 estructura base (incluye "empernador")
  Map<String, dynamic> horometrosJson = {
    'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'electrico': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'percusion': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'empernador': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  };

  // 🔥 aplicar valores de nube
  if (horometrosBase != null && horometrosBase.isNotEmpty) {
    for (var item in horometrosBase) {
      final tipo = item['tipo_horometro'];
      final finalValor = (item['final'] ?? 0).toDouble();

      // 🔥 importante: validar que exista en el JSON base
      if (horometrosJson.containsKey(tipo)) {
        horometrosJson[tipo]['inicio'] = finalValor;
      }
    }
  }

  // 🔹 resto igual
  Map<String, dynamic> condicionesEquipoJson = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '',
  };

  Map<String, dynamic> controlLlantasJson = {
    'numero1': false,
    'numero2': false,
    'numero3': false,
    'numero4': false,
  };

  String checkListStr = jsonEncode(checkListJson ?? []);

  return await db.insert(
    'Operacion_empernador',
    {
      'fecha': fecha,
      'turno': turno,
      'seccion': seccion,
      'operador': operador,
      'jefe_guardia': jefeGuardia,
      'equipo': equipo,
      'n_equipo': nEquipo,
      'tipo_equipo': tipoEquipo,
      'horometros': jsonEncode(horometrosJson),
      'condiciones_equipo': jsonEncode(condicionesEquipoJson),
      'check_list': checkListStr,
      'control_llantas': jsonEncode(controlLlantasJson),
    },
  );
}

Future<List<Map<String, dynamic>>> getOperacionEmpernadorByTurnoAndFechaMaster(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_empernador',
    where: 'turno = ? AND fecha = ? AND estado IN (?, ?)',
    whereArgs: [turno, fecha, 'activo', 'parciales'],
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionEmpernadorByTurnoAndFecha(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_empernador',
    where: 'turno = ? AND fecha = ?',
    whereArgs: [turno, fecha],
  );

  return result;
}

// Función para obtener todos los estados de una operación
Future<List<Map<String, dynamic>>> getEstadosByOperacionIdEmpernador(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_empernador',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return [];
  }
  
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  return registros.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<int> eliminarOperacionTalEmpernadorFisico(int id) async {
  final db = await database;

  final result = await db.delete(
    'Operacion_empernador',
    where: 'id = ?',
    whereArgs: [id],
  );

  return result; // devuelve el número de filas eliminadas
}

Future<bool> updateHoraFinalEmpernador(int operacionId, int estadoId, String horaFinal) async {
  final db = await database;

  final result = await db.query(
    'Operacion_empernador',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  bool encontrado = false;
  String tipoEstado = "";

  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'].toString() == estadoId.toString()) {
      tipoEstado = registros[i]['estado']; // Guardar el tipo para log
      registros[i]['hora_final'] = horaFinal;
      encontrado = true;
      break;
    }
  }

  if (!encontrado) {
    print("⚠ Estado no encontrado en JSON");
    return false;
  }

  int updated = await db.update(
    'Operacion_empernador',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("✔ Hora final actualizada para estado $tipoEstado: $horaFinal");
  return updated > 0;
}

Future<Map<String, dynamic>?> createEstadoEmpernador(
  int operacionId, 
  String estado,
  String codigo, 
  String horaInicio, {
  String? horaFinal,
  Map<String, dynamic>? operacion, // Ahora acepta todos los campos de perforación
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_empernador',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return null;
  }
  
  // 2. Parsear el JSON de registros existentes
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Determinar el próximo número
  int nuevoNumero = 1;
  if (registros.isNotEmpty) {
    int ultimoNumero = registros.last['numero'] ?? 0;
    nuevoNumero = ultimoNumero + 1;
  }
  
  // 4. Crear el nuevo estado con ID único
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;
  
  // Estructura completa del objeto operacion con todos los campos
  Map<String, dynamic> operacionCompleta = {
  'nivel': operacion?['nivel'] ?? '',
  'tipo_labor': operacion?['tipo_labor'] ?? '',
  'labor': operacion?['labor'] ?? '',
  'ala': operacion?['ala'] ?? '',
  'tipo_pernos': operacion?['tipo_pernos'] ?? '',
  'log_pernos': operacion?['log_pernos'] ?? '',
  'n_pernos_instalados': operacion?['n_pernos_instalados'] ?? '',
  'tipo_malla': operacion?['tipo_malla'] ?? '',
  'mt52_malla': operacion?['mt52_malla'] ?? '',
  'sistematico_puntual': operacion?['sistematico_puntual'] ?? '',
  'observaciones': operacion?['observaciones'] ?? '',
};
  
  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': nuevoNumero,
    'estado': estado,
    'codigo': codigo,
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': operacionCompleta,
  };
  
  // 5. Agregar al array
  registros.add(nuevoEstado);
  
  // 6. Guardar en la base de datos
  await db.update(
    'Operacion_empernador',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return nuevoEstado;
}

Future<bool> updateEstadoEmpernador(
  int operacionId,
  int estadoId, {
  int? numero,
  String? estado,
  String? codigo,
  String? horaInicio,
  String? horaFinal,
  Map<String, String>? operacion,
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_empernador',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return false;
  }
  
  // 2. Parsear el JSON de registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Buscar y actualizar el estado específico
  bool encontrado = false;
  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'] == estadoId) {
      // Actualizar solo los campos proporcionados
      if (numero != null) registros[i]['numero'] = numero;
      if (estado != null) registros[i]['estado'] = estado;
      if (codigo != null) registros[i]['codigo'] = codigo;
      if (horaInicio != null) registros[i]['hora_inicio'] = horaInicio;
      if (horaFinal != null) registros[i]['hora_final'] = horaFinal;
      if (operacion != null) {
        registros[i]['operacion'] = {
          ...registros[i]['operacion'] as Map,
          ...operacion,
        };
      }
      encontrado = true;
      break;
    }
  }
  
  if (!encontrado) {
    return false;
  }
  
  // 4. Guardar los cambios
  int updated = await db.update(
    'Operacion_empernador',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

Future<Map<String, dynamic>> getOperacionByEstadoIdEmpernador(int operacionId, int estadoId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_empernador',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos, devolver estructura por defecto
    return {
  'nivel': '',
  'tipo_labor': '',
  'labor': '',
  'ala': '',
  'tipo_pernos': '',
  'log_pernos': '',
  'n_pernos_instalados': '',
  'tipo_malla': '',
  'mt52_malla': '',
  'sistematico_puntual': '',
  'observaciones': '',
};
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';

  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    
    // Buscar el estado específico por su ID
    var estadoEncontrado = registros.firstWhere(
      (estado) => estado['id'] == estadoId,
      orElse: () => null,
    );
    
    if (estadoEncontrado != null && estadoEncontrado.containsKey('operacion')) {
      return estadoEncontrado['operacion'] as Map<String, dynamic>;
    } else {
      // Si no se encuentra o no tiene operacion, devolver estructura por defecto
      return {
        'nivel': '',
  'tipo_labor': '',
  'labor': '',
  'ala': '',
  'tipo_pernos': '',
  'log_pernos': '',
  'n_pernos_instalados': '',
  'tipo_malla': '',
  'mt52_malla': '',
  'sistematico_puntual': '',
  'observaciones': '',
      };
    }
  } catch (e) {
    print('Error decodificando registros: $e');
    return {
      'nivel': '',
  'tipo_labor': '',
  'labor': '',
  'ala': '',
  'tipo_pernos': '',
  'log_pernos': '',
  'n_pernos_instalados': '',
  'tipo_malla': '',
  'mt52_malla': '',
  'sistematico_puntual': '',
  'observaciones': '',
    };
  }
}

Future<bool> updateOperacionByEstadoIdEmpernador(
  int operacionId,
  int estadoId,
  Map<String, dynamic> operacionData,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_empernador',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    bool encontrado = false;
    
    // Buscar y actualizar el estado específico
    for (var i = 0; i < registros.length; i++) {
      if (registros[i]['id'] == estadoId) {
        // Mantener todos los datos del estado, solo actualizar el campo 'operacion'
        registros[i]['operacion'] = operacionData;
        encontrado = true;
        break;
      }
    }
    
    if (!encontrado) {
      print('⚠ Estado no encontrado en JSON');
      return false;
    }
    
    // Guardar en la base de datos
    int updated = await db.update(
      'Operacion_empernador',
      {
        'registros': jsonEncode(registros),
      },
      where: 'id = ?',
      whereArgs: [operacionId],
    );
    
    print('✔ Datos de perforación actualizados para estado $estadoId');
    return updated > 0;
  } catch (e) {
    print('Error actualizando datos de perforación: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> getCheckListByOperacionIdEmpernador(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_empernador',
    columns: ['check_list'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos, devolver lista vacía
    return [];
  }

  String checkListJson = result.first['check_list'] as String? ?? '[]';

  try {
    List<dynamic> lista = jsonDecode(checkListJson);
    // Asegurarse de que cada item sea Map<String, dynamic>
    return lista.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    print('Error decodificando checklist: $e');
    return [];
  }
}

Future<Map<String, dynamic>> getHorometrosByOperacionIdEmpernador(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_empernador',
    columns: ['horometros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    // Si no hay datos, devolver estructura por defecto
    return {
      'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  'electrico': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  'percusion': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  'empernador': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    };
  }
  
  String horometrosJson = result.first['horometros'] as String? ?? '{}';
  
  try {
    Map<String, dynamic> horometros = jsonDecode(horometrosJson);
    return horometros;
  } catch (e) {
    print('Error decodificando horómetros: $e');
    // Si hay error, devolver estructura por defecto
    return {
      'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  'electrico': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  'percusion': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  'empernador': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    };
  }
}

Future<Map<String, dynamic>?> getUltimoEstadoByOperacionIdEmpernador(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_empernador',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
   try {
    List<dynamic> registros = jsonDecode(registrosJson);

    if (registros.isEmpty) return null;

    // ✅ SIMPLE: el último insertado es el último real
    return Map<String, dynamic>.from(registros.last);

  } catch (e) {
    print('Error obteniendo último estado: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> createReservaEstadoEmpernador(
  int operacionId,
  int numero,
  String horaInicio,
  String horaFinal,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_empernador',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  // Crear nuevo estado RESERVA
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;
  
  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': numero,
    'estado': 'RESERVA',
    'codigo': '401', // Código para RESERVA
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': {
  'nivel': '',
  'tipo_labor': '',
  'labor': '',
  'ala': '',
  'tipo_pernos': '',
  'log_pernos': '',
  'n_pernos_instalados': '',
  'tipo_malla': '',
  'mt52_malla': '',
  'sistematico_puntual': '',
  'observaciones': '',
},
  };

  registros.add(nuevoEstado);

  await db.update(
    'Operacion_empernador',
    {'registros': jsonEncode(registros)},
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<void> cerrarOperacionEmpernador(int operacionId) async {
    final Database db = await DatabaseHelper().database;

    await db.update(
      'Operacion_empernador',
      {'estado': 'cerrado'}, // Nuevo estado
      where: 'id = ?',
      whereArgs: [operacionId], // Parámetro para evitar SQL Injection
    );
  }

  Future<Map<String, dynamic>> getCondicionesEquipoByOperacionIdEmpernador(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_empernador',
    columns: ['condiciones_equipo'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultData = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '', // ✅ nuevo campo
  };

  if (result.isEmpty) {
    return defaultData;
  }

  String condicionesJson = result.first['condiciones_equipo'] as String? ?? '{}';

  try {
    Map<String, dynamic> condiciones = jsonDecode(condicionesJson);

    // 🔥 asegurar que el nuevo campo exista
    condiciones.putIfAbsent('horaLlenado', () => '');

    return condiciones;
  } catch (e) {
    print('Error decodificando condiciones de equipo: $e');
    return defaultData;
  }
}

Future<Map<String, dynamic>> getControlLlantasByOperacionIdEmpernador(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_empernador',
    columns: ['control_llantas'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos devolver estructura por defecto
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }

  String controlJson = result.first['control_llantas'] as String? ?? '{}';

  try {
    Map<String, dynamic> control = jsonDecode(controlJson);
    return control;
  } catch (e) {
    print('Error decodificando control de llantas: $e');
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }
}

Future<bool> deleteEstadoEmpernador(int operacionId, int estadoId) async {
  final db = await database;

  // 1. Obtener registros
  final result = await db.query(
    'Operacion_empernador',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return false;

  // 2. Parsear JSON
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  if (registros.isEmpty) return false;

  // 3. Convertir todo a Map seguro
  List<Map<String, dynamic>> lista =
      registros.map((e) => Map<String, dynamic>.from(e)).toList();

  // 4. Ordenar por numero (orden real)
  lista.sort((a, b) {
    return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
  });

  // 5. Buscar el estado a eliminar
  Map<String, dynamic>? estadoAEliminar;
  for (var e in lista) {
    if (e['id'] == estadoId) {
      estadoAEliminar = e;
      break;
    }
  }

  if (estadoAEliminar == null) return false;

  int numeroEliminar = estadoAEliminar['numero'] ?? 0;

  // 6. Filtrar (eliminar en cascada desde ese numero)
  List<Map<String, dynamic>> nuevosRegistros = [];
  List<Map<String, dynamic>> eliminados = [];

  for (var e in lista) {
    int numero = e['numero'] ?? 0;

    if (numero < numeroEliminar) {
      nuevosRegistros.add(e);
    } else {
      eliminados.add({
        'id': e['id'],
        'estado': e['estado'],
        'numero': numero,
        'hora_inicio': e['hora_inicio']
      });
    }
  }

  // Debug
  print("🗑️ Eliminados: ${eliminados.length}");
  for (var e in eliminados) {
    print("   - ${e['estado']} #${e['numero']} (${e['hora_inicio']})");
  }

  // 7. Renumerar secuencialmente
  for (int i = 0; i < nuevosRegistros.length; i++) {
    nuevosRegistros[i]['numero'] = i + 1;
  }

  // 8. Reconstruir horas finales (solo encadenar)
  for (int i = 0; i < nuevosRegistros.length; i++) {
    if (i < nuevosRegistros.length - 1) {
      nuevosRegistros[i]['hora_final'] =
          nuevosRegistros[i + 1]['hora_inicio'] ?? '';
    } else {
      nuevosRegistros[i]['hora_final'] = "";
    }
  }

  // 9. Guardar
  int updated = await db.update(
    'Operacion_empernador',
    {
      'registros': jsonEncode(nuevosRegistros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("📊 Final: ${nuevosRegistros.length} registros");

  return updated > 0;
}

Future<bool> updateControlLlantasEmpernador(
  int operacionId,
  Map<String, dynamic> controlLlantas,
) async {

  final db = await database;

  int updated = await db.update(
    'Operacion_empernador',
    {
      'control_llantas': jsonEncode(controlLlantas),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCheckListEmpernador(int operacionId, List<Map<String, dynamic>> checkList) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_empernador',
    {
      'check_list': jsonEncode(checkList),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCondicionesEquipoEmpernador(int operacionId, Map<String, dynamic> condiciones) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_empernador',
    {
      'condiciones_equipo': jsonEncode(condiciones),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateHorometrosEmpernador(int operacionId, Map<String, dynamic> horometros) async {
  final db = await database;
  
  int updated = await db.update(
    'Operacion_empernador',
    {
      'horometros': jsonEncode(horometros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

//CARGUIO INICIO SCOOPS---------------------------------------------------------------------------------------------------------------------------------------------
Future<int> insertOperacionCarguio(
  String fecha,
  String turno,
  String seccion,
  String operador,
  String jefeGuardia,
  String equipo,
  String nEquipo,
  String capacidad,
  String tipoEquipo, {
  List<Map<String, dynamic>>? checkListJson,
  List<Map<String, dynamic>>? checkListTelemandoJson,
  List<Map<String, dynamic>>? horometrosBase, // 🔥 NUEVO
}) async {

  final db = await database;

  /// 🔥 estructura base (solo uno)
  Map<String, dynamic> horometrosJson = {
    'horometro': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  };

  /// 🔥 aplicar valor de nube (solo uno)
  if (horometrosBase != null && horometrosBase.isNotEmpty) {

    final item = horometrosBase.first; // 👈 solo hay uno
    final finalValor = (item['final'] ?? 0).toDouble();

    horometrosJson['horometro']['inicio'] = finalValor;
  }

  /// Condiciones equipo
  Map<String, dynamic> condicionesEquipoJson = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '',
  };

  /// Control llantas
  Map<String, dynamic> controlLlantasJson = {
    'numero1': false,
    'numero2': false,
    'numero3': false,
    'numero4': false,
  };

  /// Programa de trabajo
  Map<String, dynamic> programaTrabajoJson = {
    'n_cucharas_programado': 0,
    'n_cucharas_realizado': 0,
  };

  /// Checklist
  String checkListStr = jsonEncode(checkListJson ?? []);

  /// Checklist telemando
  String checkListTelemandoStr = jsonEncode(checkListTelemandoJson ?? []);

  return await db.insert(
    'Operacion_carguio',
    {
      'fecha': fecha,
      'turno': turno,
      'seccion': seccion,
      'operador': operador,
      'jefe_guardia': jefeGuardia,
      'equipo': equipo,
      'n_equipo': nEquipo,
      'capacidad': capacidad,
      'tipo_equipo': tipoEquipo,
      'horometros': jsonEncode(horometrosJson),
      'condiciones_equipo': jsonEncode(condicionesEquipoJson),
      'programa_trabajo': jsonEncode(programaTrabajoJson),
      'check_list': checkListStr,
      'check_list_telemando': checkListTelemandoStr,
      'control_llantas': jsonEncode(controlLlantasJson),
    },
  );
}

Future<List<Map<String, dynamic>>> getOperacionCarguioByTurnoAndFechaMaster(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_carguio',
    where: 'turno = ? AND fecha = ? AND estado IN (?, ?)',
    whereArgs: [turno, fecha, 'activo', 'parciales'],
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionCarguioByTurnoAndFecha(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_carguio',
    where: 'turno = ? AND fecha = ?',
    whereArgs: [turno, fecha],
  );

  return result;
}

// Función para obtener todos los estados de una operación
Future<List<Map<String, dynamic>>> getEstadosByOperacionIdCarguio(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_carguio',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return [];
  }
  
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  return registros.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<int> eliminarOperacionTalCarguioFisico(int id) async {
  final db = await database;

  final result = await db.delete(
    'Operacion_carguio',
    where: 'id = ?',
    whereArgs: [id],
  );

  return result; // devuelve el número de filas eliminadas
}

Future<bool> updateHoraFinalCarguio(int operacionId, int estadoId, String horaFinal) async {
  final db = await database;

  final result = await db.query(
    'Operacion_carguio',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  bool encontrado = false;
  String tipoEstado = "";

  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'].toString() == estadoId.toString()) {
      tipoEstado = registros[i]['estado']; // Guardar el tipo para log
      registros[i]['hora_final'] = horaFinal;
      encontrado = true;
      break;
    }
  }

  if (!encontrado) {
    print("⚠ Estado no encontrado en JSON");
    return false;
  }

  int updated = await db.update(
    'Operacion_carguio',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("✔ Hora final actualizada para estado $tipoEstado: $horaFinal");
  return updated > 0;
}

Future<Map<String, dynamic>?> createEstadoCarguio(
  int operacionId,
  String estado,
  String codigo,
  String horaInicio, {
  String? horaFinal,
  Map<String, dynamic>? operacion,
}) async {

  final db = await database;

  // 1. Obtener registros actuales
  final result = await db.query(
    'Operacion_carguio',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return null;
  }

  // 2. Parsear registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  // 3. Calcular número
  int nuevoNumero = 1;
  if (registros.isNotEmpty) {
    int ultimoNumero = registros.last['numero'] ?? 0;
    nuevoNumero = ultimoNumero + 1;
  }

  // 4. ID único
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  /// NUEVA estructura de operación para CARGUÍO
  Map<String, dynamic> operacionCompleta = {
    'labor_inicio': operacion?['labor_inicio'] ?? '',

    'ubicacion_destino': operacion?['ubicacion_destino'] ?? '',

    'n_cucharas': operacion?['n_cucharas'] ?? 0,
    'material': operacion?['material'] ?? '', 
    'observaciones': operacion?['observaciones'] ?? '',

     // Nuevos campos (pueden ser texto o número)
    'mineral': operacion?['mineral'] ?? 0,
    'desmonte': operacion?['desmonte'] ?? 0,
    'relleno': operacion?['relleno'] ?? 0,
    'numero_volquete': operacion?['numero_volquete'] ?? 0,
    'relave': operacion?['relave'] ?? 0,
  };

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': nuevoNumero,
    'estado': estado,
    'codigo': codigo,
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': operacionCompleta,
  };

  // 5. Agregar al array
  registros.add(nuevoEstado);

  // 6. Guardar
  await db.update(
    'Operacion_carguio',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<bool> updateEstadoCarguio(
  int operacionId,
  int estadoId, {
  int? numero,
  String? estado,
  String? codigo,
  String? horaInicio,
  String? horaFinal,
  Map<String, String>? operacion,
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_carguio',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return false;
  }
  
  // 2. Parsear el JSON de registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Buscar y actualizar el estado específico
  bool encontrado = false;
  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'] == estadoId) {
      // Actualizar solo los campos proporcionados
      if (numero != null) registros[i]['numero'] = numero;
      if (estado != null) registros[i]['estado'] = estado;
      if (codigo != null) registros[i]['codigo'] = codigo;
      if (horaInicio != null) registros[i]['hora_inicio'] = horaInicio;
      if (horaFinal != null) registros[i]['hora_final'] = horaFinal;
      if (operacion != null) {
        registros[i]['operacion'] = {
          ...registros[i]['operacion'] as Map,
          ...operacion,
        };
      }
      encontrado = true;
      break;
    }
  }
  
  if (!encontrado) {
    return false;
  }
  
  // 4. Guardar los cambios
  int updated = await db.update(
    'Operacion_carguio',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

Future<Map<String, dynamic>> getOperacionByEstadoIdCarguio(int operacionId, int estadoId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_carguio',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'labor_inicio': '',
      'ubicacion_destino': '',
      'n_cucharas': 0,
      'observaciones': '',
      'material': '',
       // NUEVOS CAMPOS
      'mineral': 0,
      'desmonte': 0,
      'relleno': 0,
      'numero_volquete': 0,
      'relave': 0,
    };
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';

  try {
    List<dynamic> registros = jsonDecode(registrosJson);

    var estadoEncontrado = registros.firstWhere(
      (estado) => estado['id'] == estadoId,
      orElse: () => null,
    );

    if (estadoEncontrado != null && estadoEncontrado.containsKey('operacion')) {
      return estadoEncontrado['operacion'] as Map<String, dynamic>;
    } else {
      return {
        'labor_inicio': '',
        'ubicacion_destino': '',
        'n_cucharas': 0,
        'observaciones': '',
        // NUEVOS CAMPOS
        'mineral': 0,
        'desmonte': 0,
        'relleno': 0,
        'numero_volquete': 0,
        'relave': 0,
      };
    }
  } catch (e) {
    print('Error decodificando registros: $e');

    return {
      'labor_inicio': '',
      'ubicacion_destino': '',
      'n_cucharas': 0,
      'observaciones': '',
      'material': '',
      // NUEVOS CAMPOS
      'mineral': 0,
      'desmonte': 0,
      'relleno': 0,
      'numero_volquete': 0,
      'relave': 0,
    };
  }
}

Future<bool> updateOperacionByEstadoIdCarguio(
  int operacionId,
  int estadoId,
  Map<String, dynamic> operacionData,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_carguio',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    bool encontrado = false;
    
    // Buscar y actualizar el estado específico
    for (var i = 0; i < registros.length; i++) {
      if (registros[i]['id'] == estadoId) {
        // Mantener todos los datos del estado, solo actualizar el campo 'operacion'
        registros[i]['operacion'] = operacionData;
        encontrado = true;
        break;
      }
    }
    
    if (!encontrado) {
      print('⚠ Estado no encontrado en JSON');
      return false;
    }
    
    // Guardar en la base de datos
    int updated = await db.update(
      'Operacion_carguio',
      {
        'registros': jsonEncode(registros),
      },
      where: 'id = ?',
      whereArgs: [operacionId],
    );
    
    print('✔ Datos de perforación actualizados para estado $estadoId');
    return updated > 0;
  } catch (e) {
    print('Error actualizando datos de perforación: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> getCheckListByOperacionIdCarguio(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_carguio',
    columns: ['check_list'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos, devolver lista vacía
    return [];
  }

  String checkListJson = result.first['check_list'] as String? ?? '[]';

  try {
    List<dynamic> lista = jsonDecode(checkListJson);
    // Asegurarse de que cada item sea Map<String, dynamic>
    return lista.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    print('Error decodificando checklist: $e');
    return [];
  }
}

Future<Map<String, dynamic>> getHorometrosByOperacionIdCarguio(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_carguio',
    columns: ['horometros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'horometro': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      }
    };
  }

  String horometrosJson = result.first['horometros'] as String? ?? '{}';

  try {
    Map<String, dynamic> horometros = jsonDecode(horometrosJson);

    // Si el JSON está vacío
    if (horometros.isEmpty) {
      return {
        'horometro': {
          'inicio': 0,
          'final': 0,
          'op': true,
          'inop': false
        }
      };
    }

    return horometros;
  } catch (e) {
    print('Error decodificando horómetros: $e');

    return {
      'horometro': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      }
    };
  }
}

Future<Map<String, dynamic>?> getUltimoEstadoByOperacionIdCarguio(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_carguio',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
   try {
    List<dynamic> registros = jsonDecode(registrosJson);

    if (registros.isEmpty) return null;

    // ✅ SIMPLE: el último insertado es el último real
    return Map<String, dynamic>.from(registros.last);

  } catch (e) {
    print('Error obteniendo último estado: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> createReservaEstadoCarguio(
  int operacionId,
  int numero,
  String horaInicio,
  String horaFinal,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_carguio',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': numero,
    'estado': 'DEMORA',
    'codigo': '303',
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': {
      'labor_inicio': '',
      'ubicacion_destino': '',
      'n_cucharas': 0,
      'material': '',
      'observaciones': '',
      // NUEVOS CAMPOS - usar string vacío en lugar de 0
      'mineral': '',
      'desmonte': '',
      'relleno': '',
      'numero_volquete': '',
      'relave': '',
    },
  };

  registros.add(nuevoEstado);

  await db.update(
    'Operacion_carguio',
    {'registros': jsonEncode(registros)},
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<void> cerrarOperacionCarguio(int operacionId) async {
    final Database db = await DatabaseHelper().database;

    await db.update(
      'Operacion_carguio',
      {'estado': 'cerrado'}, // Nuevo estado
      where: 'id = ?',
      whereArgs: [operacionId], // Parámetro para evitar SQL Injection
    );
  }

  Future<Map<String, dynamic>> getCondicionesEquipoByOperacionIdCarguio(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_carguio',
    columns: ['condiciones_equipo'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultData = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '', // ✅ nuevo campo
  };

  if (result.isEmpty) {
    return defaultData;
  }

  String condicionesJson = result.first['condiciones_equipo'] as String? ?? '{}';

  try {
    Map<String, dynamic> condiciones = jsonDecode(condicionesJson);

    // 🔥 asegurar que el nuevo campo exista
    condiciones.putIfAbsent('horaLlenado', () => '');

    return condiciones;
  } catch (e) {
    print('Error decodificando condiciones de equipo: $e');
    return defaultData;
  }
}

Future<Map<String, dynamic>> getControlLlantasByOperacionIdCarguio(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_carguio',
    columns: ['control_llantas'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos devolver estructura por defecto
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }

  String controlJson = result.first['control_llantas'] as String? ?? '{}';

  try {
    Map<String, dynamic> control = jsonDecode(controlJson);
    return control;
  } catch (e) {
    print('Error decodificando control de llantas: $e');
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }
}

Future<bool> deleteEstadoCarguio(int operacionId, int estadoId) async {
  final db = await database;

  // 1. Obtener registros
  final result = await db.query(
    'Operacion_carguio',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return false;

  // 2. Parsear JSON
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  if (registros.isEmpty) return false;

  // 3. Convertir todo a Map seguro
  List<Map<String, dynamic>> lista =
      registros.map((e) => Map<String, dynamic>.from(e)).toList();

  // 4. Ordenar por numero (orden real)
  lista.sort((a, b) {
    return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
  });

  // 5. Buscar el estado a eliminar
  Map<String, dynamic>? estadoAEliminar;
  for (var e in lista) {
    if (e['id'] == estadoId) {
      estadoAEliminar = e;
      break;
    }
  }

  if (estadoAEliminar == null) return false;

  int numeroEliminar = estadoAEliminar['numero'] ?? 0;

  // 6. Filtrar (eliminar en cascada desde ese numero)
  List<Map<String, dynamic>> nuevosRegistros = [];
  List<Map<String, dynamic>> eliminados = [];

  for (var e in lista) {
    int numero = e['numero'] ?? 0;

    if (numero < numeroEliminar) {
      nuevosRegistros.add(e);
    } else {
      eliminados.add({
        'id': e['id'],
        'estado': e['estado'],
        'numero': numero,
        'hora_inicio': e['hora_inicio']
      });
    }
  }

  // Debug
  print("🗑️ Eliminados: ${eliminados.length}");
  for (var e in eliminados) {
    print("   - ${e['estado']} #${e['numero']} (${e['hora_inicio']})");
  }

  // 7. Renumerar secuencialmente
  for (int i = 0; i < nuevosRegistros.length; i++) {
    nuevosRegistros[i]['numero'] = i + 1;
  }

  // 8. Reconstruir horas finales (solo encadenar)
  for (int i = 0; i < nuevosRegistros.length; i++) {
    if (i < nuevosRegistros.length - 1) {
      nuevosRegistros[i]['hora_final'] =
          nuevosRegistros[i + 1]['hora_inicio'] ?? '';
    } else {
      nuevosRegistros[i]['hora_final'] = "";
    }
  }

  // 9. Guardar
  int updated = await db.update(
    'Operacion_carguio',
    {
      'registros': jsonEncode(nuevosRegistros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("📊 Final: ${nuevosRegistros.length} registros");

  return updated > 0;
}

Future<bool> updateControlLlantasCarguio(
  int operacionId,
  Map<String, dynamic> controlLlantas,
) async {

  final db = await database;

  int updated = await db.update(
    'Operacion_carguio',
    {
      'control_llantas': jsonEncode(controlLlantas),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCheckListCarguio(int operacionId, List<Map<String, dynamic>> checkList) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_carguio',
    {
      'check_list': jsonEncode(checkList),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCondicionesEquipoCarguio(int operacionId, Map<String, dynamic> condiciones) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_carguio',
    {
      'condiciones_equipo': jsonEncode(condiciones),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateHorometrosCarguio(int operacionId, Map<String, dynamic> horometros) async {
  final db = await database;
  
  int updated = await db.update(
    'Operacion_carguio',
    {
      'horometros': jsonEncode(horometros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

Future<bool> updateCheckListTelemando(
  int operacionId,
  List<Map<String, dynamic>> checkListTelemando,
) async {

  final db = await database;

  int updated = await db.update(
    'Operacion_carguio',
    {
      'check_list_telemando': jsonEncode(checkListTelemando),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<List<Map<String, dynamic>>> getCheckListTelemandoByOperacionIdCarguio(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_carguio',
    columns: ['check_list_telemando'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return [];
  }

  String checkListJson = result.first['check_list_telemando'] as String? ?? '[]';

  try {
    List<dynamic> lista = jsonDecode(checkListJson);

    return lista.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    print('Error decodificando checklist telemando: $e');
    return [];
  }
}

Future<Map<String, dynamic>> getProgramaTrabajoByOperacionIdCarguio(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_carguio',
    columns: ['programa_trabajo'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'n_cucharas_programado': 0,
      'n_cucharas_realizado': 0,
    };
  }

  String programaTrabajoJson = result.first['programa_trabajo'] as String? ?? '{}';

  try {
    Map<String, dynamic> programaTrabajo = jsonDecode(programaTrabajoJson);

    if (programaTrabajo.isEmpty) {
      return {
        'n_cucharas_programado': 0,
        'n_cucharas_realizado': 0,
      };
    }

    return programaTrabajo;
  } catch (e) {
    print('Error decodificando programa_trabajo: $e');

    return {
      'n_cucharas_programado': 0,
      'n_cucharas_realizado': 0,
    };
  }
}

Future<bool> updateProgramaTrabajoCarguio(
  int operacionId,
  Map<String, dynamic> programaTrabajo,
) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_carguio',
    {
      'programa_trabajo': jsonEncode(programaTrabajo),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

//VOLQUETESS INICIO---------------------------------------------------------------------------------------------------------------------------------------------
Future<int> insertOperacionVolquetes(
  String fecha,
  String turno,
  String guardia,  // ← antes era seccion
  String operador,
  String jefeGuardia,
  String nVolquete,  // ← antes era equipo/nEquipo
  String empresa,    // ← nuevo campo
  List<Map<String, dynamic>>? horometrosBase,
) async {

  final db = await database;

  /// 🔥 estructura horometros (adaptada a la tabla)
  Map<String, dynamic> horometrosJson = {
    'horometro': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'kilometraje': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'combustible': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'Ralenty': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'Litraje': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  };

  /// 🔥 aplicar valor de nube
  if (horometrosBase != null && horometrosBase.isNotEmpty) {
    final item = horometrosBase.first;
    final finalValor = (item['final'] ?? 0).toDouble();
    horometrosJson['horometro']['inicio'] = finalValor;
  }

  return await db.insert(
    'Operacion_volquetes',
    {
      'fecha': fecha,
      'turno': turno,
      'guardia': guardia,           // ← mapeado correctamente
      'n_volquete': nVolquete,      // ← mapeado correctamente
      'operador': operador,
      'empresa': empresa,           // ← nuevo campo requerido
      'jefe_guardia': jefeGuardia,
      'horometros': jsonEncode(horometrosJson),
      'estado': 'activo',           // ← valor por defecto
      'envio': 0,                   // ← valor por defecto
    },
  );
}

Future<List<Map<String, dynamic>>> getOperacionVolquetesByTurnoAndFechaMaster(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_volquetes',
    where: 'turno = ? AND fecha = ? AND estado IN (?, ?)',
    whereArgs: [turno, fecha, 'activo', 'parciales'],
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionVolquetesByTurnoAndFecha(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_volquetes',
    where: 'turno = ? AND fecha = ?',
    whereArgs: [turno, fecha],
  );

  return result;
}

// Función para obtener todos los estados de una operación
Future<List<Map<String, dynamic>>> getEstadosByOperacionIdVolquetes(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_volquetes',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return [];
  }
  
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  return registros.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<int> eliminarOperacionTalVolquetesFisico(int id) async {
  final db = await database;

  final result = await db.delete(
    'Operacion_volquetes',
    where: 'id = ?',
    whereArgs: [id],
  );

  return result; // devuelve el número de filas eliminadas
}

Future<bool> updateHoraFinalVolquetes(int operacionId, int estadoId, String horaFinal) async {
  final db = await database;

  final result = await db.query(
    'Operacion_volquetes',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  bool encontrado = false;
  String tipoEstado = "";

  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'].toString() == estadoId.toString()) {
      tipoEstado = registros[i]['estado']; // Guardar el tipo para log
      registros[i]['hora_final'] = horaFinal;
      encontrado = true;
      break;
    }
  }

  if (!encontrado) {
    print("⚠ Estado no encontrado en JSON");
    return false;
  }

  int updated = await db.update(
    'Operacion_volquetes',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("✔ Hora final actualizada para estado $tipoEstado: $horaFinal");
  return updated > 0;
}

Future<Map<String, dynamic>?> createEstadoVolquetes(
  int operacionId,
  String estado,
  String codigo,
  String horaInicio, {
  String? horaFinal,
  Map<String, dynamic>? operacion,
}) async {

  final db = await database;

  // 1. Obtener registros actuales
  final result = await db.query(
    'Operacion_volquetes',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return null;
  }

  // 2. Parsear registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  // 3. Calcular número
  int nuevoNumero = 1;
  if (registros.isNotEmpty) {
    int ultimoNumero = registros.last['numero'] ?? 0;
    nuevoNumero = ultimoNumero + 1;
  }

  // 4. ID único
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  /// NUEVA estructura de operación para CARGUÍO
  Map<String, dynamic> operacionCompleta = {
    'labor_inicio': operacion?['labor_inicio'] ?? '',

    'ubicacion_destino': operacion?['ubicacion_destino'] ?? '',

    'toneladas': operacion?['toneladas'] ?? 0.0,
    'material': operacion?['material'] ?? '', 
    'observaciones': operacion?['observaciones'] ?? '',

    // Nuevos campos
  'scoop': operacion?['scoop'] ?? '',
  'total_viajes': operacion?['total_viajes'] ?? 0,

     // Nuevos campos (pueden ser texto o número)
    'mineral': operacion?['mineral'] ?? 0,
    'desmonte': operacion?['desmonte'] ?? 0,
    'relleno': operacion?['relleno'] ?? 0,
    'numero_volquete': operacion?['numero_volquete'] ?? 0,
    'relave': operacion?['relave'] ?? 0,
  };

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': nuevoNumero,
    'estado': estado,
    'codigo': codigo,
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': operacionCompleta,
  };

  // 5. Agregar al array
  registros.add(nuevoEstado);

  // 6. Guardar
  await db.update(
    'Operacion_volquetes',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<bool> updateEstadoVolquetes(
  int operacionId,
  int estadoId, {
  int? numero,
  String? estado,
  String? codigo,
  String? horaInicio,
  String? horaFinal,
  Map<String, String>? operacion,
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_volquetes',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return false;
  }
  
  // 2. Parsear el JSON de registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Buscar y actualizar el estado específico
  bool encontrado = false;
  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'] == estadoId) {
      // Actualizar solo los campos proporcionados
      if (numero != null) registros[i]['numero'] = numero;
      if (estado != null) registros[i]['estado'] = estado;
      if (codigo != null) registros[i]['codigo'] = codigo;
      if (horaInicio != null) registros[i]['hora_inicio'] = horaInicio;
      if (horaFinal != null) registros[i]['hora_final'] = horaFinal;
      if (operacion != null) {
        registros[i]['operacion'] = {
          ...registros[i]['operacion'] as Map,
          ...operacion,
        };
      }
      encontrado = true;
      break;
    }
  }
  
  if (!encontrado) {
    return false;
  }
  
  // 4. Guardar los cambios
  int updated = await db.update(
    'Operacion_volquetes',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

Future<Map<String, dynamic>> getOperacionByEstadoIdVolquetes(int operacionId, int estadoId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_volquetes',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'labor_inicio': '',
    'ubicacion_destino': '',
    'toneladas': 0.0,
    'material': '',
    'observaciones': '',

    'scoop': '',
    'total_viajes': 0,

    'mineral': 0,
    'desmonte': 0,
    'relleno': 0,
    'numero_volquete': 0,
    'relave': 0,
    };
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';

  try {
    List<dynamic> registros = jsonDecode(registrosJson);

    var estadoEncontrado = registros.firstWhere(
      (estado) => estado['id'] == estadoId,
      orElse: () => null,
    );

    if (estadoEncontrado != null && estadoEncontrado.containsKey('operacion')) {
      return estadoEncontrado['operacion'] as Map<String, dynamic>;
    } else {
      return {
        'labor_inicio': '',
    'ubicacion_destino': '',
    'toneladas': 0.0,
    'material': '',
    'observaciones': '',

    'scoop': '',
    'total_viajes': 0,

    'mineral': 0,
    'desmonte': 0,
    'relleno': 0,
    'numero_volquete': 0,
    'relave': 0,
      };
    }
  } catch (e) {
    print('Error decodificando registros: $e');

    return {
      'labor_inicio': '',
    'ubicacion_destino': '',
    'toneladas': 0.0,
    'material': '',
    'observaciones': '',

    'scoop': '',
    'total_viajes': 0,

    'mineral': 0,
    'desmonte': 0,
    'relleno': 0,
    'numero_volquete': 0,
    'relave': 0,
    };
  }
}

Future<bool> updateOperacionByEstadoIdVolquetes(
  int operacionId,
  int estadoId,
  Map<String, dynamic> operacionData,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_volquetes',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    bool encontrado = false;
    
    // Buscar y actualizar el estado específico
    for (var i = 0; i < registros.length; i++) {
      if (registros[i]['id'] == estadoId) {
        // Mantener todos los datos del estado, solo actualizar el campo 'operacion'
        registros[i]['operacion'] = operacionData;
        encontrado = true;
        break;
      }
    }
    
    if (!encontrado) {
      print('⚠ Estado no encontrado en JSON');
      return false;
    }
    
    // Guardar en la base de datos
    int updated = await db.update(
      'Operacion_volquetes',
      {
        'registros': jsonEncode(registros),
      },
      where: 'id = ?',
      whereArgs: [operacionId],
    );
    
    print('✔ Datos de perforación actualizados para estado $estadoId');
    return updated > 0;
  } catch (e) {
    print('Error actualizando datos de perforación: $e');
    return false;
  }
}


Future<Map<String, dynamic>> getHorometrosByOperacionIdVolquetes(
  int operacionId,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_volquetes',
    columns: ['horometros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultHorometros = {
    'horometro': {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false,
    },
    'kilometraje': {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false,
    },
    'combustible': {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false,
    },
    'Ralenty': {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false,
    },
    'Litraje': {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false,
    },
  };

  if (result.isEmpty) {
    return defaultHorometros;
  }

  String horometrosJson = result.first['horometros'] as String? ?? '{}';

  try {
    Map<String, dynamic> horometros =
        Map<String, dynamic>.from(jsonDecode(horometrosJson));

    if (horometros.isEmpty) {
      return defaultHorometros;
    }

    // Compatibilidad con registros antiguos
    horometros.putIfAbsent('horometro', () => {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false,
    });

    horometros.putIfAbsent('kilometraje', () => {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false,
    });

    horometros.putIfAbsent('combustible', () => {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false,
    });

    horometros.putIfAbsent('Ralenty', () => {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false,
    });

    horometros.putIfAbsent('Litraje', () => {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false,
    });

    return horometros;
  } catch (e) {
    print('Error decodificando horómetros: $e');
    return defaultHorometros;
  }
}

Future<Map<String, dynamic>?> getUltimoEstadoByOperacionIdVolquetes(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_volquetes',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
   try {
    List<dynamic> registros = jsonDecode(registrosJson);

    if (registros.isEmpty) return null;

    // ✅ SIMPLE: el último insertado es el último real
    return Map<String, dynamic>.from(registros.last);

  } catch (e) {
    print('Error obteniendo último estado: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> createReservaEstadoVolquetes(
  int operacionId,
  int numero,
  String horaInicio,
  String horaFinal,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_volquetes',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': numero,
    'estado': 'DEMORA',
    'codigo': '303',
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': {
      'labor_inicio': '',
    'ubicacion_destino': '',
    'toneladas': 0.0,
    'material': '',
    'observaciones': '',
    'scoop': '',
    'total_viajes': 0,
    'mineral': 0,
    'desmonte': 0,
    'relleno': 0,
    'numero_volquete': 0,
    'relave': 0,
    },
  };

  registros.add(nuevoEstado);

  await db.update(
    'Operacion_volquetes',
    {'registros': jsonEncode(registros)},
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<void> cerrarOperacionVolquetes(int operacionId) async {
    final Database db = await DatabaseHelper().database;

    await db.update(
      'Operacion_volquetes',
      {'estado': 'cerrado'}, // Nuevo estado
      where: 'id = ?',
      whereArgs: [operacionId], // Parámetro para evitar SQL Injection
    );
  }

  

Future<bool> deleteEstadoVolquetes(int operacionId, int estadoId) async {
  final db = await database;

  // 1. Obtener registros
  final result = await db.query(
    'Operacion_volquetes',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return false;

  // 2. Parsear JSON
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  if (registros.isEmpty) return false;

  // 3. Convertir todo a Map seguro
  List<Map<String, dynamic>> lista =
      registros.map((e) => Map<String, dynamic>.from(e)).toList();

  // 4. Ordenar por numero (orden real)
  lista.sort((a, b) {
    return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
  });

  // 5. Buscar el estado a eliminar
  Map<String, dynamic>? estadoAEliminar;
  for (var e in lista) {
    if (e['id'] == estadoId) {
      estadoAEliminar = e;
      break;
    }
  }

  if (estadoAEliminar == null) return false;

  int numeroEliminar = estadoAEliminar['numero'] ?? 0;

  // 6. Filtrar (eliminar en cascada desde ese numero)
  List<Map<String, dynamic>> nuevosRegistros = [];
  List<Map<String, dynamic>> eliminados = [];

  for (var e in lista) {
    int numero = e['numero'] ?? 0;

    if (numero < numeroEliminar) {
      nuevosRegistros.add(e);
    } else {
      eliminados.add({
        'id': e['id'],
        'estado': e['estado'],
        'numero': numero,
        'hora_inicio': e['hora_inicio']
      });
    }
  }

  // Debug
  print("🗑️ Eliminados: ${eliminados.length}");
  for (var e in eliminados) {
    print("   - ${e['estado']} #${e['numero']} (${e['hora_inicio']})");
  }

  // 7. Renumerar secuencialmente
  for (int i = 0; i < nuevosRegistros.length; i++) {
    nuevosRegistros[i]['numero'] = i + 1;
  }

  // 8. Reconstruir horas finales (solo encadenar)
  for (int i = 0; i < nuevosRegistros.length; i++) {
    if (i < nuevosRegistros.length - 1) {
      nuevosRegistros[i]['hora_final'] =
          nuevosRegistros[i + 1]['hora_inicio'] ?? '';
    } else {
      nuevosRegistros[i]['hora_final'] = "";
    }
  }

  // 9. Guardar
  int updated = await db.update(
    'Operacion_volquetes',
    {
      'registros': jsonEncode(nuevosRegistros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("📊 Final: ${nuevosRegistros.length} registros");

  return updated > 0;
}



Future<bool> updateHorometrosVolquetes(int operacionId, Map<String, dynamic> horometros) async {
  final db = await database;
  
  int updated = await db.update(
    'Operacion_volquetes',
    {
      'horometros': jsonEncode(horometros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

//CARGUIO DUMPER INICIO---------------------------------------------------------------------------------------------------------------------------------------------
Future<int> insertOperacionDumper(
  String fecha,
  String turno,
  String seccion,
  String operador,
  String jefeGuardia,
  String equipo,
  String nEquipo,
  String capacidad,
  String tipoEquipo, {
  List<Map<String, dynamic>>? checkListJson,
  List<Map<String, dynamic>>? checkListTelemandoJson,
  List<Map<String, dynamic>>? horometrosBase, // 🔥 NUEVO
}) async {

  final db = await database;

  /// 🔥 estructura base
  Map<String, dynamic> horometrosJson = {
    'horometro': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  };

  /// 🔥 aplicar valor de nube
  if (horometrosBase != null && horometrosBase.isNotEmpty) {

    final item = horometrosBase.first; // 👈 único
    final finalValor = (item['final'] ?? 0).toDouble();

    horometrosJson['horometro']['inicio'] = finalValor;
  }

  /// Condiciones equipo
  Map<String, dynamic> condicionesEquipoJson = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '',
  };

  /// Control llantas
  Map<String, dynamic> controlLlantasJson = {
    'numero1': false,
    'numero2': false,
    'numero3': false,
    'numero4': false,
  };

  /// Programa de trabajo
  Map<String, dynamic> programaTrabajoJson = {
  'n_viaje_mineral': 0.0,
  'n_viaje_desmonte': 0.0,
  'programado': 0.0,
  'realizado': 0.0,
  'total': 0.0,
};

  /// Checklist
  String checkListStr = jsonEncode(checkListJson ?? []);

  /// Checklist telemando
  String checkListTelemandoStr = jsonEncode(checkListTelemandoJson ?? []);

  return await db.insert(
    'Operacion_Dumper',
    {
      'fecha': fecha,
      'turno': turno,
      'seccion': seccion,
      'operador': operador,
      'jefe_guardia': jefeGuardia,
      'equipo': equipo,
      'n_equipo': nEquipo,
      'capacidad': capacidad,
      'tipo_equipo': tipoEquipo,
      'horometros': jsonEncode(horometrosJson),
      'condiciones_equipo': jsonEncode(condicionesEquipoJson),
      'programa_trabajo': jsonEncode(programaTrabajoJson),
      'check_list': checkListStr,
      'check_list_telemando': checkListTelemandoStr,
      'control_llantas': jsonEncode(controlLlantasJson),
    },
  );
}

Future<List<Map<String, dynamic>>> getOperacionDumperByTurnoAndFechaMaster(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_Dumper',
    where: 'turno = ? AND fecha = ? AND estado IN (?, ?)',
    whereArgs: [turno, fecha, 'activo', 'parciales'],
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionDumperByTurnoAndFecha(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_Dumper',
    where: 'turno = ? AND fecha = ?',
    whereArgs: [turno, fecha],
  );

  return result;
}

// Función para obtener todos los estados de una operación
Future<List<Map<String, dynamic>>> getEstadosByOperacionIdDumper(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_Dumper',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return [];
  }
  
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  return registros.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<int> eliminarOperacionTalDumperFisico(int id) async {
  final db = await database;

  final result = await db.delete(
    'Operacion_Dumper',
    where: 'id = ?',
    whereArgs: [id],
  );

  return result; // devuelve el número de filas eliminadas
}

Future<bool> updateHoraFinalDumper(int operacionId, int estadoId, String horaFinal) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Dumper',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  bool encontrado = false;
  String tipoEstado = "";

  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'].toString() == estadoId.toString()) {
      tipoEstado = registros[i]['estado']; // Guardar el tipo para log
      registros[i]['hora_final'] = horaFinal;
      encontrado = true;
      break;
    }
  }

  if (!encontrado) {
    print("⚠ Estado no encontrado en JSON");
    return false;
  }

  int updated = await db.update(
    'Operacion_Dumper',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("✔ Hora final actualizada para estado $tipoEstado: $horaFinal");
  return updated > 0;
}

Future<Map<String, dynamic>?> createEstadoDumper(
  int operacionId,
  String estado,
  String codigo,
  String horaInicio, {
  String? horaFinal,
  Map<String, dynamic>? operacion,
}) async {

  final db = await database;

  // 1. Obtener registros actuales
  final result = await db.query(
    'Operacion_Dumper',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return null;
  }

  // 2. Parsear registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  // 3. Calcular número
  int nuevoNumero = 1;
  if (registros.isNotEmpty) {
    int ultimoNumero = registros.last['numero'] ?? 0;
    nuevoNumero = ultimoNumero + 1;
  }

  // 4. ID único
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  /// NUEVA estructura de operación para CARGUÍO
  Map<String, dynamic> operacionCompleta = {
    // INICIO
    'nivel_inicio': operacion?['nivel_inicio'] ?? '',
    'tipo_labor_inicio': operacion?['tipo_labor_inicio'] ?? '',
    'labor_inicio': operacion?['labor_inicio'] ?? '',
    'ala_inicio': operacion?['ala_inicio'] ?? '',

    // FIN
    'nivel_fin': operacion?['nivel_fin'] ?? '',
    'tipo_labor_fin': operacion?['tipo_labor_fin'] ?? '',
    'labor_fin': operacion?['labor_fin'] ?? '',
    'ala_fin': operacion?['ala_fin'] ?? '',

    // NUEVO CAMPO
    'n_viajes': operacion?['n_viajes'] ?? 0,

    // OBSERVACIONES
    'observaciones': operacion?['observaciones'] ?? '',
  };

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': nuevoNumero,
    'estado': estado,
    'codigo': codigo,
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': operacionCompleta,
  };

  // 5. Agregar al array
  registros.add(nuevoEstado);

  // 6. Guardar
  await db.update(
    'Operacion_Dumper',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<bool> updateEstadoDumper(
  int operacionId,
  int estadoId, {
  int? numero,
  String? estado,
  String? codigo,
  String? horaInicio,
  String? horaFinal,
  Map<String, String>? operacion,
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_Dumper',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return false;
  }
  
  // 2. Parsear el JSON de registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Buscar y actualizar el estado específico
  bool encontrado = false;
  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'] == estadoId) {
      // Actualizar solo los campos proporcionados
      if (numero != null) registros[i]['numero'] = numero;
      if (estado != null) registros[i]['estado'] = estado;
      if (codigo != null) registros[i]['codigo'] = codigo;
      if (horaInicio != null) registros[i]['hora_inicio'] = horaInicio;
      if (horaFinal != null) registros[i]['hora_final'] = horaFinal;
      if (operacion != null) {
        registros[i]['operacion'] = {
          ...registros[i]['operacion'] as Map,
          ...operacion,
        };
      }
      encontrado = true;
      break;
    }
  }
  
  if (!encontrado) {
    return false;
  }
  
  // 4. Guardar los cambios
  int updated = await db.update(
    'Operacion_Dumper',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

Future<Map<String, dynamic>> getOperacionByEstadoIdDumper(int operacionId, int estadoId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Dumper',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      // INICIO
      'nivel_inicio': '',
      'tipo_labor_inicio': '',
      'labor_inicio': '',
      'ala_inicio': '',

      // FIN
      'nivel_fin': '',
      'tipo_labor_fin': '',
      'labor_fin': '',
      'ala_fin': '',

      // NUEVO
      'n_viajes': 0,

      'observaciones': '',
    };
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';

  try {
    List<dynamic> registros = jsonDecode(registrosJson);

    var estadoEncontrado = registros.firstWhere(
      (estado) => estado['id'] == estadoId,
      orElse: () => null,
    );

    if (estadoEncontrado != null && estadoEncontrado.containsKey('operacion')) {
      return estadoEncontrado['operacion'] as Map<String, dynamic>;
    } else {
      return {
       // INICIO
      'nivel_inicio': '',
      'tipo_labor_inicio': '',
      'labor_inicio': '',
      'ala_inicio': '',

      // FIN
      'nivel_fin': '',
      'tipo_labor_fin': '',
      'labor_fin': '',
      'ala_fin': '',

      // NUEVO
      'n_viajes': 0,

      'observaciones': '',
      };
    }
  } catch (e) {
    print('Error decodificando registros: $e');

    return {
      // INICIO
      'nivel_inicio': '',
      'tipo_labor_inicio': '',
      'labor_inicio': '',
      'ala_inicio': '',

      // FIN
      'nivel_fin': '',
      'tipo_labor_fin': '',
      'labor_fin': '',
      'ala_fin': '',

      // NUEVO
      'n_viajes': 0,

      'observaciones': '',
    };
  }
}

Future<bool> updateOperacionByEstadoIdDumper(
  int operacionId,
  int estadoId,
  Map<String, dynamic> operacionData,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Dumper',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    bool encontrado = false;
    
    // Buscar y actualizar el estado específico
    for (var i = 0; i < registros.length; i++) {
      if (registros[i]['id'] == estadoId) {
        // Mantener todos los datos del estado, solo actualizar el campo 'operacion'
        registros[i]['operacion'] = operacionData;
        encontrado = true;
        break;
      }
    }
    
    if (!encontrado) {
      print('⚠ Estado no encontrado en JSON');
      return false;
    }
    
    // Guardar en la base de datos
    int updated = await db.update(
      'Operacion_Dumper',
      {
        'registros': jsonEncode(registros),
      },
      where: 'id = ?',
      whereArgs: [operacionId],
    );
    
    print('✔ Datos de perforación actualizados para estado $estadoId');
    return updated > 0;
  } catch (e) {
    print('Error actualizando datos de perforación: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> getCheckListByOperacionIdDumper(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Dumper',
    columns: ['check_list'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos, devolver lista vacía
    return [];
  }

  String checkListJson = result.first['check_list'] as String? ?? '[]';

  try {
    List<dynamic> lista = jsonDecode(checkListJson);
    // Asegurarse de que cada item sea Map<String, dynamic>
    return lista.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    print('Error decodificando checklist: $e');
    return [];
  }
}

Future<Map<String, dynamic>> getHorometrosByOperacionIdDumper(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Dumper',
    columns: ['horometros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'horometro': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      }
    };
  }

  String horometrosJson = result.first['horometros'] as String? ?? '{}';

  try {
    Map<String, dynamic> horometros = jsonDecode(horometrosJson);

    // Si el JSON está vacío
    if (horometros.isEmpty) {
      return {
        'horometro': {
          'inicio': 0,
          'final': 0,
          'op': true,
          'inop': false
        }
      };
    }

    return horometros;
  } catch (e) {
    print('Error decodificando horómetros: $e');

    return {
      'horometro': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      }
    };
  }
}

Future<Map<String, dynamic>?> getUltimoEstadoByOperacionIdDumper(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Dumper',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
   try {
    List<dynamic> registros = jsonDecode(registrosJson);

    if (registros.isEmpty) return null;

    // ✅ SIMPLE: el último insertado es el último real
    return Map<String, dynamic>.from(registros.last);

  } catch (e) {
    print('Error obteniendo último estado: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> createReservaEstadoDumper(
  int operacionId,
  int numero,
  String horaInicio,
  String horaFinal,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Dumper',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': numero,
    'estado': 'RESERVA',
    'codigo': '401',
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': {
       // INICIO
      'nivel_inicio': '',
      'tipo_labor_inicio': '',
      'labor_inicio': '',
      'ala_inicio': '',

      // FIN
      'nivel_fin': '',
      'tipo_labor_fin': '',
      'labor_fin': '',
      'ala_fin': '',

      // NUEVO
      'n_viajes': 0,

      'observaciones': '',
    },
  };

  registros.add(nuevoEstado);

  await db.update(
    'Operacion_Dumper',
    {'registros': jsonEncode(registros)},
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<void> cerrarOperacionDumper(int operacionId) async {
    final Database db = await DatabaseHelper().database;

    await db.update(
      'Operacion_Dumper',
      {'estado': 'cerrado'}, // Nuevo estado
      where: 'id = ?',
      whereArgs: [operacionId], // Parámetro para evitar SQL Injection
    );
  }

  Future<Map<String, dynamic>> getCondicionesEquipoByOperacionIdDumper(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Dumper',
    columns: ['condiciones_equipo'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultData = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '', // ✅ nuevo campo
  };

  if (result.isEmpty) {
    return defaultData;
  }

  String condicionesJson = result.first['condiciones_equipo'] as String? ?? '{}';

  try {
    Map<String, dynamic> condiciones = jsonDecode(condicionesJson);

    // 🔥 asegurar que el nuevo campo exista
    condiciones.putIfAbsent('horaLlenado', () => '');

    return condiciones;
  } catch (e) {
    print('Error decodificando condiciones de equipo: $e');
    return defaultData;
  }
}

Future<Map<String, dynamic>> getControlLlantasByOperacionIdDumper(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Dumper',
    columns: ['control_llantas'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos devolver estructura por defecto
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }

  String controlJson = result.first['control_llantas'] as String? ?? '{}';

  try {
    Map<String, dynamic> control = jsonDecode(controlJson);
    return control;
  } catch (e) {
    print('Error decodificando control de llantas: $e');
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }
}

Future<bool> deleteEstadoDumper(int operacionId, int estadoId) async {
  final db = await database;

  // 1. Obtener registros
  final result = await db.query(
    'Operacion_Dumper',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return false;

  // 2. Parsear JSON
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  if (registros.isEmpty) return false;

  // 3. Convertir todo a Map seguro
  List<Map<String, dynamic>> lista =
      registros.map((e) => Map<String, dynamic>.from(e)).toList();

  // 4. Ordenar por numero (orden real)
  lista.sort((a, b) {
    return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
  });

  // 5. Buscar el estado a eliminar
  Map<String, dynamic>? estadoAEliminar;
  for (var e in lista) {
    if (e['id'] == estadoId) {
      estadoAEliminar = e;
      break;
    }
  }

  if (estadoAEliminar == null) return false;

  int numeroEliminar = estadoAEliminar['numero'] ?? 0;

  // 6. Filtrar (eliminar en cascada desde ese numero)
  List<Map<String, dynamic>> nuevosRegistros = [];
  List<Map<String, dynamic>> eliminados = [];

  for (var e in lista) {
    int numero = e['numero'] ?? 0;

    if (numero < numeroEliminar) {
      nuevosRegistros.add(e);
    } else {
      eliminados.add({
        'id': e['id'],
        'estado': e['estado'],
        'numero': numero,
        'hora_inicio': e['hora_inicio']
      });
    }
  }

  // Debug
  print("🗑️ Eliminados: ${eliminados.length}");
  for (var e in eliminados) {
    print("   - ${e['estado']} #${e['numero']} (${e['hora_inicio']})");
  }

  // 7. Renumerar secuencialmente
  for (int i = 0; i < nuevosRegistros.length; i++) {
    nuevosRegistros[i]['numero'] = i + 1;
  }

  // 8. Reconstruir horas finales (solo encadenar)
  for (int i = 0; i < nuevosRegistros.length; i++) {
    if (i < nuevosRegistros.length - 1) {
      nuevosRegistros[i]['hora_final'] =
          nuevosRegistros[i + 1]['hora_inicio'] ?? '';
    } else {
      nuevosRegistros[i]['hora_final'] = "";
    }
  }

  // 9. Guardar
  int updated = await db.update(
    'Operacion_Dumper',
    {
      'registros': jsonEncode(nuevosRegistros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("📊 Final: ${nuevosRegistros.length} registros");

  return updated > 0;
}


Future<bool> updateControlLlantasDumper(
  int operacionId,
  Map<String, dynamic> controlLlantas,
) async {

  final db = await database;

  int updated = await db.update(
    'Operacion_Dumper',
    {
      'control_llantas': jsonEncode(controlLlantas),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCheckListDumper(int operacionId, List<Map<String, dynamic>> checkList) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_Dumper',
    {
      'check_list': jsonEncode(checkList),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCondicionesEquipoDumper(int operacionId, Map<String, dynamic> condiciones) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_Dumper',
    {
      'condiciones_equipo': jsonEncode(condiciones),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateHorometrosDumper(int operacionId, Map<String, dynamic> horometros) async {
  final db = await database;
  
  int updated = await db.update(
    'Operacion_Dumper',
    {
      'horometros': jsonEncode(horometros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

Future<bool> updateCheckListTelemandoDumper(
  int operacionId,
  List<Map<String, dynamic>> checkListTelemando,
) async {

  final db = await database;

  int updated = await db.update(
    'Operacion_Dumper',
    {
      'check_list_telemando': jsonEncode(checkListTelemando),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<List<Map<String, dynamic>>> getCheckListTelemandoByOperacionIdDumper(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Dumper',
    columns: ['check_list_telemando'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return [];
  }

  String checkListJson = result.first['check_list_telemando'] as String? ?? '[]';

  try {
    List<dynamic> lista = jsonDecode(checkListJson);

    return lista.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    print('Error decodificando checklist telemando: $e');
    return [];
  }
}

Future<Map<String, dynamic>> getProgramaTrabajoByOperacionIdDumper(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Dumper',
    columns: ['programa_trabajo'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  // 🔥 estructura nueva base
  Map<String, dynamic> estructuraNueva() {
    return {
      'n_viaje_mineral': 0.0,
      'n_viaje_desmonte': 0.0,
      'programado': 0.0,
      'realizado': 0.0,
      'total': 0.0,
    };
  }

  if (result.isEmpty) {
    return estructuraNueva();
  }

  String programaTrabajoJson = result.first['programa_trabajo'] as String? ?? '{}';

  try {
    Map<String, dynamic> programaTrabajo = jsonDecode(programaTrabajoJson);

    if (programaTrabajo.isEmpty) {
      return estructuraNueva();
    }

    // ✅ SIEMPRE formato nuevo
    return {
      'n_viaje_mineral': (programaTrabajo['n_viaje_mineral'] ?? 0).toDouble(),
      'n_viaje_desmonte': (programaTrabajo['n_viaje_desmonte'] ?? 0).toDouble(),
      'programado': (programaTrabajo['programado'] ?? 0).toDouble(),
      'realizado': (programaTrabajo['realizado'] ?? 0).toDouble(),
      'total': (programaTrabajo['total'] ?? 0).toDouble(),
    };

  } catch (e) {
    print('Error decodificando programa_trabajo: $e');
    return estructuraNueva();
  }
}

Future<bool> updateProgramaTrabajoDumper(
  int operacionId,
  Map<String, dynamic> programaTrabajo,
) async {
  final db = await database;

  // 🔥 Normalizar estructura
  Map<String, dynamic> data = {
    'n_viaje_mineral': (programaTrabajo['n_viaje_mineral'] ?? 0).toDouble(),
    'n_viaje_desmonte': (programaTrabajo['n_viaje_desmonte'] ?? 0).toDouble(),
    'programado': (programaTrabajo['programado'] ?? 0).toDouble(),
    'realizado': (programaTrabajo['realizado'] ?? 0).toDouble(),
    'total': (programaTrabajo['total'] ?? 0).toDouble(),
  };

  int updated = await db.update(
    'Operacion_Dumper',
    {
      'programa_trabajo': jsonEncode(data),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

//ROMPE BANCOS INICIO---------------------------------------------------------------------------------------------------------------------------------------------

Future<int> insertOperacionRompeBaco(
  String fecha,
  String turno,
  String operador,
  String jefeGuardia,
  String equipo,
  String nEquipo, {
  List<Map<String, dynamic>>? checkListJson,
  List<Map<String, dynamic>>? horometrosBase, // 🔥 NUEVO
}) async {

  final db = await database;

  /// 🔥 estructura base
  Map<String, dynamic> horometrosJson = {
    'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'percusion': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  };

  /// 🔥 aplicar valores de nube
  if (horometrosBase != null && horometrosBase.isNotEmpty) {
    for (var item in horometrosBase) {

      final tipo = item['tipo_horometro'];
      final finalValor = (item['final'] ?? 0).toDouble();

      if (horometrosJson.containsKey(tipo)) {
        horometrosJson[tipo]['inicio'] = finalValor;
      }
    }
  }

  /// Condiciones equipo
  Map<String, dynamic> condicionesEquipoJson = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '',
  };

  /// Control llantas
  Map<String, dynamic> controlLlantasJson = {
    'numero1': false,
    'numero2': false,
    'numero3': false,
    'numero4': false,
  };

  /// Checklist
  String checkListStr = jsonEncode(checkListJson ?? []);

  return await db.insert(
    'Operacion_rompebanco',
    {
      'fecha': fecha,
      'turno': turno,
      'operador': operador,
      'jefe_guardia': jefeGuardia,
      'equipo': equipo,
      'n_equipo': nEquipo,
      'horometros': jsonEncode(horometrosJson),
      'condiciones_equipo': jsonEncode(condicionesEquipoJson),
      'check_list': checkListStr,
      'control_llantas': jsonEncode(controlLlantasJson),
      'estado': 'activo',
      'envio': 0
    },
  );
}

Future<List<Map<String, dynamic>>> getOperacionRompeBacoByTurnoAndFechaMaster(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_rompebanco',
    where: 'turno = ? AND fecha = ? AND estado IN (?, ?)',
    whereArgs: [turno, fecha, 'activo', 'parciales'],
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionRompeBacoByTurnoAndFecha(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_rompebanco',
    where: 'turno = ? AND fecha = ?',
    whereArgs: [turno, fecha],
  );

  return result;
}

// Función para obtener todos los estados de una operación
Future<List<Map<String, dynamic>>> getEstadosByOperacionIdRompeBaco(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return [];
  }
  
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  return registros.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<int> eliminarOperacionTalRompeBacoFisico(int id) async {
  final db = await database;

  final result = await db.delete(
    'Operacion_rompebanco',
    where: 'id = ?',
    whereArgs: [id],
  );

  return result; // devuelve el número de filas eliminadas
}

Future<bool> updateHoraFinalRompeBaco(int operacionId, int estadoId, String horaFinal) async {
  final db = await database;

  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  bool encontrado = false;
  String tipoEstado = "";

  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'].toString() == estadoId.toString()) {
      tipoEstado = registros[i]['estado']; // Guardar el tipo para log
      registros[i]['hora_final'] = horaFinal;
      encontrado = true;
      break;
    }
  }

  if (!encontrado) {
    print("⚠ Estado no encontrado en JSON");
    return false;
  }

  int updated = await db.update(
    'Operacion_rompebanco',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("✔ Hora final actualizada para estado $tipoEstado: $horaFinal");
  return updated > 0;
}

Future<Map<String, dynamic>?> createEstadoRompeBaco(
  int operacionId,
  String estado,
  String codigo,
  String horaInicio, {
  String? horaFinal,
  Map<String, dynamic>? operacion,
}) async {

  final db = await database;

  // 1. Obtener registros actuales
  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return null;
  }

  // 2. Parsear registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  // 3. Calcular número
  int nuevoNumero = 1;
  if (registros.isNotEmpty) {
    int ultimoNumero = registros.last['numero'] ?? 0;
    nuevoNumero = ultimoNumero + 1;
  }

  // 4. ID único
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  /// NUEVA estructura de operación
  Map<String, dynamic> operacionSimple = {
    'nivel': operacion?['nivel'] ?? '',
    'tipo_labor': operacion?['tipo_labor'] ?? '',
    'labor': operacion?['labor'] ?? '',
    'ala': operacion?['ala'] ?? '',
    'observaciones': operacion?['observaciones'] ?? '',
  };

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': nuevoNumero,
    'estado': estado,
    'codigo': codigo,
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': operacionSimple,
  };

  // 5. Agregar al array
  registros.add(nuevoEstado);

  // 6. Guardar
  await db.update(
    'Operacion_rompebanco',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<bool> updateEstadoRompeBaco(
  int operacionId,
  int estadoId, {
  int? numero,
  String? estado,
  String? codigo,
  String? horaInicio,
  String? horaFinal,
  Map<String, String>? operacion,
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return false;
  }
  
  // 2. Parsear el JSON de registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Buscar y actualizar el estado específico
  bool encontrado = false;
  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'] == estadoId) {
      // Actualizar solo los campos proporcionados
      if (numero != null) registros[i]['numero'] = numero;
      if (estado != null) registros[i]['estado'] = estado;
      if (codigo != null) registros[i]['codigo'] = codigo;
      if (horaInicio != null) registros[i]['hora_inicio'] = horaInicio;
      if (horaFinal != null) registros[i]['hora_final'] = horaFinal;
      if (operacion != null) {
        registros[i]['operacion'] = {
          ...registros[i]['operacion'] as Map,
          ...operacion,
        };
      }
      encontrado = true;
      break;
    }
  }
  
  if (!encontrado) {
    return false;
  }
  
  // 4. Guardar los cambios
  int updated = await db.update(
    'Operacion_rompebanco',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

Future<Map<String, dynamic>> getOperacionByEstadoIdRompeBaco(
    int operacionId, int estadoId) async {

  final db = await database;

  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      'observaciones': '',
    };
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';

  try {
    List<dynamic> registros = jsonDecode(registrosJson);

    var estadoEncontrado = registros.firstWhere(
      (estado) => estado['id'] == estadoId,
      orElse: () => null,
    );

    if (estadoEncontrado != null &&
        estadoEncontrado.containsKey('operacion')) {

      return Map<String, dynamic>.from(estadoEncontrado['operacion']);
    } else {
      return {
        'nivel': '',
        'tipo_labor': '',
        'labor': '',
        'ala': '',
        'observaciones': '',
      };
    }

  } catch (e) {
    print('Error decodificando registros: $e');

    return {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      'observaciones': '',
    };
  }
}

Future<bool> updateOperacionByEstadoIdRompeBaco(
  int operacionId,
  int estadoId,
  Map<String, dynamic> operacionData,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    bool encontrado = false;
    
    // Buscar y actualizar el estado específico
    for (var i = 0; i < registros.length; i++) {
      if (registros[i]['id'] == estadoId) {
        // Mantener todos los datos del estado, solo actualizar el campo 'operacion'
        registros[i]['operacion'] = operacionData;
        encontrado = true;
        break;
      }
    }
    
    if (!encontrado) {
      print('⚠ Estado no encontrado en JSON');
      return false;
    }
    
    // Guardar en la base de datos
    int updated = await db.update(
      'Operacion_rompebanco',
      {
        'registros': jsonEncode(registros),
      },
      where: 'id = ?',
      whereArgs: [operacionId],
    );
    
    print('✔ Datos de perforación actualizados para estado $estadoId');
    return updated > 0;
  } catch (e) {
    print('Error actualizando datos de perforación: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> getCheckListByOperacionIdRompeBaco(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['check_list'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos, devolver lista vacía
    return [];
  }

  String checkListJson = result.first['check_list'] as String? ?? '[]';

  try {
    List<dynamic> lista = jsonDecode(checkListJson);
    // Asegurarse de que cada item sea Map<String, dynamic>
    return lista.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    print('Error decodificando checklist: $e');
    return [];
  }
}

Future<Map<String, dynamic>> getHorometrosByOperacionIdRompeBaco(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['horometros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'diesel': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      },
      'percusion': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      }
    };
  }

  String horometrosJson = result.first['horometros'] as String? ?? '{}';

  try {
    Map<String, dynamic> horometros = jsonDecode(horometrosJson);

    if (horometros.isEmpty) {
      return {
        'diesel': {
          'inicio': 0,
          'final': 0,
          'op': true,
          'inop': false
        },
        'percusion': {
          'inicio': 0,
          'final': 0,
          'op': true,
          'inop': false
        }
      };
    }

    return Map<String, dynamic>.from(horometros);

  } catch (e) {
    print('Error decodificando horómetros: $e');

    return {
      'diesel': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      },
      'percusion': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      }
    };
  }
}

Future<Map<String, dynamic>?> getUltimoEstadoByOperacionIdRompeBaco(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
   try {
    List<dynamic> registros = jsonDecode(registrosJson);

    if (registros.isEmpty) return null;

    // ✅ SIMPLE: el último insertado es el último real
    return Map<String, dynamic>.from(registros.last);

  } catch (e) {
    print('Error obteniendo último estado: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> createReservaEstadoRompeBaco(
  int operacionId,
  int numero,
  String horaInicio,
  String horaFinal,
) async {

  final db = await database;

  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';

  List<dynamic> registros = [];
  try {
    registros = jsonDecode(registrosJson);
  } catch (e) {
    registros = [];
  }

  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': numero,
    'estado': 'RESERVA',
    'codigo': '401',
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      'observaciones': '',
    },
  };

  registros.add(nuevoEstado);

  await db.update(
    'Operacion_rompebanco',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<void> cerrarOperacionRompeBaco(int operacionId) async {
    final Database db = await DatabaseHelper().database;

    await db.update(
      'Operacion_rompebanco',
      {'estado': 'cerrado'}, // Nuevo estado
      where: 'id = ?',
      whereArgs: [operacionId], // Parámetro para evitar SQL Injection
    );
  }

  Future<Map<String, dynamic>> getCondicionesEquipoByOperacionIdRompeBaco(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['condiciones_equipo'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultData = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '', // ✅ nuevo campo
  };

  if (result.isEmpty) {
    return defaultData;
  }

  String condicionesJson = result.first['condiciones_equipo'] as String? ?? '{}';

  try {
    Map<String, dynamic> condiciones = jsonDecode(condicionesJson);

    // 🔥 asegurar que el nuevo campo exista
    condiciones.putIfAbsent('horaLlenado', () => '');

    return condiciones;
  } catch (e) {
    print('Error decodificando condiciones de equipo: $e');
    return defaultData;
  }
}

Future<Map<String, dynamic>> getControlLlantasByOperacionIdRompeBaco(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['control_llantas'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos devolver estructura por defecto
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }

  String controlJson = result.first['control_llantas'] as String? ?? '{}';

  try {
    Map<String, dynamic> control = jsonDecode(controlJson);
    return control;
  } catch (e) {
    print('Error decodificando control de llantas: $e');
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }
}

Future<bool> deleteEstadoRompeBaco(int operacionId, int estadoId) async {
  final db = await database;

  // 1. Obtener registros
  final result = await db.query(
    'Operacion_rompebanco',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return false;

  // 2. Parsear JSON
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  if (registros.isEmpty) return false;

  // 3. Convertir todo a Map seguro
  List<Map<String, dynamic>> lista =
      registros.map((e) => Map<String, dynamic>.from(e)).toList();

  // 4. Ordenar por numero (orden real)
  lista.sort((a, b) {
    return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
  });

  // 5. Buscar el estado a eliminar
  Map<String, dynamic>? estadoAEliminar;
  for (var e in lista) {
    if (e['id'] == estadoId) {
      estadoAEliminar = e;
      break;
    }
  }

  if (estadoAEliminar == null) return false;

  int numeroEliminar = estadoAEliminar['numero'] ?? 0;

  // 6. Filtrar (eliminar en cascada desde ese numero)
  List<Map<String, dynamic>> nuevosRegistros = [];
  List<Map<String, dynamic>> eliminados = [];

  for (var e in lista) {
    int numero = e['numero'] ?? 0;

    if (numero < numeroEliminar) {
      nuevosRegistros.add(e);
    } else {
      eliminados.add({
        'id': e['id'],
        'estado': e['estado'],
        'numero': numero,
        'hora_inicio': e['hora_inicio']
      });
    }
  }

  // Debug
  print("🗑️ Eliminados: ${eliminados.length}");
  for (var e in eliminados) {
    print("   - ${e['estado']} #${e['numero']} (${e['hora_inicio']})");
  }

  // 7. Renumerar secuencialmente
  for (int i = 0; i < nuevosRegistros.length; i++) {
    nuevosRegistros[i]['numero'] = i + 1;
  }

  // 8. Reconstruir horas finales (solo encadenar)
  for (int i = 0; i < nuevosRegistros.length; i++) {
    if (i < nuevosRegistros.length - 1) {
      nuevosRegistros[i]['hora_final'] =
          nuevosRegistros[i + 1]['hora_inicio'] ?? '';
    } else {
      nuevosRegistros[i]['hora_final'] = "";
    }
  }

  // 9. Guardar
  int updated = await db.update(
    'Operacion_rompebanco',
    {
      'registros': jsonEncode(nuevosRegistros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("📊 Final: ${nuevosRegistros.length} registros");

  return updated > 0;
}

Future<bool> updateControlLlantasRompeBaco(
  int operacionId,
  Map<String, dynamic> controlLlantas,
) async {

  final db = await database;

  int updated = await db.update(
    'Operacion_rompebanco',
    {
      'control_llantas': jsonEncode(controlLlantas),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCheckListRompeBaco(int operacionId, List<Map<String, dynamic>> checkList) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_rompebanco',
    {
      'check_list': jsonEncode(checkList),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCondicionesEquipoRompeBaco(int operacionId, Map<String, dynamic> condiciones) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_rompebanco',
    {
      'condiciones_equipo': jsonEncode(condiciones),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateHorometrosRompeBaco(int operacionId, Map<String, dynamic> horometros) async {
  final db = await database;
  
  int updated = await db.update(
    'Operacion_rompebanco',
    {
      'horometros': jsonEncode(horometros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

//SCALAMIN INICIO---------------------------------------------------------------------------------------------------------------------------------------------

Future<int> insertOperacionScalamin(
  String fecha,
  String turno,
  String operador,
  String jefeGuardia,
  String equipo,
  String nEquipo, {
  List<Map<String, dynamic>>? checkListJson,
  List<Map<String, dynamic>>? horometrosBase, // 🔥 NUEVO
}) async {

  final db = await database;

  /// 🔥 estructura base
  Map<String, dynamic> horometrosJson = {
    'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'percusion': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  };

  /// 🔥 aplicar valores de nube
  if (horometrosBase != null && horometrosBase.isNotEmpty) {
    for (var item in horometrosBase) {

      final tipo = item['tipo_horometro'];
      final finalValor = (item['final'] ?? 0).toDouble();

      if (horometrosJson.containsKey(tipo)) {
        horometrosJson[tipo]['inicio'] = finalValor;
      }
    }
  }

  /// Condiciones equipo
  Map<String, dynamic> condicionesEquipoJson = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '',
  };

  /// Control llantas
  Map<String, dynamic> controlLlantasJson = {
    'numero1': false,
    'numero2': false,
    'numero3': false,
    'numero4': false,
  };

  /// Checklist
  String checkListStr = jsonEncode(checkListJson ?? []);

  return await db.insert(
    'Operacion_Scalamin',
    {
      'fecha': fecha,
      'turno': turno,
      'operador': operador,
      'jefe_guardia': jefeGuardia,
      'equipo': equipo,
      'n_equipo': nEquipo,
      'horometros': jsonEncode(horometrosJson),
      'condiciones_equipo': jsonEncode(condicionesEquipoJson),
      'check_list': checkListStr,
      'control_llantas': jsonEncode(controlLlantasJson),
      'estado': 'activo',
      'envio': 0
    },
  );
}

Future<List<Map<String, dynamic>>> getOperacionScalaminByTurnoAndFechaMaster(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_Scalamin',
    where: 'turno = ? AND fecha = ? AND estado IN (?, ?)',
    whereArgs: [turno, fecha, 'activo', 'parciales'],
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionScalaminByTurnoAndFecha(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_Scalamin',
    where: 'turno = ? AND fecha = ?',
    whereArgs: [turno, fecha],
  );

  return result;
}

// Función para obtener todos los estados de una operación
Future<List<Map<String, dynamic>>> getEstadosByOperacionIdScalamin(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return [];
  }
  
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  return registros.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<int> eliminarOperacionTalScalaminFisico(int id) async {
  final db = await database;

  final result = await db.delete(
    'Operacion_Scalamin',
    where: 'id = ?',
    whereArgs: [id],
  );

  return result; // devuelve el número de filas eliminadas
}

Future<bool> updateHoraFinalScalamin(int operacionId, int estadoId, String horaFinal) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  bool encontrado = false;
  String tipoEstado = "";

  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'].toString() == estadoId.toString()) {
      tipoEstado = registros[i]['estado']; // Guardar el tipo para log
      registros[i]['hora_final'] = horaFinal;
      encontrado = true;
      break;
    }
  }

  if (!encontrado) {
    print("⚠ Estado no encontrado en JSON");
    return false;
  }

  int updated = await db.update(
    'Operacion_Scalamin',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("✔ Hora final actualizada para estado $tipoEstado: $horaFinal");
  return updated > 0;
}

Future<Map<String, dynamic>?> createEstadoScalamin(
  int operacionId,
  String estado,
  String codigo,
  String horaInicio, {
  String? horaFinal,
  Map<String, dynamic>? operacion,
}) async {

  final db = await database;

  // 1. Obtener registros actuales
  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return null;
  }

  // 2. Parsear registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  // 3. Calcular número
  int nuevoNumero = 1;
  if (registros.isNotEmpty) {
    int ultimoNumero = registros.last['numero'] ?? 0;
    nuevoNumero = ultimoNumero + 1;
  }

  // 4. ID único
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  /// NUEVA estructura de operación
  Map<String, dynamic> operacionSimple = {
    'nivel': operacion?['nivel'] ?? '',
    'tipo_labor': operacion?['tipo_labor'] ?? '',
    'labor': operacion?['labor'] ?? '',
    'ala': operacion?['ala'] ?? '',
    'observaciones': operacion?['observaciones'] ?? '',
  };

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': nuevoNumero,
    'estado': estado,
    'codigo': codigo,
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': operacionSimple,
  };

  // 5. Agregar al array
  registros.add(nuevoEstado);

  // 6. Guardar
  await db.update(
    'Operacion_Scalamin',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<bool> updateEstadoScalamin(
  int operacionId,
  int estadoId, {
  int? numero,
  String? estado,
  String? codigo,
  String? horaInicio,
  String? horaFinal,
  Map<String, String>? operacion,
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return false;
  }
  
  // 2. Parsear el JSON de registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Buscar y actualizar el estado específico
  bool encontrado = false;
  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'] == estadoId) {
      // Actualizar solo los campos proporcionados
      if (numero != null) registros[i]['numero'] = numero;
      if (estado != null) registros[i]['estado'] = estado;
      if (codigo != null) registros[i]['codigo'] = codigo;
      if (horaInicio != null) registros[i]['hora_inicio'] = horaInicio;
      if (horaFinal != null) registros[i]['hora_final'] = horaFinal;
      if (operacion != null) {
        registros[i]['operacion'] = {
          ...registros[i]['operacion'] as Map,
          ...operacion,
        };
      }
      encontrado = true;
      break;
    }
  }
  
  if (!encontrado) {
    return false;
  }
  
  // 4. Guardar los cambios
  int updated = await db.update(
    'Operacion_Scalamin',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

Future<Map<String, dynamic>> getOperacionByEstadoIdScalamin(
    int operacionId, int estadoId) async {

  final db = await database;

  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      'observaciones': '',
    };
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';

  try {
    List<dynamic> registros = jsonDecode(registrosJson);

    var estadoEncontrado = registros.firstWhere(
      (estado) => estado['id'] == estadoId,
      orElse: () => null,
    );

    if (estadoEncontrado != null &&
        estadoEncontrado.containsKey('operacion')) {

      return Map<String, dynamic>.from(estadoEncontrado['operacion']);
    } else {
      return {
        'nivel': '',
        'tipo_labor': '',
        'labor': '',
        'ala': '',
        'observaciones': '',
      };
    }

  } catch (e) {
    print('Error decodificando registros: $e');

    return {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      'observaciones': '',
    };
  }
}

Future<bool> updateOperacionByEstadoIdScalamin(
  int operacionId,
  int estadoId,
  Map<String, dynamic> operacionData,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    bool encontrado = false;
    
    // Buscar y actualizar el estado específico
    for (var i = 0; i < registros.length; i++) {
      if (registros[i]['id'] == estadoId) {
        // Mantener todos los datos del estado, solo actualizar el campo 'operacion'
        registros[i]['operacion'] = operacionData;
        encontrado = true;
        break;
      }
    }
    
    if (!encontrado) {
      print('⚠ Estado no encontrado en JSON');
      return false;
    }
    
    // Guardar en la base de datos
    int updated = await db.update(
      'Operacion_Scalamin',
      {
        'registros': jsonEncode(registros),
      },
      where: 'id = ?',
      whereArgs: [operacionId],
    );
    
    print('✔ Datos de perforación actualizados para estado $estadoId');
    return updated > 0;
  } catch (e) {
    print('Error actualizando datos de perforación: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> getCheckListByOperacionIdScalamin(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['check_list'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos, devolver lista vacía
    return [];
  }

  String checkListJson = result.first['check_list'] as String? ?? '[]';

  try {
    List<dynamic> lista = jsonDecode(checkListJson);
    // Asegurarse de que cada item sea Map<String, dynamic>
    return lista.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    print('Error decodificando checklist: $e');
    return [];
  }
}

Future<Map<String, dynamic>> getHorometrosByOperacionIdScalamin(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['horometros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'diesel': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      },
      'percusion': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      }
    };
  }

  String horometrosJson = result.first['horometros'] as String? ?? '{}';

  try {
    Map<String, dynamic> horometros = jsonDecode(horometrosJson);

    if (horometros.isEmpty) {
      return {
        'diesel': {
          'inicio': 0,
          'final': 0,
          'op': true,
          'inop': false
        },
        'percusion': {
          'inicio': 0,
          'final': 0,
          'op': true,
          'inop': false
        }
      };
    }

    return Map<String, dynamic>.from(horometros);

  } catch (e) {
    print('Error decodificando horómetros: $e');

    return {
      'diesel': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      },
      'percusion': {
        'inicio': 0,
        'final': 0,
        'op': true,
        'inop': false
      }
    };
  }
}

Future<Map<String, dynamic>?> getUltimoEstadoByOperacionIdScalamin(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
   try {
    List<dynamic> registros = jsonDecode(registrosJson);

    if (registros.isEmpty) return null;

    // ✅ SIMPLE: el último insertado es el último real
    return Map<String, dynamic>.from(registros.last);

  } catch (e) {
    print('Error obteniendo último estado: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> createReservaEstadoScalamin(
  int operacionId,
  int numero,
  String horaInicio,
  String horaFinal,
) async {

  final db = await database;

  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';

  List<dynamic> registros = [];
  try {
    registros = jsonDecode(registrosJson);
  } catch (e) {
    registros = [];
  }

  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': numero,
    'estado': 'RESERVA',
    'codigo': '401',
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': {
      'nivel': '',
      'tipo_labor': '',
      'labor': '',
      'ala': '',
      'observaciones': '',
    },
  };

  registros.add(nuevoEstado);

  await db.update(
    'Operacion_Scalamin',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<void> cerrarOperacionScalamin(int operacionId) async {
    final Database db = await DatabaseHelper().database;

    await db.update(
      'Operacion_Scalamin',
      {'estado': 'cerrado'}, // Nuevo estado
      where: 'id = ?',
      whereArgs: [operacionId], // Parámetro para evitar SQL Injection
    );
  }

  Future<Map<String, dynamic>> getCondicionesEquipoByOperacionIdScalamin(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['condiciones_equipo'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultData = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '', // ✅ nuevo campo
  };

  if (result.isEmpty) {
    return defaultData;
  }

  String condicionesJson = result.first['condiciones_equipo'] as String? ?? '{}';

  try {
    Map<String, dynamic> condiciones = jsonDecode(condicionesJson);

    // 🔥 asegurar que el nuevo campo exista
    condiciones.putIfAbsent('horaLlenado', () => '');

    return condiciones;
  } catch (e) {
    print('Error decodificando condiciones de equipo: $e');
    return defaultData;
  }
}

Future<Map<String, dynamic>> getControlLlantasByOperacionIdScalamin(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['control_llantas'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos devolver estructura por defecto
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }

  String controlJson = result.first['control_llantas'] as String? ?? '{}';

  try {
    Map<String, dynamic> control = jsonDecode(controlJson);
    return control;
  } catch (e) {
    print('Error decodificando control de llantas: $e');
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }
}

Future<bool> deleteEstadoScalamin(int operacionId, int estadoId) async {
  final db = await database;

  // 1. Obtener registros
  final result = await db.query(
    'Operacion_Scalamin',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return false;

  // 2. Parsear JSON
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  if (registros.isEmpty) return false;

  // 3. Convertir todo a Map seguro
  List<Map<String, dynamic>> lista =
      registros.map((e) => Map<String, dynamic>.from(e)).toList();

  // 4. Ordenar por numero (orden real)
  lista.sort((a, b) {
    return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
  });

  // 5. Buscar el estado a eliminar
  Map<String, dynamic>? estadoAEliminar;
  for (var e in lista) {
    if (e['id'] == estadoId) {
      estadoAEliminar = e;
      break;
    }
  }

  if (estadoAEliminar == null) return false;

  int numeroEliminar = estadoAEliminar['numero'] ?? 0;

  // 6. Filtrar (eliminar en cascada desde ese numero)
  List<Map<String, dynamic>> nuevosRegistros = [];
  List<Map<String, dynamic>> eliminados = [];

  for (var e in lista) {
    int numero = e['numero'] ?? 0;

    if (numero < numeroEliminar) {
      nuevosRegistros.add(e);
    } else {
      eliminados.add({
        'id': e['id'],
        'estado': e['estado'],
        'numero': numero,
        'hora_inicio': e['hora_inicio']
      });
    }
  }

  // Debug
  print("🗑️ Eliminados: ${eliminados.length}");
  for (var e in eliminados) {
    print("   - ${e['estado']} #${e['numero']} (${e['hora_inicio']})");
  }

  // 7. Renumerar secuencialmente
  for (int i = 0; i < nuevosRegistros.length; i++) {
    nuevosRegistros[i]['numero'] = i + 1;
  }

  // 8. Reconstruir horas finales (solo encadenar)
  for (int i = 0; i < nuevosRegistros.length; i++) {
    if (i < nuevosRegistros.length - 1) {
      nuevosRegistros[i]['hora_final'] =
          nuevosRegistros[i + 1]['hora_inicio'] ?? '';
    } else {
      nuevosRegistros[i]['hora_final'] = "";
    }
  }

  // 9. Guardar
  int updated = await db.update(
    'Operacion_Scalamin',
    {
      'registros': jsonEncode(nuevosRegistros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("📊 Final: ${nuevosRegistros.length} registros");

  return updated > 0;
}

Future<bool> updateControlLlantasScalamin(
  int operacionId,
  Map<String, dynamic> controlLlantas,
) async {

  final db = await database;

  int updated = await db.update(
    'Operacion_Scalamin',
    {
      'control_llantas': jsonEncode(controlLlantas),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCheckListScalamin(int operacionId, List<Map<String, dynamic>> checkList) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_Scalamin',
    {
      'check_list': jsonEncode(checkList),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCondicionesEquipoScalamin(int operacionId, Map<String, dynamic> condiciones) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_Scalamin',
    {
      'condiciones_equipo': jsonEncode(condiciones),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateHorometrosScalamin(int operacionId, Map<String, dynamic> horometros) async {
  final db = await database;
  
  int updated = await db.update(
    'Operacion_Scalamin',
    {
      'horometros': jsonEncode(horometros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}


// SCISSOR INICIO----------------------------------------------------------------------------------------------------------------------------------------------------------
Future<int> insertOperacionScissor(
  String fecha,
  String turno,
  String operador,
  String jefeGuardia,
  String equipo,
  String nEquipo, {
  List<Map<String, dynamic>>? checkListJson,
  List<Map<String, dynamic>>? horometrosBase, // 🔥 NUEVO
}) async {

  final db = await database;

  /// 🔥 estructura base (IMPORTANTE: nombres exactos)
  Map<String, dynamic> horometrosJson = {
    'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  };

  /// 🔥 aplicar valores de nube
  if (horometrosBase != null && horometrosBase.isNotEmpty) {
    for (var item in horometrosBase) {

      final tipo = item['tipo_horometro'];
      final finalValor = (item['final'] ?? 0).toDouble();

      if (horometrosJson.containsKey(tipo)) {
        horometrosJson[tipo]['inicio'] = finalValor;
      }
    }
  }

  /// Condiciones equipo
  Map<String, dynamic> condicionesEquipoJson = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '',
  };

  /// Control llantas
  Map<String, dynamic> controlLlantasJson = {
    'numero1': false,
    'numero2': false,
    'numero3': false,
    'numero4': false,
  };

  /// Checklist
  String checkListStr = jsonEncode(checkListJson ?? []);

  return await db.insert(
    'Operacion_scissor',
    {
      'fecha': fecha,
      'turno': turno,
      'operador': operador,
      'jefe_guardia': jefeGuardia,
      'equipo': equipo,
      'n_equipo': nEquipo,
      'horometros': jsonEncode(horometrosJson),
      'condiciones_equipo': jsonEncode(condicionesEquipoJson),
      'check_list': checkListStr,
      'control_llantas': jsonEncode(controlLlantasJson),
      'estado': 'activo',
      'envio': 0
    },
  );
}

Future<List<Map<String, dynamic>>> getOperacionScissorByTurnoAndFechaMaster(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_scissor',
    where: 'turno = ? AND fecha = ? AND estado IN (?, ?)',
    whereArgs: [turno, fecha, 'activo', 'parciales'],
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionScissorByTurnoAndFecha(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_scissor',
    where: 'turno = ? AND fecha = ?',
    whereArgs: [turno, fecha],
  );

  return result;
}

// Función para obtener todos los estados de una operación
Future<List<Map<String, dynamic>>> getEstadosByOperacionIdScissor(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_scissor',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return [];
  }
  
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  return registros.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<int> eliminarOperacionTalScissorFisico(int id) async {
  final db = await database;

  final result = await db.delete(
    'Operacion_scissor',
    where: 'id = ?',
    whereArgs: [id],
  );

  return result; // devuelve el número de filas eliminadas
}

Future<bool> updateHoraFinalScissor(int operacionId, int estadoId, String horaFinal) async {
  final db = await database;

  final result = await db.query(
    'Operacion_scissor',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  bool encontrado = false;
  String tipoEstado = "";

  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'].toString() == estadoId.toString()) {
      tipoEstado = registros[i]['estado']; // Guardar el tipo para log
      registros[i]['hora_final'] = horaFinal;
      encontrado = true;
      break;
    }
  }

  if (!encontrado) {
    print("⚠ Estado no encontrado en JSON");
    return false;
  }

  int updated = await db.update(
    'Operacion_scissor',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("✔ Hora final actualizada para estado $tipoEstado: $horaFinal");
  return updated > 0;
}

Future<Map<String, dynamic>?> createEstadoScissor(
  int operacionId,
  String estado,
  String codigo,
  String horaInicio, {
  String? horaFinal,
  Map<String, dynamic>? operacion,
}) async {

  final db = await database;

  // 1. Obtener registros actuales
  final result = await db.query(
    'Operacion_scissor',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return null;
  }

  // 2. Parsear registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  // 3. Calcular número
  int nuevoNumero = 1;
  if (registros.isNotEmpty) {
    int ultimoNumero = registros.last['numero'] ?? 0;
    nuevoNumero = ultimoNumero + 1;
  }

  // 4. ID único
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  /// NUEVA estructura operación (origen / destino)
  Map<String, dynamic> operacionSimple = {
    'origen_nivel': operacion?['origen_nivel'] ?? '',
    'origen_tipo_labor': operacion?['origen_tipo_labor'] ?? '',
    'origen_labor': operacion?['origen_labor'] ?? '',
    'origen_ala': operacion?['origen_ala'] ?? '',

    'destino_nivel': operacion?['destino_nivel'] ?? '',
    'destino_tipo_labor': operacion?['destino_tipo_labor'] ?? '',
    'destino_labor': operacion?['destino_labor'] ?? '',
    'destino_ala': operacion?['destino_ala'] ?? '',

    'observaciones': operacion?['observaciones'] ?? '',
  };

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': nuevoNumero,
    'estado': estado,
    'codigo': codigo,
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': operacionSimple,
  };

  // 5. Agregar al array
  registros.add(nuevoEstado);

  // 6. Guardar
  await db.update(
    'Operacion_scissor',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<bool> updateEstadoScissor(
  int operacionId,
  int estadoId, {
  int? numero,
  String? estado,
  String? codigo,
  String? horaInicio,
  String? horaFinal,
  Map<String, String>? operacion,
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_scissor',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return false;
  }
  
  // 2. Parsear el JSON de registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Buscar y actualizar el estado específico
  bool encontrado = false;
  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'] == estadoId) {
      // Actualizar solo los campos proporcionados
      if (numero != null) registros[i]['numero'] = numero;
      if (estado != null) registros[i]['estado'] = estado;
      if (codigo != null) registros[i]['codigo'] = codigo;
      if (horaInicio != null) registros[i]['hora_inicio'] = horaInicio;
      if (horaFinal != null) registros[i]['hora_final'] = horaFinal;
      if (operacion != null) {
        registros[i]['operacion'] = {
          ...registros[i]['operacion'] as Map,
          ...operacion,
        };
      }
      encontrado = true;
      break;
    }
  }
  
  if (!encontrado) {
    return false;
  }
  
  // 4. Guardar los cambios
  int updated = await db.update(
    'Operacion_scissor',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

Future<Map<String, dynamic>> getOperacionByEstadoIdScissor(
    int operacionId, int estadoId) async {

  final db = await database;

  final result = await db.query(
    'Operacion_scissor',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'origen_nivel': '',
      'origen_tipo_labor': '',
      'origen_labor': '',
      'origen_ala': '',
      'destino_nivel': '',
      'destino_tipo_labor': '',
      'destino_labor': '',
      'destino_ala': '',
      'observaciones': '',
    };
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';

  try {
    List<dynamic> registros = jsonDecode(registrosJson);

    var estadoEncontrado = registros.firstWhere(
      (estado) => estado['id'] == estadoId,
      orElse: () => null,
    );

    if (estadoEncontrado != null &&
        estadoEncontrado.containsKey('operacion')) {

      return Map<String, dynamic>.from(estadoEncontrado['operacion']);

    } else {
      return {
        'origen_nivel': '',
        'origen_tipo_labor': '',
        'origen_labor': '',
        'origen_ala': '',
        'destino_nivel': '',
        'destino_tipo_labor': '',
        'destino_labor': '',
        'destino_ala': '',
        'observaciones': '',
      };
    }

  } catch (e) {
    print('Error decodificando registros: $e');

    return {
      'origen_nivel': '',
      'origen_tipo_labor': '',
      'origen_labor': '',
      'origen_ala': '',
      'destino_nivel': '',
      'destino_tipo_labor': '',
      'destino_labor': '',
      'destino_ala': '',
      'observaciones': '',
    };
  }
}

Future<bool> updateOperacionByEstadoIdScissor(
  int operacionId,
  int estadoId,
  Map<String, dynamic> operacionData,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_scissor',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    bool encontrado = false;
    
    // Buscar y actualizar el estado específico
    for (var i = 0; i < registros.length; i++) {
      if (registros[i]['id'] == estadoId) {
        // Mantener todos los datos del estado, solo actualizar el campo 'operacion'
        registros[i]['operacion'] = operacionData;
        encontrado = true;
        break;
      }
    }
    
    if (!encontrado) {
      print('⚠ Estado no encontrado en JSON');
      return false;
    }
    
    // Guardar en la base de datos
    int updated = await db.update(
      'Operacion_scissor',
      {
        'registros': jsonEncode(registros),
      },
      where: 'id = ?',
      whereArgs: [operacionId],
    );
    
    print('✔ Datos de perforación actualizados para estado $estadoId');
    return updated > 0;
  } catch (e) {
    print('Error actualizando datos de perforación: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> getCheckListByOperacionIdScissor(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_scissor',
    columns: ['check_list'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos, devolver lista vacía
    return [];
  }

  String checkListJson = result.first['check_list'] as String? ?? '[]';

  try {
    List<dynamic> lista = jsonDecode(checkListJson);
    // Asegurarse de que cada item sea Map<String, dynamic>
    return lista.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    print('Error decodificando checklist: $e');
    return [];
  }
}

Future<Map<String, dynamic>> getHorometrosByOperacionIdScissor(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_scissor',
    columns: ['horometros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultHorometros = {
    'horometro_principal': {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false
    },
    'diesel': {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false
    }
  };

  if (result.isEmpty) {
    return defaultHorometros;
  }

  String horometrosJson = result.first['horometros'] as String? ?? '{}';

  try {
    Map<String, dynamic> horometros = jsonDecode(horometrosJson);

    if (horometros.isEmpty) {
      return defaultHorometros;
    }

    return Map<String, dynamic>.from(horometros);

  } catch (e) {
    print('Error decodificando horómetros: $e');
    return defaultHorometros;
  }
}

Future<Map<String, dynamic>?> getUltimoEstadoByOperacionIdScissor(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_scissor',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
   try {
    List<dynamic> registros = jsonDecode(registrosJson);

    if (registros.isEmpty) return null;

    // ✅ SIMPLE: el último insertado es el último real
    return Map<String, dynamic>.from(registros.last);

  } catch (e) {
    print('Error obteniendo último estado: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> createReservaEstadoScissor(
  int operacionId,
  int numero,
  String horaInicio,
  String horaFinal,
) async {

  final db = await database;

  final result = await db.query(
    'Operacion_scissor',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';

  List<dynamic> registros = [];
  try {
    registros = jsonDecode(registrosJson);
  } catch (e) {
    registros = [];
  }

  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': numero,
    'estado': 'RESERVA',
    'codigo': '401',
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': {
      'origen_nivel': '',
      'origen_tipo_labor': '',
      'origen_labor': '',
      'origen_ala': '',

      'destino_nivel': '',
      'destino_tipo_labor': '',
      'destino_labor': '',
      'destino_ala': '',

      'observaciones': '',
    },
  };

  registros.add(nuevoEstado);

  await db.update(
    'Operacion_scissor',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<void> cerrarOperacionScissor(int operacionId) async {
    final Database db = await DatabaseHelper().database;

    await db.update(
      'Operacion_scissor',
      {'estado': 'cerrado'}, // Nuevo estado
      where: 'id = ?',
      whereArgs: [operacionId], // Parámetro para evitar SQL Injection
    );
  }

  Future<Map<String, dynamic>> getCondicionesEquipoByOperacionIdScissor(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_scissor',
    columns: ['condiciones_equipo'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultData = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '', // ✅ nuevo campo
  };

  if (result.isEmpty) {
    return defaultData;
  }

  String condicionesJson = result.first['condiciones_equipo'] as String? ?? '{}';

  try {
    Map<String, dynamic> condiciones = jsonDecode(condicionesJson);

    // 🔥 asegurar que el nuevo campo exista
    condiciones.putIfAbsent('horaLlenado', () => '');

    return condiciones;
  } catch (e) {
    print('Error decodificando condiciones de equipo: $e');
    return defaultData;
  }
}

Future<Map<String, dynamic>> getControlLlantasByOperacionIdScissor(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_scissor',
    columns: ['control_llantas'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos devolver estructura por defecto
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }

  String controlJson = result.first['control_llantas'] as String? ?? '{}';

  try {
    Map<String, dynamic> control = jsonDecode(controlJson);
    return control;
  } catch (e) {
    print('Error decodificando control de llantas: $e');
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }
}

Future<bool> deleteEstadoScissor(int operacionId, int estadoId) async {
  final db = await database;

  // 1. Obtener registros
  final result = await db.query(
    'Operacion_scissor',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return false;

  // 2. Parsear JSON
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  if (registros.isEmpty) return false;

  // 3. Convertir todo a Map seguro
  List<Map<String, dynamic>> lista =
      registros.map((e) => Map<String, dynamic>.from(e)).toList();

  // 4. Ordenar por numero (orden real)
  lista.sort((a, b) {
    return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
  });

  // 5. Buscar el estado a eliminar
  Map<String, dynamic>? estadoAEliminar;
  for (var e in lista) {
    if (e['id'] == estadoId) {
      estadoAEliminar = e;
      break;
    }
  }

  if (estadoAEliminar == null) return false;

  int numeroEliminar = estadoAEliminar['numero'] ?? 0;

  // 6. Filtrar (eliminar en cascada desde ese numero)
  List<Map<String, dynamic>> nuevosRegistros = [];
  List<Map<String, dynamic>> eliminados = [];

  for (var e in lista) {
    int numero = e['numero'] ?? 0;

    if (numero < numeroEliminar) {
      nuevosRegistros.add(e);
    } else {
      eliminados.add({
        'id': e['id'],
        'estado': e['estado'],
        'numero': numero,
        'hora_inicio': e['hora_inicio']
      });
    }
  }

  // Debug
  print("🗑️ Eliminados: ${eliminados.length}");
  for (var e in eliminados) {
    print("   - ${e['estado']} #${e['numero']} (${e['hora_inicio']})");
  }

  // 7. Renumerar secuencialmente
  for (int i = 0; i < nuevosRegistros.length; i++) {
    nuevosRegistros[i]['numero'] = i + 1;
  }

  // 8. Reconstruir horas finales (solo encadenar)
  for (int i = 0; i < nuevosRegistros.length; i++) {
    if (i < nuevosRegistros.length - 1) {
      nuevosRegistros[i]['hora_final'] =
          nuevosRegistros[i + 1]['hora_inicio'] ?? '';
    } else {
      nuevosRegistros[i]['hora_final'] = "";
    }
  }

  // 9. Guardar
  int updated = await db.update(
    'Operacion_scissor',
    {
      'registros': jsonEncode(nuevosRegistros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("📊 Final: ${nuevosRegistros.length} registros");

  return updated > 0;
}


Future<bool> updateControlLlantasScissor(
  int operacionId,
  Map<String, dynamic> controlLlantas,
) async {

  final db = await database;

  int updated = await db.update(
    'Operacion_scissor',
    {
      'control_llantas': jsonEncode(controlLlantas),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCheckListScissor(int operacionId, List<Map<String, dynamic>> checkList) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_scissor',
    {
      'check_list': jsonEncode(checkList),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCondicionesEquipoScissor(int operacionId, Map<String, dynamic> condiciones) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_scissor',
    {
      'condiciones_equipo': jsonEncode(condiciones),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateHorometrosScissor(int operacionId, Map<String, dynamic> horometros) async {
  final db = await database;
  
  int updated = await db.update(
    'Operacion_scissor',
    {
      'horometros': jsonEncode(horometros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}


// ANFOCHANGER INICIO----------------------------------------------------------------------------------------------------------------------------------------------------------
Future<int> insertOperacionAnfochanger(
  String fecha,
  String turno,
  String operador,
  String jefeGuardia,
  String equipo,
  String nEquipo, {
  List<Map<String, dynamic>>? checkListJson,
  List<Map<String, dynamic>>? horometrosBase, // 🔥 NUEVO
}) async {

  final db = await database; 

  /// 🔥 estructura base
  Map<String, dynamic> horometrosJson = {
    'horometro_principal': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'electrico': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
    'diesel': {'inicio': 0, 'final': 0, 'op': true, 'inop': false},
  };

  /// 🔥 aplicar valores de nube
  if (horometrosBase != null && horometrosBase.isNotEmpty) {
    for (var item in horometrosBase) {

      final tipo = item['tipo_horometro'];
      final finalValor = (item['final'] ?? 0).toDouble();

      if (horometrosJson.containsKey(tipo)) {
        horometrosJson[tipo]['inicio'] = finalValor;
      }
    }
  }

  /// Condiciones equipo
  Map<String, dynamic> condicionesEquipoJson = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '',
  };

  /// Control llantas
  Map<String, dynamic> controlLlantasJson = {
    'numero1': false,
    'numero2': false,
    'numero3': false,
    'numero4': false,
  };

  /// Checklist
  String checkListStr = jsonEncode(checkListJson ?? []);

  return await db.insert(
    'Operacion_anfochanger',
    {
      'fecha': fecha,
      'turno': turno,
      'operador': operador,
      'jefe_guardia': jefeGuardia,
      'equipo': equipo,
      'n_equipo': nEquipo,
      'horometros': jsonEncode(horometrosJson),
      'condiciones_equipo': jsonEncode(condicionesEquipoJson),
      'check_list': checkListStr,
      'control_llantas': jsonEncode(controlLlantasJson),
      'estado': 'activo',
      'envio': 0
    },
  );
}

Future<List<Map<String, dynamic>>> getOperacionAnfochangerByTurnoAndFechaMaster(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_anfochanger',
    where: 'turno = ? AND fecha = ? AND estado IN (?, ?)',
    whereArgs: [turno, fecha, 'activo', 'parciales'],
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionAnfochangerByTurnoAndFecha(
    String turno, String fecha) async {

  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_anfochanger',
    where: 'turno = ? AND fecha = ?',
    whereArgs: [turno, fecha],
  );

  return result;
}

// Función para obtener todos los estados de una operación
Future<List<Map<String, dynamic>>> getEstadosByOperacionIdAnfochanger(int operacionId) async {
  final db = await database;
  
  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return [];
  }
  
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  return registros.map((e) => Map<String, dynamic>.from(e)).toList();
}

Future<int> eliminarOperacionTalAnfochangerFisico(int id) async {
  final db = await database;

  final result = await db.delete(
    'Operacion_anfochanger',
    where: 'id = ?',
    whereArgs: [id],
  );

  return result; // devuelve el número de filas eliminadas
}

Future<bool> updateHoraFinalAnfochanger(int operacionId, int estadoId, String horaFinal) async {
  final db = await database;

  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  bool encontrado = false;
  String tipoEstado = "";

  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'].toString() == estadoId.toString()) {
      tipoEstado = registros[i]['estado']; // Guardar el tipo para log
      registros[i]['hora_final'] = horaFinal;
      encontrado = true;
      break;
    }
  }

  if (!encontrado) {
    print("⚠ Estado no encontrado en JSON");
    return false;
  }

  int updated = await db.update(
    'Operacion_anfochanger',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("✔ Hora final actualizada para estado $tipoEstado: $horaFinal");
  return updated > 0;
}

Future<Map<String, dynamic>?> createEstadoAnfochanger(
  int operacionId,
  String estado,
  String codigo,
  String horaInicio, {
  String? horaFinal,
  Map<String, dynamic>? operacion,
}) async {

  final db = await database;

  // 1. Obtener registros actuales
  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return null;
  }

  // 2. Parsear registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  // 3. Calcular número
  int nuevoNumero = 1;
  if (registros.isNotEmpty) {
    int ultimoNumero = registros.last['numero'] ?? 0;
    nuevoNumero = ultimoNumero + 1;
  }

  // 4. ID único
  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  /// NUEVA estructura del estado
  Map<String, dynamic> operacionSimple = {
    'origen_nivel': operacion?['origen_nivel'] ?? '',
    'origen_tipo_labor': operacion?['origen_tipo_labor'] ?? '',
    'origen_labor': operacion?['origen_labor'] ?? '',
    'origen_ala': operacion?['origen_ala'] ?? '',

    'n_taladros_cargados': operacion?['n_taladros_cargados'] ?? 0,
    'cantidad_anfo': operacion?['cantidad_anfo'] ?? 0,
    'n_cartuchos': operacion?['n_cartuchos'] ?? 0,

    'observaciones': operacion?['observaciones'] ?? '',
  };

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': nuevoNumero,
    'estado': estado,
    'codigo': codigo,
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': operacionSimple,
  };

  // 5. Agregar al array
  registros.add(nuevoEstado);

  // 6. Guardar
  await db.update(
    'Operacion_anfochanger',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<bool> updateEstadoAnfochanger(
  int operacionId,
  int estadoId, {
  int? numero,
  String? estado,
  String? codigo,
  String? horaInicio,
  String? horaFinal,
  Map<String, String>? operacion,
}) async {
  final db = await database;
  
  // 1. Obtener el registro actual
  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  if (result.isEmpty) {
    return false;
  }
  
  // 2. Parsear el JSON de registros
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);
  
  // 3. Buscar y actualizar el estado específico
  bool encontrado = false;
  for (var i = 0; i < registros.length; i++) {
    if (registros[i]['id'] == estadoId) {
      // Actualizar solo los campos proporcionados
      if (numero != null) registros[i]['numero'] = numero;
      if (estado != null) registros[i]['estado'] = estado;
      if (codigo != null) registros[i]['codigo'] = codigo;
      if (horaInicio != null) registros[i]['hora_inicio'] = horaInicio;
      if (horaFinal != null) registros[i]['hora_final'] = horaFinal;
      if (operacion != null) {
        registros[i]['operacion'] = {
          ...registros[i]['operacion'] as Map,
          ...operacion,
        };
      }
      encontrado = true;
      break;
    }
  }
  
  if (!encontrado) {
    return false;
  }
  
  // 4. Guardar los cambios
  int updated = await db.update(
    'Operacion_anfochanger',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}

Future<Map<String, dynamic>> getOperacionByEstadoIdAnfochanger(
    int operacionId, int estadoId) async {

  final db = await database;

  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return {
      'origen_nivel': '',
      'origen_tipo_labor': '',
      'origen_labor': '',
      'origen_ala': '',
      'n_taladros_cargados': 0,
      'cantidad_anfo': 0,
      'n_cartuchos': 0,
      'observaciones': '',
    };
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';

  try {

    List<dynamic> registros = jsonDecode(registrosJson);

    var estadoEncontrado = registros.firstWhere(
      (estado) => estado['id'] == estadoId,
      orElse: () => null,
    );

    if (estadoEncontrado != null &&
        estadoEncontrado.containsKey('operacion')) {

      return Map<String, dynamic>.from(estadoEncontrado['operacion']);

    } else {

      return {
        'origen_nivel': '',
        'origen_tipo_labor': '',
        'origen_labor': '',
        'origen_ala': '',
        'n_taladros_cargados': 0,
        'cantidad_anfo': 0,
        'n_cartuchos': 0,
        'observaciones': '',
      };

    }

  } catch (e) {

    print('Error decodificando registros: $e');

    return {
      'origen_nivel': '',
      'origen_tipo_labor': '',
      'origen_labor': '',
      'origen_ala': '',
      'n_taladros_cargados': 0,
      'cantidad_anfo': 0,
      'n_cartuchos': 0,
      'observaciones': '',
    };
  }
}

Future<bool> updateOperacionByEstadoIdAnfochanger(
  int operacionId,
  int estadoId,
  Map<String, dynamic> operacionData,
) async {
  final db = await database;

  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    return false;
  }

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);
    bool encontrado = false;
    
    // Buscar y actualizar el estado específico
    for (var i = 0; i < registros.length; i++) {
      if (registros[i]['id'] == estadoId) {
        // Mantener todos los datos del estado, solo actualizar el campo 'operacion'
        registros[i]['operacion'] = operacionData;
        encontrado = true;
        break;
      }
    }
    
    if (!encontrado) {
      print('⚠ Estado no encontrado en JSON');
      return false;
    }
    
    // Guardar en la base de datos
    int updated = await db.update(
      'Operacion_anfochanger',
      {
        'registros': jsonEncode(registros),
      },
      where: 'id = ?',
      whereArgs: [operacionId],
    );
    
    print('✔ Datos de perforación actualizados para estado $estadoId');
    return updated > 0;
  } catch (e) {
    print('Error actualizando datos de perforación: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> getCheckListByOperacionIdAnfochanger(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['check_list'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos, devolver lista vacía
    return [];
  }

  String checkListJson = result.first['check_list'] as String? ?? '[]';

  try {
    List<dynamic> lista = jsonDecode(checkListJson);
    // Asegurarse de que cada item sea Map<String, dynamic>
    return lista.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    print('Error decodificando checklist: $e');
    return [];
  }
}

Future<Map<String, dynamic>> getHorometrosByOperacionIdAnfochanger(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['horometros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultHorometros = {
    'horometro_principal': {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false
    },
    'electrico': {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false
    },
    'diesel': {
      'inicio': 0,
      'final': 0,
      'op': true,
      'inop': false
    }
  };

  if (result.isEmpty) {
    return defaultHorometros;
  }

  String horometrosJson = result.first['horometros'] as String? ?? '{}';

  try {

    Map<String, dynamic> horometros = jsonDecode(horometrosJson);

    if (horometros.isEmpty) {
      return defaultHorometros;
    }

    /// Asegurar que los 3 horómetros existan (por migraciones)
    defaultHorometros.forEach((key, value) {
      horometros.putIfAbsent(key, () => value);
    });

    return Map<String, dynamic>.from(horometros);

  } catch (e) {
    print('Error decodificando horómetros: $e');
    return defaultHorometros;
  }
}

Future<Map<String, dynamic>?> getUltimoEstadoByOperacionIdAnfochanger(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';
  
  try {
    List<dynamic> registros = jsonDecode(registrosJson);

    if (registros.isEmpty) return null;

    // ✅ SIMPLE: el último insertado es el último real
    return Map<String, dynamic>.from(registros.last);

  } catch (e) {
    print('Error obteniendo último estado: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> createReservaEstadoAnfochanger(
  int operacionId,
  int numero,
  String horaInicio,
  String horaFinal,
) async {

  final db = await database;

  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return null;

  String registrosJson = result.first['registros'] as String? ?? '[]';

  List<dynamic> registros = [];
  try {
    registros = jsonDecode(registrosJson);
  } catch (e) {
    registros = [];
  }

  int nuevoId = DateTime.now().millisecondsSinceEpoch + registros.length;

  Map<String, dynamic> nuevoEstado = {
    'id': nuevoId,
    'numero': numero,
    'estado': 'RESERVA',
    'codigo': '401',
    'hora_inicio': horaInicio,
    'hora_final': horaFinal,
    'operacion': {
      'origen_nivel': '',
      'origen_tipo_labor': '',
      'origen_labor': '',
      'origen_ala': '',

      'n_taladros_cargados': 0,
      'cantidad_anfo': 0,

      'observaciones': '',
    },
  };

  registros.add(nuevoEstado);

  await db.update(
    'Operacion_anfochanger',
    {
      'registros': jsonEncode(registros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return nuevoEstado;
}

Future<void> cerrarOperacionAnfochanger(int operacionId) async {
    final Database db = await DatabaseHelper().database;

    await db.update(
      'Operacion_anfochanger',
      {'estado': 'cerrado'}, // Nuevo estado
      where: 'id = ?',
      whereArgs: [operacionId], // Parámetro para evitar SQL Injection
    );
  }

  Future<Map<String, dynamic>> getCondicionesEquipoByOperacionIdAnfochanger(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['condiciones_equipo'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  Map<String, dynamic> defaultData = {
    'op': false,
    'noOp': false,
    'lugar': '',
    'descripcion': '',
    'aceiteMotor': false,
    'aceiteHidraulico': false,
    'aceiteTransmision': false,
    'combustible': '',
    'horaLlenado': '', // ✅ nuevo campo
  };

  if (result.isEmpty) {
    return defaultData;
  }

  String condicionesJson = result.first['condiciones_equipo'] as String? ?? '{}';

  try {
    Map<String, dynamic> condiciones = jsonDecode(condicionesJson);

    // 🔥 asegurar que el nuevo campo exista
    condiciones.putIfAbsent('horaLlenado', () => '');

    return condiciones;
  } catch (e) {
    print('Error decodificando condiciones de equipo: $e');
    return defaultData;
  }
}

Future<Map<String, dynamic>> getControlLlantasByOperacionIdAnfochanger(int operacionId) async {
  final db = await database;

  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['control_llantas'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) {
    // Si no hay datos devolver estructura por defecto
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }

  String controlJson = result.first['control_llantas'] as String? ?? '{}';

  try {
    Map<String, dynamic> control = jsonDecode(controlJson);
    return control;
  } catch (e) {
    print('Error decodificando control de llantas: $e');
    return {
      'numero1': false,
      'numero2': false,
      'numero3': false,
      'numero4': false,
    };
  }
}

Future<bool> deleteEstadoAnfochanger(int operacionId, int estadoId) async {
  final db = await database;

  // 1. Obtener registros
  final result = await db.query(
    'Operacion_anfochanger',
    columns: ['registros'],
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  if (result.isEmpty) return false;

  // 2. Parsear JSON
  String registrosJson = result.first['registros'] as String? ?? '[]';
  List<dynamic> registros = jsonDecode(registrosJson);

  if (registros.isEmpty) return false;

  // 3. Convertir todo a Map seguro
  List<Map<String, dynamic>> lista =
      registros.map((e) => Map<String, dynamic>.from(e)).toList();

  // 4. Ordenar por numero (orden real)
  lista.sort((a, b) {
    return (a['numero'] ?? 0).compareTo(b['numero'] ?? 0);
  });

  // 5. Buscar el estado a eliminar
  Map<String, dynamic>? estadoAEliminar;
  for (var e in lista) {
    if (e['id'] == estadoId) {
      estadoAEliminar = e;
      break;
    }
  }

  if (estadoAEliminar == null) return false;

  int numeroEliminar = estadoAEliminar['numero'] ?? 0;

  // 6. Filtrar (eliminar en cascada desde ese numero)
  List<Map<String, dynamic>> nuevosRegistros = [];
  List<Map<String, dynamic>> eliminados = [];

  for (var e in lista) {
    int numero = e['numero'] ?? 0;

    if (numero < numeroEliminar) {
      nuevosRegistros.add(e);
    } else {
      eliminados.add({
        'id': e['id'],
        'estado': e['estado'],
        'numero': numero,
        'hora_inicio': e['hora_inicio']
      });
    }
  }

  // Debug
  print("🗑️ Eliminados: ${eliminados.length}");
  for (var e in eliminados) {
    print("   - ${e['estado']} #${e['numero']} (${e['hora_inicio']})");
  }

  // 7. Renumerar secuencialmente
  for (int i = 0; i < nuevosRegistros.length; i++) {
    nuevosRegistros[i]['numero'] = i + 1;
  }

  // 8. Reconstruir horas finales (solo encadenar)
  for (int i = 0; i < nuevosRegistros.length; i++) {
    if (i < nuevosRegistros.length - 1) {
      nuevosRegistros[i]['hora_final'] =
          nuevosRegistros[i + 1]['hora_inicio'] ?? '';
    } else {
      nuevosRegistros[i]['hora_final'] = "";
    }
  }

  // 9. Guardar
  int updated = await db.update(
    'Operacion_anfochanger',
    {
      'registros': jsonEncode(nuevosRegistros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  print("📊 Final: ${nuevosRegistros.length} registros");

  return updated > 0;
}


Future<bool> updateControlLlantasAnfochanger(
  int operacionId,
  Map<String, dynamic> controlLlantas,
) async {

  final db = await database;

  int updated = await db.update(
    'Operacion_anfochanger',
    {
      'control_llantas': jsonEncode(controlLlantas),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCheckListAnfochanger(int operacionId, List<Map<String, dynamic>> checkList) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_anfochanger',
    {
      'check_list': jsonEncode(checkList),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateCondicionesEquipoAnfochanger(int operacionId, Map<String, dynamic> condiciones) async {
  final db = await database;

  int updated = await db.update(
    'Operacion_anfochanger',
    {
      'condiciones_equipo': jsonEncode(condiciones),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );

  return updated > 0;
}

Future<bool> updateHorometrosAnfochanger(int operacionId, Map<String, dynamic> horometros) async {
  final db = await database;
  
  int updated = await db.update(
    'Operacion_anfochanger',
    {
      'horometros': jsonEncode(horometros),
    },
    where: 'id = ?',
    whereArgs: [operacionId],
  );
  
  return updated > 0;
}


//ENVIOS A LA NUBE---------------------------------------------------------------------
  //TAL-LARGO
  Future<int> actualizarEnvio( int id,
  double envio,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'envio': envio,
  };


    // Llamada a la función update
    return await db.update(
      'Operacion_tal_largo', // El nombre de la tabla
      data, // Los datos a actualizar
      where: 'id = ?', // Condición para seleccionar la fila
      whereArgs: [id], // El valor de id para seleccionar la fila específica
    );
  }

  Future<int> actualizarIdNubeOpseracion(int idOperacion, int idNube) async {
    final db = await database;
    return await db.update(
      'Operacion_tal_largo',
      {'idNube': idNube},
      where: 'id = ?',
      whereArgs: [idOperacion],
    );
  }

  Future<List<Map<String, dynamic>>> getOperacionesTaladroLargo() async {
  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_tal_largo',
    orderBy: 'id DESC', // opcional, para ver las más recientes primero
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionesNoEnviadasLargo() async {
  final db = await database;

  return await db.query(
    'Operacion_tal_largo',
    where: 'envio IN (?, ?)',
    whereArgs: [0, 0.5],
    orderBy: 'id DESC',
  );
}

//TAL-HORIZONTAL
Future<List<Map<String, dynamic>>> getOperacionesTaladroHorizontal() async {
  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_tal_horizontal',
    orderBy: 'id DESC', // opcional, para ver las más recientes primero
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionesTaladroHorizontalNoEnviadas() async {
  final db = await database;

  return await db.query(
    'Operacion_tal_horizontal',
    where: 'envio IN (?, ?)',
    whereArgs: [0, 0.5],
    orderBy: 'id DESC',
  );
}

Future<int> actualizarEnvioHorizontal( int id,
  double envio,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'envio': envio,
  };


    // Llamada a la función update
    return await db.update(
      'Operacion_tal_horizontal', // El nombre de la tabla
      data, // Los datos a actualizar
      where: 'id = ?', // Condición para seleccionar la fila
      whereArgs: [id], // El valor de id para seleccionar la fila específica
    );
  }

//EMPERNADOR
Future<List<Map<String, dynamic>>> getOperacionesTaladroEmpernador() async {
  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_empernador',
    orderBy: 'id DESC', // opcional, para ver las más recientes primero
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionesEmpernadorNoEnviadas() async {
  final db = await database;

  return await db.query(
    'Operacion_empernador',
    where: 'envio IN (?, ?)',
    whereArgs: [0, 0.5],
    orderBy: 'id DESC',
  );
}

  Future<int> actualizarEnvioEmpernador( int id,
  double envio,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'envio': envio,
  };


    // Llamada a la función update
    return await db.update(
      'Operacion_empernador', // El nombre de la tabla
      data, // Los datos a actualizar
      where: 'id = ?', // Condición para seleccionar la fila
      whereArgs: [id], // El valor de id para seleccionar la fila específica
    );
  }

//CARGUIO
Future<List<Map<String, dynamic>>> getOperacionesTaladroCarguio() async {
  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_carguio',
    orderBy: 'id DESC', // opcional, para ver las más recientes primero
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionesCarguioNoEnviadas() async {
  final db = await database;

  return await db.query(
    'Operacion_carguio',
    where: 'envio IN (?, ?)',
    whereArgs: [0, 0.5],
    orderBy: 'id DESC',
  );
}

Future<int> actualizarEnvioCarguio(
  int id,
  double envio,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'envio': envio,
  };

  return await db.update(
    'Operacion_carguio',
    data,
    where: 'id = ?',
    whereArgs: [id],
  );

}

  /// Actualiza el campo [envio] de varios registros en un solo UPDATE batch.
  /// Usa: envio=1 para confirmado, envio=0 para revertir, envio=2 para "en tránsito".
  Future<void> actualizarEnvioBatch(
    String tabla,
    List<int> ids,
    double envio,
  ) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(', ');
    await db.rawUpdate(
      'UPDATE $tabla SET envio = ? WHERE id IN ($placeholders)',
      [envio, ...ids],
    );
  }

  //ID NUBEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
  Future<int> actualizarIdNube(
  String tabla,
  int id,
  int idNube,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'idNube': idNube,
  };

  return await db.update(
    tabla,
    data,
    where: 'id = ?',
    whereArgs: [id],
  );

}


//Dumper-------------------------------------------------

Future<List<Map<String, dynamic>>> getOperacionesTaladroDumper() async {
  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_Dumper',
    orderBy: 'id DESC', // opcional, para ver las más recientes primero
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionesDumperNoEnviadas() async {
  final db = await database;

  return await db.query(
    'Operacion_Dumper',
    where: 'envio IN (?, ?)',
    whereArgs: [0, 0.5],
    orderBy: 'id DESC',
  );
}

  Future<int> actualizarEnvioDumper( int id,
  double envio,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'envio': envio,
  };


    // Llamada a la función update
    return await db.update(
      'Operacion_Dumper', // El nombre de la tabla
      data, // Los datos a actualizar
      where: 'id = ?', // Condición para seleccionar la fila
      whereArgs: [id], // El valor de id para seleccionar la fila específica
    );
  }

//ROMPE BANCOS
Future<List<Map<String, dynamic>>> getOperacionesTaladroRompeBaco() async {
  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_rompebanco',
    orderBy: 'id DESC', // opcional, para ver las más recientes primero
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionesRompeBancosNoEnviadas() async {
  final db = await database;

  return await db.query(
    'Operacion_rompebanco',
    where: 'envio IN (?, ?)',
    whereArgs: [0, 0.5],
    orderBy: 'id DESC',
  );
}

Future<int> actualizarEnvioRompeBancos( int id,
  double envio,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'envio': envio,
  };


    // Llamada a la función update
    return await db.update(
      'Operacion_rompebanco', // El nombre de la tabla
      data, // Los datos a actualizar
      where: 'id = ?', // Condición para seleccionar la fila
      whereArgs: [id], // El valor de id para seleccionar la fila específica
    );
  }

//SCALAMIN
Future<List<Map<String, dynamic>>> getOperacionesTaladroScalamin() async {
  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_Scalamin',
    orderBy: 'id DESC', // opcional, para ver las más recientes primero
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionesScalaminNoEnviadas() async {
  final db = await database;

  return await db.query(
    'Operacion_Scalamin',
    where: 'envio IN (?, ?)',
    whereArgs: [0, 0.5],
    orderBy: 'id DESC',
  );
}

Future<int> actualizarEnvioScalamin( int id,
  double envio,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'envio': envio,
  };


    // Llamada a la función update
    return await db.update(
      'Operacion_Scalamin', // El nombre de la tabla
      data, // Los datos a actualizar
      where: 'id = ?', // Condición para seleccionar la fila
      whereArgs: [id], // El valor de id para seleccionar la fila específica
    );
  }

//ANFOCHANGER
Future<List<Map<String, dynamic>>> getOperacionesTaladroAnfoChanger() async {
  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_anfochanger',
    orderBy: 'id DESC', // opcional, para ver las más recientes primero
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionesAnfoChangerNoEnviadas() async {
  final db = await database;

  return await db.query(
    'Operacion_anfochanger',
    where: 'envio IN (?, ?)',
    whereArgs: [0, 0.5],
    orderBy: 'id DESC',
  );
}

Future<int> actualizarEnvioRAnfoChanger( int id,
  double envio,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'envio': envio,
  };


    // Llamada a la función update
    return await db.update(
      'Operacion_anfochanger', // El nombre de la tabla
      data, // Los datos a actualizar
      where: 'id = ?', // Condición para seleccionar la fila
      whereArgs: [id], // El valor de id para seleccionar la fila específica
    );
  }


//scissor
Future<List<Map<String, dynamic>>> getOperacionesTaladroscissor() async {
  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_scissor',
    orderBy: 'id DESC', // opcional, para ver las más recientes primero
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionesVolquetes() async {
  final db = await database;

  final List<Map<String, dynamic>> result = await db.query(
    'Operacion_volquetes',
    orderBy: 'id DESC', // opcional, para ver las más recientes primero
  );

  return result;
}

Future<List<Map<String, dynamic>>> getOperacionesScissorNoEnviadas() async {
  final db = await database;

  return await db.query(
    'Operacion_scissor',
    where: 'envio IN (?, ?)',
    whereArgs: [0, 0.5],
    orderBy: 'id DESC',
  );
}

Future<int> actualizarEnvioscissor( int id,
  double envio,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'envio': envio,
  };


    // Llamada a la función update
    return await db.update(
      'Operacion_scissor', // El nombre de la tabla
      data, // Los datos a actualizar
      where: 'id = ?', // Condición para seleccionar la fila
      whereArgs: [id], // El valor de id para seleccionar la fila específica
    );
  }

  Future<int> actualizarEnvioVolquetes( int id,
  double envio,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'envio': envio,
  };


    // Llamada a la función update
    return await db.update(
      'Operacion_volquetes', // El nombre de la tabla
      data, // Los datos a actualizar
      where: 'id = ?', // Condición para seleccionar la fila
      whereArgs: [id], // El valor de id para seleccionar la fila específica
    );
  }


//EXPLOSIVOS ----------------------------------------------------------

Future<bool> estaRegistroCerrado(int idExploracion) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'Datos_trabajo_exploraciones',
      columns: ['cerrado'],
      where: 'id = ?',
      whereArgs: [idExploracion],
    );

    if (result.isNotEmpty) {
      return result.first['cerrado'] == 1;
    }
    return false; // Si no encuentra el registro, asumimos que no está cerrado
  }

  Future<int> updateEstadoExploracion(int id, String nuevoEstado) async {
    final db = await database;

    return await db.update(
      'Datos_trabajo_exploraciones',
      {'estado': nuevoEstado}, // Nuevo estado
      where: 'id = ?',
      whereArgs: [id], // Filtro por ID
    );
  }

  Future<List<TipoPerforacion>> getTiposPerforacion() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('TipoPerforacion');
    return List.generate(maps.length, (i) => TipoPerforacion.fromJson(maps[i]));
  }

  Future<List<PlanMensual>> getPlanes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('PlanMensual');
    return List.generate(maps.length, (i) => PlanMensual.fromJson(maps[i]));
  }

  Future<Map<String, dynamic>?> getPlanMensual({
    required String zona,
    required String tipoLabor,
    required String labor,
    required String estructuraVeta,
    required String nivel,
  }) async {
    final db = await database;

    List<Map<String, dynamic>> result = await db.query(
      'PlanMensual',
      columns: ['ancho_m', 'alto_m'], // Solo obtenemos estos campos
      where:
          'zona = ? AND tipo_labor = ? AND labor = ? AND estructura_veta = ? AND nivel = ?',
      whereArgs: [zona, tipoLabor, labor, estructuraVeta, nivel],
    );

    // Verificar si se encontraron resultados
    if (result.isNotEmpty) {
      return result
          .first; // Retorna solo los campos requeridos del primer registro encontrado
    } else {
      return null; // No se encontraron registros que coincidan
    }
  }
  Future<Map<String, dynamic>?> getExploracionById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'Datos_trabajo_exploraciones',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<int> updateExploracion(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      'Datos_trabajo_exploraciones',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertExploracionFull(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('Datos_trabajo_exploraciones', row);
  }

  Future<List<Map<String, String>>> getAccesoriosunidad() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db
        .query('accesorios', columns: ['tipo_accesorio', 'unidad_medida']);

    return maps
        .map((map) => {
              'tipo': map['tipo_accesorio'] as String,
              'unidad_medida': map['unidad_medida'] as String
            })
        .toList();
  }

  Future<List<Map<String, String>>> getExplosivosunidad() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db
        .query('explosivos', columns: ['tipo_explosivo', 'unidad_medida']);

    return maps
        .map((map) => {
              'tipo': map['tipo_explosivo'] as String,
              'unidad_medida': map['unidad_medida'] as String
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getDetalleDespachoByExploracionId(
      int exploracionId) async {
    final db = await database;
    return await db.query(
      'Despacho',
      where: 'datos_trabajo_id = ?', // Corrección aquí
      whereArgs: [exploracionId],
    );
  }

  Future<List<ExplosivosUni>> getExplosivosUni() async {
    final db = await database; // Obtener la instancia de la base de datos
    final List<Map<String, dynamic>> maps =
        await db.query('ExplosivosUni'); // Consultar la tabla

    return List.generate(
        maps.length,
        (i) => ExplosivosUni.fromJson(
            maps[i])); // Convertir los resultados en objetos
  }
  
  Future<List<Map<String, dynamic>>>
      getDetalleDespachoByDesapachoExposivosyAccesorios(int despachoId) async {
    final db = await database; // Obtiene la instancia de la base de datos
    return await db.query(
      'DespachoDetalle', // Nombre de la tabla a consultar
      where:
          'despacho_id = ?', // Condición de búsqueda: despacho_id debe coincidir
      whereArgs: [
        despachoId
      ], // Se pasa el valor de despachoId para evitar inyección SQL
    );
  }

  Future<List<Map<String, dynamic>>> getDetalleDespachoByDespachoId(
      int despachoId) async {
    final db = await database;
    return await db.query(
      'DetalleDespachoExplosivos',
      where: 'id_despacho = ?',
      whereArgs: [despachoId],
    );
  }
  Future<int> updateDespacho(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      'Despacho',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateDespachoDetalle(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      'DespachoDetalle',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

Future<void> insertDetallesDespacho(
      int idDespacho, List<Map<String, dynamic>> detalles) async {
    final db = await database;

    for (var detalle in detalles) {
      if (detalle['ms_cant1'].isNotEmpty || detalle['lp_cant1'].isNotEmpty) {
        await db.insert(
          'DetalleDespachoExplosivos',
          {
            'id_despacho':
                idDespacho, // Debe ser id_despacho en lugar de id_exploracion
            'numero': detalle['numero'],
            'ms_cant1': detalle['ms_cant1'],
            'lp_cant1': detalle['lp_cant1'],
          },
          conflictAlgorithm:
              ConflictAlgorithm.replace, // Reemplaza si ya existe
        );
      }
    }
  }

  Future<int> actualizarDetalleDespacho(int idDespacho, String detalle) async {
    final db = await database;
    return await db.update(
      'Despacho',
      {'observaciones': detalle},
      where: 'id = ?',
      whereArgs: [idDespacho],
    );
  }

  Future<int> actualizarTiemposDespacho(
      int idDespacho, double? milisegundo, double? medioSegundo) async {
    final db = await database;

    Map<String, dynamic> valores = {};
    if (milisegundo != null) valores['mili_segundo'] = milisegundo;
    if (medioSegundo != null) valores['medio_segundo'] = medioSegundo;

    if (valores.isEmpty) return 0; // Nada que actualizar

    return await db.update(
      'Despacho',
      valores,
      where: 'id = ?',
      whereArgs: [idDespacho],
    );
  }

  Future<List<Map<String, dynamic>>> getDetalleDevolucionesByExploracionId(
      int exploracionId) async {
    final db = await database;
    return await db.query(
      'Devoluciones',
      where: 'datos_trabajo_id = ?', // Corrección aquí
      whereArgs: [exploracionId],
    );
  }

Future<List<Map<String, dynamic>>> getDetalleDevolucionByDevolucionId(
      int devolucionId) async {
    final db = await database; // Obtiene la instancia de la base de datos
    return await db.query(
      'DevolucionDetalle', // Nombre de la tabla
      where: 'devolucion_id = ?', // Filtra por el ID de la devolución
      whereArgs: [
        devolucionId
      ], // Se pasa el ID como argumento para evitar inyección SQL
    );
  }

  //Exportar pdf:
  Future<List<Map<String, dynamic>>> obtenerEstructuraCompleta(
      int idPadre) async {
    final Database db = await database;

    // Obtener los datos del padre
    List<Map<String, dynamic>> datosTrabajo = await db.query(
      'Datos_trabajo_exploraciones',
      where: 'id = ?',
      whereArgs: [idPadre],
    );

    if (datosTrabajo.isEmpty) return [];

    // Obtener despacho relacionado con el padre
    List<Map<String, dynamic>> despachosRaw = await db.query(
      'Despacho',
      where: 'datos_trabajo_id = ?',
      whereArgs: [idPadre],
    );

    List<Map<String, dynamic>> despachos = [];
    for (var despacho in despachosRaw) {
      int despachoId = despacho['id'];

      // Obtener los detalles del despacho (explosivos)
      List<Map<String, dynamic>> detallesExplosivos = await db.query(
        'DetalleDespachoExplosivos',
        where: 'id_despacho = ?',
        whereArgs: [despachoId],
      );

      // Obtener los detalles del despacho (materiales)
      List<Map<String, dynamic>> detallesMateriales = await db.query(
        'DespachoDetalle',
        where: 'despacho_id = ?',
        whereArgs: [despachoId],
      );

      // Crear un nuevo mapa copiando los valores
      Map<String, dynamic> despachoModificado =
          Map<String, dynamic>.from(despacho);
      despachoModificado['detalles_explosivos'] = detallesExplosivos;
      despachoModificado['detalles_materiales'] = detallesMateriales;
      despachos.add(despachoModificado);
    }

    // Obtener devoluciones relacionadas con el padre
    List<Map<String, dynamic>> devolucionesRaw = await db.query(
      'Devoluciones',
      where: 'datos_trabajo_id = ?',
      whereArgs: [idPadre],
    );

    List<Map<String, dynamic>> devoluciones = [];
    for (var devolucion in devolucionesRaw) {
      int devolucionId = devolucion['id'];

      // Obtener los detalles de la devolución (explosivos)
      List<Map<String, dynamic>> detallesExplosivos = await db.query(
        'DetalleDevolucionesExplosivos',
        where: 'id_devolucion = ?',
        whereArgs: [devolucionId],
      );

      // Obtener los detalles de la devolución (materiales)
      List<Map<String, dynamic>> detallesMateriales = await db.query(
        'DevolucionDetalle',
        where: 'devolucion_id = ?',
        whereArgs: [devolucionId],
      );

      // Crear un nuevo mapa copiando los valores
      Map<String, dynamic> devolucionModificada =
          Map<String, dynamic>.from(devolucion);
      devolucionModificada['detalles_explosivos'] = detallesExplosivos;
      devolucionModificada['detalles_materiales'] = detallesMateriales;
      devoluciones.add(devolucionModificada);
    }

    // Estructurar la respuesta
    return datosTrabajo.map((dato) {
      return {
        ...dato,
        'despachos': despachos,
        'devoluciones': devoluciones,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getDetalleDevolucionesByDevolucionesId(
      int _DevolucionesId) async {
    final db = await database;
    return await db.query(
      'DetalleDevolucionesExplosivos',
      where: 'id_devolucion = ?',
      whereArgs: [_DevolucionesId],
    );
  }

  Future<int> updateDevoluciones(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      'Devoluciones',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateDevolucionDetalle(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      'DevolucionDetalle',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> actualizarTiemposDevoluciones(
      int _DevolucionesId, double? milisegundo, double? medioSegundo) async {
    final db = await database;

    Map<String, dynamic> valores = {};
    if (milisegundo != null) valores['mili_segundo'] = milisegundo;
    if (medioSegundo != null) valores['medio_segundo'] = medioSegundo;

    if (valores.isEmpty) return 0; // Nada que actualizar

    return await db.update(
      'Devoluciones',
      valores,
      where: 'id = ?',
      whereArgs: [_DevolucionesId],
    );
  }

  Future<void> cerrarRegistro(int idExploracion) async {
    final db = await database;
    await db.update(
      'Datos_trabajo_exploraciones',
      {'cerrado': 1}, // Marcar como cerrado
      where: 'id = ?',
      whereArgs: [idExploracion],
    );
  }

  Future<void> insertDetallesDevoluciones(
      int _DevolucionesId, List<Map<String, dynamic>> detalles) async {
    final db = await database;

    for (var detalle in detalles) {
      if (detalle['ms_cant1'].isNotEmpty || detalle['lp_cant1'].isNotEmpty) {
        await db.insert(
          'DetalleDevolucionesExplosivos',
          {
            'id_devolucion':
                _DevolucionesId, // Debe ser id_devolucion en lugar de id_exploracion
            'numero': detalle['numero'],
            'ms_cant1': detalle['ms_cant1'],
            'lp_cant1': detalle['lp_cant1'],
          },
          conflictAlgorithm:
              ConflictAlgorithm.replace, // Reemplaza si ya existe
        );
      }
    }
  }

  Future<int> actualizarDetalleDevolucion(
      int idDevolucion, String detalle) async {
    final db = await database;
    return await db.update(
      'Devoluciones',
      {'observaciones': detalle},
      where: 'id = ?',
      whereArgs: [idDevolucion],
    );
  }

  Future<int> insertExploracion(
      String fecha,
      String turno,
      String semanaDefault,
      int cantidadRetardos,
      Map<String, String> materialesDespacho,
      Map<String, String> materialesDevolucion) async {
    final db = await database;

    // Insertar en Datos_trabajo_exploraciones y obtener el ID generado
    int idExploracion = await db.insert(
      'Datos_trabajo_exploraciones',
      {
        'fecha': fecha,
        'turno': turno,
        'semanaDefault': semanaDefault,
        'estado': 'Creado',
      },
    );

    // Insertar un registro vacío en Despacho
    int idDespacho = await db.insert(
      'Despacho',
      {
        'datos_trabajo_id': idExploracion,
        'mili_segundo': 0.0,
        'medio_segundo': 0.0,
        'cantidad_retardos': cantidadRetardos,
      },
    );

    // Insertar los detalles del despacho (materiales)
    materialesDespacho.forEach((nombreMaterial, cantidad) async {
      await db.insert(
        'DespachoDetalle',
        {
          'despacho_id': idDespacho,
          'nombre_material': nombreMaterial,
          'cantidad': cantidad,
        },
      );
    });

    // Insertar un registro vacío en Devoluciones
    int idDevolucion = await db.insert(
      'Devoluciones',
      {
        'datos_trabajo_id': idExploracion,
        'mili_segundo': 0.0,
        'medio_segundo': 0.0,
        'cantidad_retardos': cantidadRetardos,
      },
    );

    // Insertar los detalles de la devolución (materiales)
    materialesDevolucion.forEach((nombreMaterial, cantidad) async {
      await db.insert(
        'DevolucionDetalle',
        {
          'devolucion_id': idDevolucion,
          'nombre_material': nombreMaterial,
          'cantidad': cantidad,
        },
      );
    });

    return idExploracion;
  }

Future<List<Map<String, dynamic>>> getExploraciones() async {
    final db = await database;
    return await db.query(
      'Datos_trabajo_exploraciones',
      orderBy: 'id DESC',
    );
  }

Future<List<Map<String, dynamic>>> getMateriales(String proceso) async {
  final db = await database;

  return await db.query(
    'materiales',
    where: 'proceso = ?',
    whereArgs: [proceso],
    orderBy: 'id DESC',
  );
}
  Future<List<Accesorio>> getAccesorios() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('accesorios');

    return List.generate(maps.length, (i) => Accesorio.fromJson(maps[i]));
  }

   Future<List<Explosivo>> getExplosivos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('explosivos');

    return List.generate(maps.length, (i) => Explosivo.fromJson(maps[i]));
  }
  
  Future<bool> eliminarEstructuraCompletaManual(int idExploracion) async {
    final db = await database;

    // Verificar si el registro está cerrado
    List<Map<String, dynamic>> resultado = await db.query(
      'Datos_trabajo_exploraciones',
      columns: ['cerrado'],
      where: 'id = ?',
      whereArgs: [idExploracion],
    );

    if (resultado.isNotEmpty && resultado.first['cerrado'] == 1) {
      print("El registro ya está cerrado y no se puede eliminar.");
      return false;
    }

    return await db.transaction((txn) async {
      // Eliminar primero los detalles de Despacho y Devoluciones
      await txn.delete(
        'DespachoDetalle',
        where:
            'despacho_id IN (SELECT id FROM Despacho WHERE datos_trabajo_id = ?)',
        whereArgs: [idExploracion],
      );

      await txn.delete(
        'DevolucionDetalle',
        where:
            'devolucion_id IN (SELECT id FROM Devoluciones WHERE datos_trabajo_id = ?)',
        whereArgs: [idExploracion],
      );

      // Eliminar los detalles de explosivos
      await txn.delete(
        'DetalleDespachoExplosivos',
        where:
            'id_despacho IN (SELECT id FROM Despacho WHERE datos_trabajo_id = ?)',
        whereArgs: [idExploracion],
      );

      await txn.delete(
        'DetalleDevolucionesExplosivos',
        where:
            'id_devolucion IN (SELECT id FROM Devoluciones WHERE datos_trabajo_id = ?)',
        whereArgs: [idExploracion],
      );

      // Eliminar los registros principales de Despacho y Devoluciones
      await txn.delete('Despacho',
          where: 'datos_trabajo_id = ?', whereArgs: [idExploracion]);
      await txn.delete('Devoluciones',
          where: 'datos_trabajo_id = ?', whereArgs: [idExploracion]);

      // Finalmente, eliminar la exploración principal
      await txn.delete('Datos_trabajo_exploraciones',
          where: 'id = ?', whereArgs: [idExploracion]);

      return true;
    });
  }


  //MEDICIONES.----------------------
  Future<List<Map<String, dynamic>>> obtenerExploracionesCompletas() async {
  try {
    final Database db = await database;
    
    // Obtener solo las exploraciones con medicion = 0
    final List<Map<String, dynamic>> exploraciones = await db.query(
      'nube_Datos_trabajo_exploraciones',
      where: 'medicion = ?',
      whereArgs: [0],
      orderBy: 'fecha DESC, turno DESC',
    );

    if (exploraciones.isEmpty) return [];

    List<Map<String, dynamic>> resultado = [];

    for (var exploracion in exploraciones) {
      // Crear un nuevo mapa mutable para la exploración
      Map<String, dynamic> exploracionCompleta = Map<String, dynamic>.from(exploracion);
      int exploracionId = exploracion['id'];
      String idnube = exploracion['idnube']?.toString() ?? '';

      // Obtener despachos relacionados
      exploracionCompleta['despachos'] = await _obtenerDespachosPorExploracion(exploracionId);
      
      // Obtener devoluciones relacionadas
      exploracionCompleta['devoluciones'] = await _obtenerDevolucionesPorExploracion(exploracionId);
      
      // Asegurar que idnube está incluido
      exploracionCompleta['idnube'] = idnube;

      resultado.add(exploracionCompleta);
    }

    return resultado;
  } catch (e) {
    print('Error al obtener exploraciones completas: $e');
    return [];
  }
}

Future<List<Map<String, dynamic>>> _obtenerDespachosPorExploracion(int exploracionId) async {
  final Database db = await database;
  final List<Map<String, dynamic>> despachos = await db.query(
    'nube_Despacho',
    where: 'datos_trabajo_id = ?',
    whereArgs: [exploracionId],
  );

  List<Map<String, dynamic>> despachosCompletos = [];

  for (var despacho in despachos) {
    // Crear un nuevo mapa mutable para el despacho
    Map<String, dynamic> despachoCompleto = Map<String, dynamic>.from(despacho);
    int despachoId = despacho['id'];
    
    // Obtener detalles normales del despacho
    despachoCompleto['detalles'] = await db.query(
      'nube_DespachoDetalle',
      where: 'despacho_id = ?',
      whereArgs: [despachoId],
    );
    
    // Obtener detalles de explosivos del despacho
    despachoCompleto['detalles_explosivos'] = await db.query(
      'nube_DetalleDespachoExplosivos',
      where: 'id_despacho = ?',
      whereArgs: [despachoId],
    );

    despachosCompletos.add(despachoCompleto);
  }

  return despachosCompletos;
}

Future<List<Map<String, dynamic>>> _obtenerDevolucionesPorExploracion(int exploracionId) async {
  final Database db = await database;
  final List<Map<String, dynamic>> devoluciones = await db.query(
    'nube_Devoluciones',
    where: 'datos_trabajo_id = ?',
    whereArgs: [exploracionId],
  );

  List<Map<String, dynamic>> devolucionesCompletas = [];

  for (var devolucion in devoluciones) {
    // Crear un nuevo mapa mutable para la devolución
    Map<String, dynamic> devolucionCompleta = Map<String, dynamic>.from(devolucion);
    int devolucionId = devolucion['id'];
    
    // Obtener detalles normales de la devolución
    devolucionCompleta['detalles'] = await db.query(
      'nube_DevolucionDetalle',
      where: 'devolucion_id = ?',
      whereArgs: [devolucionId],
    );
    
    // Obtener detalles de explosivos de la devolución
    devolucionCompleta['detalles_explosivos'] = await db.query(
      'nube_DetalleDevolucionesExplosivos',
      where: 'id_devolucion = ?',
      whereArgs: [devolucionId],
    );

    devolucionesCompletas.add(devolucionCompleta);
  }

  return devolucionesCompletas;
}


Future<List<TipoPerforacion>> getTiposPerforacionhorizontalfil() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'TipoPerforacion',
    where: 'proceso = ? AND permitido_medicion = ?',  // Cambio aquí
    whereArgs: ['PERFORACIÓN HORIZONTAL', 1],        // Cambio aquí
  );
  return List.generate(maps.length, (i) => TipoPerforacion.fromJson(maps[i]));
}

Future<int> insertarMedicionHorizontal(Map<String, dynamic> datos) async {
  final db = await database;
  return await db.insert(
    'mediciones_horizontal',
    datos,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> actualizarMedicionEXplosivo(List<int> ids) async {
  final db = await database;

  // Construir placeholders dinámicos (?, ?, ?)
  final placeholders = List.filled(ids.length, '?').join(',');

  await db.rawUpdate(
    'UPDATE nube_Datos_trabajo_exploraciones SET medicion = 1 WHERE id IN ($placeholders)',
    ids,
  );
}

  Future<List<Map<String, dynamic>>> obtenerExploracionesCompletasPorZona(String zona) async {
  try {
    final Database db = await database;
    
    // Obtener solo las exploraciones con medicion = 0 y la zona especificada
    final List<Map<String, dynamic>> exploraciones = await db.query(
      'nube_Datos_trabajo_exploraciones',
      where: 'medicion = ? AND zona = ?',
      whereArgs: [0, zona],
      orderBy: 'fecha DESC, turno DESC',
    );

    if (exploraciones.isEmpty) return [];

    List<Map<String, dynamic>> resultado = [];

    for (var exploracion in exploraciones) {
      // Crear un nuevo mapa mutable para la exploración
      Map<String, dynamic> exploracionCompleta = Map<String, dynamic>.from(exploracion);
      int exploracionId = exploracion['id'];
      String idnube = exploracion['idnube']?.toString() ?? '';

      // Obtener despachos relacionados
      exploracionCompleta['despachos'] = await _obtenerDespachosPorExploracion(exploracionId);
      
      // Obtener devoluciones relacionadas
      exploracionCompleta['devoluciones'] = await _obtenerDevolucionesPorExploracion(exploracionId);
      
      // Asegurar que idnube está incluido
      exploracionCompleta['idnube'] = idnube;

      resultado.add(exploracionCompleta);
    }

    return resultado;
  } catch (e) {
    print('Error al obtener exploraciones completas por zona: $e');
    return [];
  }
}
Future<List<Map<String, dynamic>>> obtenerTodasMedicionesHorizontal() async {
  final db = await database;
  final List<Map<String, dynamic>> result = await db.query(
    'mediciones_horizontal',
    orderBy: 'fecha DESC', // Ordenar por fecha descendente
  );
  return result;
}
Future<void> actualizarMedicionExplosivoACero(List<int> ids) async {
  if (ids.isEmpty) return; // ✅ Evita ejecución si la lista está vacía

  final db = await database;

  // Construir placeholders dinámicos (?, ?, ?)
  final placeholders = List.filled(ids.length, '?').join(',');

  await db.rawUpdate(
    'UPDATE nube_Datos_trabajo_exploraciones SET medicion = 0 WHERE id IN ($placeholders)',
    ids,
  );
}
Future<int> eliminarMultiplesMedicionesLargo(List<int> ids) async {
  if (ids.isEmpty) return 0;
  
  final db = await database;
  final placeholders = List.filled(ids.length, '?').join(',');
  
  return await db.delete(
    'mediciones_largo',
    where: 'id IN ($placeholders)',
    whereArgs: ids,
  );
}
//TONELADASSSS----------------------------------------------------------------------
Future<List<Map<String, dynamic>>> obtenerTodasToneladas() async {
  final db = await database;
  final List<Map<String, dynamic>> result = await db.query(
    'toneladas',
    orderBy: 'fecha DESC', // Ordenar por fecha descendente
  );
  return result;
}

  Future<List<TipoPerforacion>> getTiposPerforacionLargofil() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'TipoPerforacion',
    where: 'proceso = ? AND permitido_medicion = ?',
    whereArgs: ['PERFORACIÓN TALADROS LARGOS', 1],
  );
  return List.generate(maps.length, (i) => TipoPerforacion.fromJson(maps[i]));
}
Future<int> insertarMedicionLargo(Map<String, dynamic> datos) async {
  final db = await database;
  return await db.insert(
    'mediciones_largo',
    datos,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<List<Map<String, dynamic>>> obtenerTodasMedicionesLargo() async {
  final db = await database;
  final List<Map<String, dynamic>> result = await db.query(
    'mediciones_largo',
    orderBy: 'fecha DESC', // Ordenar por fecha descendente
  );
  return result;
}

Future<int> deleteDatosTrabajo(int id) async {
    final db = await database;
    return await db.delete(
      'Datos_trabajo_exploraciones',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> actualizarEnvioDatos_trabajo_exploraciones( int id,
  double envio,
) async {

  final db = await database;

  Map<String, dynamic> data = {
    'envio': envio,
  };


    // Llamada a la función update
    return await db.update(
      'Datos_trabajo_exploraciones', // El nombre de la tabla
      data, // Los datos a actualizar
      where: 'id = ?', // Condición para seleccionar la fila
      whereArgs: [id], // El valor de id para seleccionar la fila específica
    );
  }

//NUBE
Future<Map<String, dynamic>?> obtenerMedicionHorizontalPorId(int id) async {
  final Database db = await database;

  // Obtener el registro de mediciones_horizontal con el ID especificado
  List<Map<String, dynamic>> mediciones = await db.query(
    'mediciones_horizontal',
    where: 'id = ?',
    whereArgs: [id],
  );

  if (mediciones.isEmpty) return null;

  // Retornar el primer registro como Map<String, dynamic>
  return mediciones.first;
}

Future<int> eliminarMultiplesMedicionesHorizontal(List<int> ids) async {
  if (ids.isEmpty) return 0;
  
  final db = await database;
  final placeholders = List.filled(ids.length, '?').join(',');
  
  return await db.delete(
    'mediciones_horizontal',
    where: 'id IN ($placeholders)',
    whereArgs: ids,
  );
}

Future<int> actualizarEnvioMedicionesHorizontal(List<int> ids) async {
  final db = await database;
  final idPlaceholders = List.filled(ids.length, '?').join(', ');

  return await db.update(
    'mediciones_horizontal',
    {'envio': 1},
    where: 'id IN ($idPlaceholders)',
    whereArgs: ids,
  );
}

//EXPLOSIVOSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
//Cantidad de retardos a mostrar
Future<Map<String, dynamic>?> getUltimoNumeroRetardos() async {
  final db = await database;

  final result = await db.query(
    'numero_retardos',
    orderBy: 'id DESC',
    limit: 1,
  );

  if (result.isNotEmpty) {
    return result.first;
  }

  return null;
}

}