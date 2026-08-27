class LongitudBarras {
  int? id;
  String proceso;
  double longitudPies;

  LongitudBarras({
    this.id,
    required this.proceso,
    required this.longitudPies,
  });

  // JSON → Objeto
  factory LongitudBarras.fromJson(Map<String, dynamic> json) {
    return LongitudBarras(
      id: json['id'],
      proceso: json['proceso'],
      longitudPies: (json['longitud_pies'] as num).toDouble(),
    );
  }

  // Objeto → Map (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'proceso': proceso,
      'longitud_pies': longitudPies,
    };
  }
}