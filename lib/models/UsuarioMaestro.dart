// lib/models/UsuarioMaestro.dart
import 'dart:convert';

class UsuarioMaestro {
  int? id;
  String codigoDni;
  String apellidos;
  String nombres;
  String? cargo;
  String? empresa;
  String? guardia;
  String? autorizadoEquipo;
  String? area;
  String? clasificacion;
  String? correo;
  String password; // Hasheado con bcrypt
  String? firma;
  String? rol;
  Map<String, dynamic>? operacionesAutorizadas;
  String createdAt;
  String updatedAt;

  UsuarioMaestro({
    this.id,
    required this.codigoDni,
    required this.apellidos,
    required this.nombres,
    this.cargo,
    this.empresa,
    this.guardia,
    this.autorizadoEquipo,
    this.area,
    this.clasificacion,
    this.correo,
    required this.password,
    this.firma,
    this.rol,
    this.operacionesAutorizadas,
    required this.createdAt,
    required this.updatedAt,
  });

  // 📥 From JSON (desde API)
  factory UsuarioMaestro.fromJson(Map<String, dynamic> json) {
    return UsuarioMaestro(
      id: json['id'],
      codigoDni: json['codigo_dni']?.toString() ?? '',
      apellidos: json['apellidos'] ?? '',
      nombres: json['nombres'] ?? '',
      cargo: json['cargo'] ?? '',
      empresa: json['empresa'] ?? '',
      guardia: json['guardia'] ?? '',
      autorizadoEquipo: json['autorizado_equipo'] ?? '',
      area: json['area'] ?? '',
      clasificacion: json['clasificacion'] ?? '',
      correo: json['correo'] ?? '',
      password: json['password'] ?? '', // Ya viene hasheada del backend
      firma: json['firma'] ?? '',
      rol: json['rol']?.toString() ?? '',
      operacionesAutorizadas: json['operaciones_autorizadas'] is Map
          ? json['operaciones_autorizadas']
          : (json['operaciones_autorizadas'] is String
              ? jsonDecode(json['operaciones_autorizadas'])
              : {}),
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  // 📤 To JSON (para enviar a API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo_dni': codigoDni,
      'apellidos': apellidos,
      'nombres': nombres,
      'cargo': cargo,
      'empresa': empresa,
      'guardia': guardia,
      'autorizado_equipo': autorizadoEquipo,
      'area': area,
      'clasificacion': clasificacion,
      'correo': correo,
      'password': password,
      'firma': firma,
      'rol': rol,
      'operaciones_autorizadas': operacionesAutorizadas,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // 📥 From Map (para SQLite)
  factory UsuarioMaestro.fromMap(Map<String, dynamic> map) {
    return UsuarioMaestro(
      id: map['id'],
      codigoDni: map['codigo_dni']?.toString() ?? '',
      apellidos: map['apellidos'] ?? '',
      nombres: map['nombres'] ?? '',
      cargo: map['cargo'] ?? '',
      empresa: map['empresa'] ?? '',
      guardia: map['guardia'] ?? '',
      autorizadoEquipo: map['autorizado_equipo'] ?? '',
      area: map['area'] ?? '',
      clasificacion: map['clasificacion'] ?? '',
      correo: map['correo'] ?? '',
      password: map['password'] ?? '',
      firma: map['firma'] ?? '',
      rol: map['rol']?.toString() ?? '',
      operacionesAutorizadas: map['operaciones_autorizadas'] is Map
          ? map['operaciones_autorizadas']
          : (map['operaciones_autorizadas'] is String
              ? jsonDecode(map['operaciones_autorizadas'])
              : {}),
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  // 📤 To Map (para SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo_dni': codigoDni,
      'apellidos': apellidos,
      'nombres': nombres,
      'cargo': cargo,
      'empresa': empresa,
      'guardia': guardia,
      'autorizado_equipo': autorizadoEquipo,
      'area': area,
      'clasificacion': clasificacion,
      'correo': correo,
      'password': password,
      'firma': firma,
      'rol': rol,
      'operaciones_autorizadas': jsonEncode(operacionesAutorizadas ?? {}),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // 🔄 Copiar con cambios
  UsuarioMaestro copyWith({
    int? id,
    String? codigoDni,
    String? apellidos,
    String? nombres,
    String? cargo,
    String? empresa,
    String? guardia,
    String? autorizadoEquipo,
    String? area,
    String? clasificacion,
    String? correo,
    String? password,
    String? firma,
    String? rol,
    Map<String, dynamic>? operacionesAutorizadas,
    String? createdAt,
    String? updatedAt,
  }) {
    return UsuarioMaestro(
      id: id ?? this.id,
      codigoDni: codigoDni ?? this.codigoDni,
      apellidos: apellidos ?? this.apellidos,
      nombres: nombres ?? this.nombres,
      cargo: cargo ?? this.cargo,
      empresa: empresa ?? this.empresa,
      guardia: guardia ?? this.guardia,
      autorizadoEquipo: autorizadoEquipo ?? this.autorizadoEquipo,
      area: area ?? this.area,
      clasificacion: clasificacion ?? this.clasificacion,
      correo: correo ?? this.correo,
      password: password ?? this.password,
      firma: firma ?? this.firma,
      rol: rol ?? this.rol,
      operacionesAutorizadas: operacionesAutorizadas ?? this.operacionesAutorizadas,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UsuarioMaestro{id: $id, codigoDni: $codigoDni, nombres: $nombres $apellidos, cargo: $cargo}';
  }
}