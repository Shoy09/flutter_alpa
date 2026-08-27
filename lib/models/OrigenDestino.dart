class OrigenDestino {
  int? id;
  String proceso;
  String tipo;
  String nombre;

  OrigenDestino({
    this.id,
    required this.proceso,
    required this.tipo,
    required this.nombre,
  });

  /// 🔹 De JSON a objeto
  factory OrigenDestino.fromJson(Map<String, dynamic> json) {
    return OrigenDestino(
      id: json['id'],
      proceso: json['proceso'],
      tipo: json['tipo'],
      nombre: json['nombre'],
    );
  }

  /// 🔹 De objeto a Map (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'proceso': proceso,
      'tipo': tipo,
      'nombre': nombre,
    };
  }
}