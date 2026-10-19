import 'dart:convert';
import 'dart:io';

class LocalPdfException implements Exception {
  const LocalPdfException(this.message);
  final String message;
}

/// Comprueba solo la cabecera; evita leer el documento completo dos veces.
Future<File> prepareLocalPdf(String filePath) async {
  final file = File(filePath);
  final stat = await file.stat();
  if (stat.type != FileSystemEntityType.file) {
    throw const LocalPdfException(
      'El archivo no está disponible. Actualiza los documentos y vuelve a intentarlo.',
    );
  }
  if (stat.size == 0) {
    throw const LocalPdfException(
      'El archivo está vacío. Vuelve a sincronizar los documentos.',
    );
  }
  final handle = await file.open();
  try {
    final header = await handle.read(1024);
    if (!latin1.decode(header).contains('%PDF-')) {
      throw const LocalPdfException(
        'El archivo descargado no es un PDF válido. Vuelve a sincronizar los documentos.',
      );
    }
  } finally {
    await handle.close();
  }
  return file;
}
