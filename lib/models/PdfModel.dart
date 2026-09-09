class PdfModel {
  final int id;
  final String nombre;
  final String urlPdf;
  final int carpetaId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relación opcional con la carpeta
  final CarpetaResumen? carpeta;

  PdfModel({
    required this.id,
    required this.nombre,
    required this.urlPdf,
    required this.carpetaId,
    required this.createdAt,
    required this.updatedAt,
    this.carpeta,
  });

  factory PdfModel.fromJson(Map<String, dynamic> json) {
    return PdfModel(
      id: json['id'],
      nombre: json['nombre'],
      urlPdf: json['url_pdf'],
      carpetaId: json['carpeta_id'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      carpeta: json['carpeta'] != null
          ? CarpetaResumen.fromJson(json['carpeta'])
          : null,
    );
  }

  factory PdfModel.fromMap(Map<String, dynamic> map) {
    return PdfModel(
      id: map['id'],
      nombre: map['nombre'],
      urlPdf: map['url_pdf'],
      carpetaId: map['carpeta_id'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'url_pdf': urlPdf,
      'carpeta_id': carpetaId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();
}

/// Resumen de carpeta embebido en la respuesta de PDFs
class CarpetaResumen {
  final int id;
  final String nombre;

  CarpetaResumen({required this.id, required this.nombre});

  factory CarpetaResumen.fromJson(Map<String, dynamic> json) {
    return CarpetaResumen(
      id: json['id'],
      nombre: json['nombre'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
      };
}
