class Guardia {
  int? id;
  String guardia;

  Guardia({
    this.id,
    required this.guardia,
  });

  factory Guardia.fromJson(Map<String, dynamic> json) {
    return Guardia(
      id: json['id'],
      guardia: json['guardia'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'guardia': guardia,
    };
  }
}