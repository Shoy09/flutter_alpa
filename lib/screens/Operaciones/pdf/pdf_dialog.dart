// widgets/pdf_dialog.dart
// Utilidad para abrir un PDF local en un diálogo.
// La navegación principal se hace desde PdfDetailScreen.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

Future<void> showPdfDialog(
  BuildContext context, {
  required String titulo,
  required String urlPdfLocal,
}) async {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Color(0xFF1B5E6B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: screenWidth * 0.9,
          height: screenHeight * 0.7,
          child: File(urlPdfLocal).existsSync()
              ? SfPdfViewer.file(File(urlPdfLocal))
              : _buildErrorContent(titulo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cerrar',
              style: TextStyle(
                color: Color(0xFF1B5E6B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildErrorContent(String titulo) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
      const SizedBox(height: 16),
      const Text(
        'No se pudo cargar el PDF',
        style: TextStyle(
          color: Color(0xFF1B5E6B),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        titulo,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        textAlign: TextAlign.center,
      ),
    ],
  );
}
