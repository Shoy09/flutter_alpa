import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'transfer_store.dart';

/// HTTP local deliberadamente separado de Azure. Sesión temporal con código,
/// límites de tamaño/tiempo y confirmación solo después de persistir en SQLite.
class LocalTransferServer {
  LocalTransferServer(this.store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final TransferStore store;
  final DateTime Function() _now;
  HttpServer? _server;
  String code = '';
  int get port => _server!.port;
  final _failures = <String, int>{};
  final _lastFailure = <String, DateTime>{};
  int _active = 0;
  Future<void> start({InternetAddress? address, int port = 47831}) async {
    _failures.clear();
    _lastFailure.clear();
    code = List.generate(8, (_) => Random.secure().nextInt(10)).join();
    _server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
    _server!.listen((request) => unawaited(_handle(request)));
  }

  Future<void> _handle(HttpRequest request) async {
    final peer = request.connectionInfo?.remoteAddress.address ?? '';
    try {
      if (_active >= 16) {
        request.response.statusCode = 503;
        return;
      }
      if ((_failures[peer] ?? 0) >= 10) {
        if (_now().difference(_lastFailure[peer]!).inSeconds < 30) {
          request.response.statusCode = 429;
          return;
        }
        _failures.remove(peer);
        _lastFailure.remove(peer);
      }
      if (request.headers.value('X-Transfer-Code') != code) {
        if (_failures.length < 1000) {
          _failures[peer] = (_failures[peer] ?? 0) + 1;
          _lastFailure[peer] = _now();
        }
        request.response.statusCode = 403;
        return;
      }
      if (request.method != 'POST' || request.uri.path != '/transfer') {
        request.response.statusCode = 404;
        return;
      }
      _active++;
      try {
        final bytes = <int>[];
        await for (final chunk in request.timeout(
          const Duration(seconds: 20),
        )) {
          if (bytes.length + chunk.length > 2 * 1024 * 1024) {
            request.response.statusCode = 413;
            return;
          }
          bytes.addAll(chunk);
        }
        final item = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(bytes)) as Map,
        );
        final receipt = await store.receive(item);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'ok': true, 'receipt': receipt}));
      } finally {
        _active--;
      }
    } catch (_) {
      request.response.statusCode = 400;
    } finally {
      try {
        await request.response.close();
      } on IOException {
        // El remitente puede desconectarse después del commit. Su reintento
        // recupera el mismo recibo; no debe tumbar la recepción de los demás.
      }
    }
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }

  static Future<List<String>> addresses() async => [
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    ))
      for (final address in interface.addresses)
        if (!address.isLoopback) address.address,
  ];
}
