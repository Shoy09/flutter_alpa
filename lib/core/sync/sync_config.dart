class SyncConfig {
  final String tipo;
  final Future<List<Map<String, dynamic>>> Function() obtenerDatos;
  final Future<List<Map<String, dynamic>>> Function(Set<int>, List<Map<String, dynamic>>) exportar;
  final Future<void> Function(int) marcarEnviado;

  SyncConfig({
    required this.tipo,
    required this.obtenerDatos,
    required this.exportar,
    required this.marcarEnviado,
  });
}