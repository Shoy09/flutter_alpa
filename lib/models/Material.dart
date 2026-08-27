class Material {
  int? id;
  String proceso;
  String nombre;

  Material({
    this.id,
    required this.proceso,
    required this.nombre,
  });

  // Convertir de JSON a Objeto
  factory Material.fromJson(Map<String, dynamic> json) {
    return Material(
      id: json['id'],
      proceso: json['proceso'],
      nombre: json['nombre'],
    );
  }

  // Convertir de Objeto a Map (para BD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'proceso': proceso,
      'nombre': nombre,
    };
  }
}