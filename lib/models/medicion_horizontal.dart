class MedicionHorizontal {
  final int? id; // Solo para uso local, no se enviará a la nube
  final String fecha;
  final String? turno;
  final String? empresa;
  final String? zona;
  final String? labor;
  final String? veta;
  final String? tipoPerforacion;
  final double? kgExplosivos;
  final double? avanceProgramado;
  final double? ancho;
  final double? alto;
  final int? envio;
  final int? idExplosivo;
  final int? idnube;

  MedicionHorizontal({
    this.id,
    required this.fecha,
    this.turno,
    this.empresa,
    this.zona,
    this.labor,
    this.veta,
    this.tipoPerforacion,
    this.kgExplosivos,
    this.avanceProgramado,
    this.ancho,
    this.alto,
    this.envio,
    this.idExplosivo,
    this.idnube,
  });

  factory MedicionHorizontal.fromJson(Map<String, dynamic> json) {
    return MedicionHorizontal(
      id: json['id'],
      fecha: json['fecha'],
      turno: json['turno'],
      empresa: json['empresa'],
      zona: json['zona'],
      labor: json['labor'],
      veta: json['veta'],
      tipoPerforacion: json['tipo_perforacion'],
      kgExplosivos: json['kg_explosivos']?.toDouble(),
      avanceProgramado: json['avance_programado']?.toDouble(),
      ancho: json['ancho']?.toDouble(),
      alto: json['alto']?.toDouble(),
      envio: json['envio'],
      idExplosivo: json['id_explosivo'],
      idnube: json['idnube'],
    );
  }

  // Método toJson para enviar a la API (excluye el ID local)
  Map<String, dynamic> toApiJson() => {
        'fecha': fecha,
        if (turno != null) 'turno': turno,
        if (empresa != null) 'empresa': empresa,
        if (zona != null) 'zona': zona,
        if (labor != null) 'labor': labor,
        if (veta != null) 'veta': veta,
        if (tipoPerforacion != null) 'tipo_perforacion': tipoPerforacion,
        if (kgExplosivos != null) 'kg_explosivos': kgExplosivos,
        if (avanceProgramado != null) 'avance_programado': avanceProgramado,
        if (ancho != null) 'ancho': ancho,
        if (alto != null) 'alto': alto,
        if (envio != null) 'envio': envio,
        if (idExplosivo != null) 'id_explosivo': idExplosivo,
        if (idnube != null) 'idnube': idnube,
      };

  // Método toJson para uso local (incluye el ID)
  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'fecha': fecha,
        'turno': turno,
        'empresa': empresa,
        'zona': zona,
        'labor': labor,
        'veta': veta,
        'tipo_perforacion': tipoPerforacion,
        'kg_explosivos': kgExplosivos,
        'avance_programado': avanceProgramado,
        'ancho': ancho,
        'alto': alto,
        'envio': envio,
        'id_explosivo': idExplosivo,
        'idnube': idnube,
      };
}