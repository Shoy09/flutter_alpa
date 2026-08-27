class CheckListItem {
  int? id;
  String proceso;
  String categoria;
  String nombre;

  CheckListItem({
    this.id,
    required this.proceso,
    required this.categoria,
    required this.nombre,
  });

  factory CheckListItem.fromJson(Map<String, dynamic> json) {
    return CheckListItem(
      id: json['id'],
      proceso: json['proceso'],
      categoria: json['categoria'],
      nombre: json['nombre'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'proceso': proceso,
      'categoria': categoria,
      'nombre': nombre,
    };
  }
}
