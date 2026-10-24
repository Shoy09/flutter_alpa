import 'dart:async';
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
  Timer? _retryTimer;
  StreamSubscription<ConnectionStatus>? _subscription;

  ConnectionProvider() {
    _service.initialize();

    _subscription = _service.connectionStream.listen((newStatus) async {
      final previousStatus = _status;

      _status = newStatus;
      notifyListeners();

      if (previousStatus == ConnectionStatus.offline &&
          newStatus == ConnectionStatus.online) {
        await _syncPending();
      }
    });
    // Reintentar también cuando la conexión sigue disponible, sin exigir
    // desconectar y conectar la tablet. No es un servicio en segundo plano.
    _retryTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (isOnline) unawaited(_syncPending());
    });
  }

  Future<void> _syncPending() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await SyncService().syncData();
    } catch (error) {
      debugPrint('Error en sincronización: $error');
    } finally {
      _isSyncing = false;
    }
  }

  bool get isOnline => _status == ConnectionStatus.online;

  @override
  void dispose() {
    _retryTimer?.cancel();
    _subscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
