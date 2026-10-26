import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:i_miner/core/transfer/transfer_pairing.dart';

class TransferQrScanner extends StatefulWidget {
  const TransferQrScanner({super.key});
  @override
  State<TransferQrScanner> createState() => _TransferQrScannerState();
}

class _TransferQrScannerState extends State<TransferQrScanner> {
  bool _done = false;
  String _hint = 'Apunta al QR de la tablet maestra.';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear QR de la maestra')),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No se pudo abrir la cámara. Revisa el permiso de cámara en los ajustes o ingresa la IP y el código manualmente.',
                ),
              ),
            ),
            onDetect: (capture) {
              if (_done) return;
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw == null) continue;
                try {
                  final pairing = TransferPairing.parse(raw);
                  _done = true;
                  Navigator.of(context).pop(pairing);
                  return;
                } on FormatException {
                  if (_hint != 'Este QR no es una conexión de I-MINER.') {
                    setState(
                      () => _hint = 'Este QR no es una conexión de I-MINER.',
                    );
                  }
                }
              }
            },
          ),
        ),
        Padding(padding: const EdgeInsets.all(24), child: Text(_hint)),
      ],
    ),
  );
}
