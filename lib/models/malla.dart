class Malla {
  int? id;
  String tipoMalla;

  Malla({
    this.id,
    required this.tipoMalla,
  });

  // JSON → Objeto
  factory Malla.fromJson(Map<String, dynamic> json) {
    return Malla(
      id: json['id'],
      tipoMalla: json['tipo_malla'],
    );
  }

  // Objeto → Map (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo_malla': tipoMalla,
    };
  }
}