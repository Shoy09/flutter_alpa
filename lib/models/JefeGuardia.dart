class JefeGuardia {
  final String nombres;
  final String apellidos;

  JefeGuardia({required this.nombres, required this.apellidos});

  factory JefeGuardia.fromJson(Map<String, dynamic> json) {
    return JefeGuardia(
      nombres: json['nombres'],
      apellidos: json['apellidos'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombres': nombres,
      'apellidos': apellidos,
    };
  }
}
