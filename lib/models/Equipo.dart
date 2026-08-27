class Equipo {
  int? id;
  String nombre;
  String proceso;
  String codigo;
  String marca;
  String modelo;
  String serie;
  int anioFabricacion;
  String fechaIngreso; // Se usa String para manejar formato ISO
  double? capacidadYd3;
  double? capacidadM3;

  Equipo({
    this.id,
    required this.nombre,
    required this.proceso,
    required this.codigo,
    required this.marca,
    required this.modelo,
    required this.serie,
    required this.anioFabricacion,
    required this.fechaIngreso,
    this.capacidadYd3,
    this.capacidadM3,
  });

  // Convertir de JSON a Objeto
  factory Equipo.fromJson(Map<String, dynamic> json) {
    return Equipo(
      id: json['id'],
      nombre: json['nombre'],
      proceso: json['proceso'],
      codigo: json['codigo'],
      marca: json['marca'],
      modelo: json['modelo'],
      serie: json['serie'],
      anioFabricacion: json['anioFabricacion'],
      fechaIngreso: json['fechaIngreso'], 
      capacidadYd3: json['capacidadYd3']?.toDouble(),
      capacidadM3: json['capacidadM3']?.toDouble(),
    );
  }

  // Convertir de Objeto a Map (para BD local)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'proceso': proceso,
      'codigo': codigo,
      'marca': marca,
      'modelo': modelo,
      'serie': serie,
      'anioFabricacion': anioFabricacion,
      'fechaIngreso': fechaIngreso,
      'capacidadYd3': capacidadYd3,
      'capacidadM3': capacidadM3,
    };
  }
}
