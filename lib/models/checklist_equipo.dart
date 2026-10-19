/// Identidad estable del equipo para el catálogo sin conexión.
/// No usa ni almacena el ID autoincremental de la tabla local Equipo.
class ChecklistEquipo {
  final String codigo;
  final String proceso;

  const ChecklistEquipo({required this.codigo, required this.proceso});

  factory ChecklistEquipo.fromJson(Map<String, dynamic> json) {
    final codigo = json['codigo'];
    final proceso = json['proceso'];
    if (codigo is! String ||
        codigo.trim().isEmpty ||
        proceso is! String ||
        proceso.trim().isEmpty) {
      throw const FormatException(
        'La asignación de checklist necesita código y proceso del equipo.',
      );
    }
    return ChecklistEquipo(codigo: codigo.trim(), proceso: proceso.trim());
  }
}

String normalizarClaveChecklist(String value) {
  var result = value.trim().toUpperCase();
  const acentos = {
    'Á': 'A',
    'É': 'E',
    'Í': 'I',
    'Ó': 'O',
    'Ú': 'U',
    'Ü': 'U',
    'Ñ': 'N',
  };
  acentos.forEach(
    (origen, destino) => result = result.replaceAll(origen, destino),
  );
  return result.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
}
