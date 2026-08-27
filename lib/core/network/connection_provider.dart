import 'package:flutter/material.dart';
import 'package:i_miner/core/sync/sync_service.dart';
import 'connection_service.dart';
import 'connection_status.dart';

// 👇 IMPORTANTE

class ConnectionProvider extends ChangeNotifier {
  final ConnectionService _service = ConnectionService();

  ConnectionStatus _status = ConnectionStatus.offline;

  ConnectionStatus get status => _status;

  bool _isSyncing = false; // 🔥 bloqueo

  ConnectionProvider() {
    _service.initialize();

    _service.connectionStream.listen((newStatus) async {
      final previousStatus = _status;

      _status = newStatus;
      notifyListeners();

      if (previousStatus == ConnectionStatus.offline &&
          newStatus == ConnectionStatus.online) {

        // 🔥 evitar múltiples sync simultáneos
        if (_isSyncing) {
          print("⚠️ Sync ya en progreso");
          return;
        }

        _isSyncing = true;

        try {
          print("🟢 Internet recuperado → lanzar sync");

          await SyncService().syncData();
        } catch (e) {
          print("❌ Error en sincronización: $e");
        } finally {
          _isSyncing = false;
        }
      }
    });
  }

  bool get isOnline => _status == ConnectionStatus.online;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}