class ChecklistTelemando {
  int? id;
  String nombre;

  ChecklistTelemando({
    this.id,
    required this.nombre,
  });

  /// Convertir JSON → Objeto
  factory ChecklistTelemando.fromJson(Map<String, dynamic> json) {
    return ChecklistTelemando(
      id: json['id'],
      nombre: json['nombre'],
    );
  }

  /// Convertir Objeto → Map (para SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}