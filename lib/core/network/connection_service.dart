import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'connection_status.dart';

class ConnectionService {
  final Connectivity _connectivity = Connectivity();
  final InternetConnectionChecker _internetChecker =
      InternetConnectionChecker();

  final StreamController<ConnectionStatus> _controller =
      StreamController<ConnectionStatus>.broadcast();

  /// Último estado emitido; evita duplicados cuando ambas fuentes
  /// (connectivity_plus e internet_connection_checker) disparan el mismo estado.
  ConnectionStatus? _lastEmitted;

  Stream<ConnectionStatus> get connectionStream => _controller.stream;

  void initialize() {
    // Escuchar cambios de red (wifi, datos, etc.)
    _connectivity.onConnectivityChanged.listen((_) async {
      await _checkInternet();
    });

    // También escuchar cambios reales de internet
    _internetChecker.onStatusChange.listen((status) {
      if (status == InternetConnectionStatus.connected) {
        _emitStatus(ConnectionStatus.online);
      } else {
        _emitStatus(ConnectionStatus.offline);
      }
    });
  }

  /// Emite [status] solo si es diferente al último estado emitido.
  void _emitStatus(ConnectionStatus status) {
    if (_lastEmitted == status) return;
    _lastEmitted = status;
    _controller.add(status);
  }

  Future<void> _checkInternet() async {
    final bool hasInternet = await _internetChecker.hasConnection;
    _emitStatus(
      hasInternet ? ConnectionStatus.online : ConnectionStatus.offline,
    );
  }

  void dispose() {
    _controller.close();
  }
}