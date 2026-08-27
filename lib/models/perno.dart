class Perno {
  int? id;
  String tipoPerno;
  double longitud;

  Perno({
    this.id,
    required this.tipoPerno,
    required this.longitud,
  });

  // JSON → Objeto
  factory Perno.fromJson(Map<String, dynamic> json) {
    return Perno(
      id: json['id'],
      tipoPerno: json['tipo_perno'],
      longitud: (json['longitud'] as num).toDouble(),
    );
  }

  // Objeto → Map (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo_perno': tipoPerno,
      'longitud': longitud,
    };
  }
}