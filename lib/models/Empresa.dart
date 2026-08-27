class Empresa {
  int? id;
  String nombre;

  Empresa({
    this.id,
    required this.nombre,
  });

  // Convertir de JSON a Objeto
  factory Empresa.fromJson(Map<String, dynamic> json) {
    return Empresa(
      id: json['id'],
      nombre: json['nombre'],
    );
  }

  // Convertir de Objeto a Map (para BD local)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}