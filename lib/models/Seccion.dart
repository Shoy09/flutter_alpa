class Seccion {
  int? id;
  String proceso;
  String nombre;

  Seccion({
    this.id,
    required this.proceso,
    required this.nombre,
  });

  // Convertir de JSON a objeto
  factory Seccion.fromJson(Map<String, dynamic> json) {
    return Seccion(
      id: json['id'],
      proceso: json['proceso'],
      nombre: json['nombre'],
    );
  }

  // Convertir de objeto a Map (para SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'proceso': proceso,
      'nombre': nombre,
    };
  }
}