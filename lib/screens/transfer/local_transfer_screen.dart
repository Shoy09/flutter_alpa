import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:i_miner/core/transfer/transfer_pairing.dart';
import 'transfer_qr_scanner.dart';
import 'received_summary_screen.dart';
import 'transfer_review_screen.dart';
import 'package:i_miner/core/sync/sync_service.dart';
import 'package:i_miner/core/transfer/local_transfer_client.dart';
import 'package:i_miner/core/transfer/local_transfer_server.dart';
import 'package:i_miner/core/transfer/transfer_store.dart';
import 'package:i_miner/core/transfer/transfer_content.dart';

class LocalTransferScreen extends StatefulWidget {
  const LocalTransferScreen({
    super.key,
    required this.source,
    required this.canReceive,
    this.store,
  });
  final String source;
  final bool canReceive;
  final TransferStore? store;
  @override
  State<LocalTransferScreen> createState() => _LocalTransferScreenState();
}

class _LocalTransferScreenState extends State<LocalTransferScreen> {
  static const _channel = MethodChannel('i_miner/local_transfer');
  Future<void> _keepAwake(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('keepAwake', enabled);
    } on MissingPluginException {
      /* Necesita reinstalación sobre el APK anterior. */
    } on PlatformException {
      /* La copia permanece guardada si el equipo suspende. */
    }
  }

  final _host = TextEditingController();
  final _code = TextEditingController();
  LocalTransferServer? _server;
  TransferStore? _store;
  Timer? _timer;
  bool _busy = false;
  String _message = '';
  List<String> _addresses = [];
  List<Map<String, Object?>> _rows = [];
  List<Map<String, Object?>> _availableRows = [];
  static const labels = {
    'prepared': 'Preparado para entregar',
    'delivered': 'Entregado a maestra',
    'received': 'Recibido, pendiente de nube',
    'cloud': 'Confirmado en nube',
    'conflict': 'Requiere revisión',
    'review': 'Copiado; pendiente de conciliación',
  };

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    unawaited(_load());
    unawaited(_restoreHost());
  }

  String get _hostKey => 'transfer_last_host_${widget.source}';

  Future<void> _restoreHost() async {
    try {
      final host = await const FlutterSecureStorage().read(key: _hostKey);
      if (mounted &&
          _host.text.isEmpty &&
          host != null &&
          LocalTransferClient.privateAddress(host)) {
        _host.text = host;
      }
    } catch (_) {
      /* Connection preferences must not block transfers. */
    }
  }

  Future<void> _saveHost() async {
    try {
      await const FlutterSecureStorage().write(
        key: _hostKey,
        value: _host.text.trim(),
      );
    } catch (_) {
      /* Manual connection remains available. */
    }
  }

  Future<void> _scanPairing() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      setState(
        () => _message =
            'La cámara QR está disponible en las tablets Android. En Windows ingresa la IP y el código mostrados por la maestra.',
      );
      return;
    }
    final pairing = await Navigator.of(context).push<TransferPairing>(
      MaterialPageRoute(builder: (_) => const TransferQrScanner()),
    );
    if (!mounted || pairing == null) return;
    setState(() {
      _host.text = pairing.host;
      _code.text = pairing.code;
      _message =
          'Conexión cargada. Comprueba que ambas tablets estén en el mismo Wi-Fi y pulsa Enviar.';
    });
    await _saveHost();
  }

  Future<void> _showPairing(String address) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Conectar con la maestra'),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: TransferPairing(address, _server!.code).encode(),
                size: 260,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                'IP: $address\nCódigo: ${_server!.code}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Conecta la tablet operadora al mismo Wi-Fi y escanea este QR desde I-MINER. Es válido durante esta recepción.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );

  Future<void> _load({bool refreshAvailable = true}) async {
    try {
      _store ??= await SyncService().transferStore();
      final rows = await _store!.db.query(
        'LocalTransfers',
        columns: ['direction', 'type', 'uuid', 'source', 'status', 'cloud_id'],
        orderBy: 'updated_at DESC',
        limit: 500,
      );
      final available = refreshAvailable && !widget.canReceive
          ? await _store!.available()
          : _availableRows;
      if (mounted) {
        setState(() {
          _rows = rows;
          _availableRows = available;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await _keepAwake(true);
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      await _keepAwake(mounted && _server != null);
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  Future<void> _start() async {
    _store ??= await SyncService().transferStore();
    final server = LocalTransferServer(_store!);
    await server.start();
    if (!mounted) {
      await server.close();
      return;
    }
    _server = server;
    await _keepAwake(true);
    _addresses = await LocalTransferServer.addresses();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_load(refreshAvailable: false)),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_keepAwake(false));
    _timer?.cancel();
    unawaited(_server?.close() ?? Future<void>.value());
    _host.dispose();
    _code.dispose();
    super.dispose();
  }

  static const _primary = Color(0xFF1B5E6B);
  static const _ink = Color(0xFF2C3E50);
  static const _background = Color(0xFFF5F7FA);
  static const _names = {
    'tal_horizontal': 'Perforación horizontal',
    'tal_largo': 'Taladros largos',
    'empernador': 'Sostenimiento',
    'carguio': 'Carguío',
    'dumper': 'Dumper',
    'volquetes': 'Volquetes',
    'rompebanco': 'Rompebanco',
    'scissor': 'Scissor',
    'scalamin': 'Scalamin',
    'anfochanger': 'Anfochanger',
  };

  Color _statusColor(Object? status) => switch (status) {
    'cloud' => const Color(0xFF2E7D32),
    'conflict' || 'review' => const Color(0xFFB46916),
    _ => _primary,
  };

  Widget _badge(String text, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5EBEF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _primary, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF687888),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        child,
      ],
    ),
  );

  Widget _primaryButton(String label, IconData icon, VoidCallback? action) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: action,
          icon: Icon(icon, size: 19),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );

  Widget _connectionValue(String label, String value) => Container(
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: _background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5EBEF)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF687888), fontSize: 12),
              ),
              const SizedBox(height: 5),
              SelectableText(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copiar $label',
          icon: const Icon(Icons.copy_outlined, size: 19, color: _primary),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$label copiado')));
            }
          },
        ),
      ],
    ),
  );

  Widget _receiver() {
    final sources = _rows
        .where((row) => row['direction'] == 'inbox')
        .map((row) => row['source'])
        .toSet();
    return _card(
      icon: Icons.wifi_tethering,
      title: 'Tablet maestra',
      subtitle: 'Recibe las copias de los operadores a través de tu red Wi-Fi.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge(
            _server == null ? 'Recepción detenida' : 'Recepción activa',
            _server == null ? const Color(0xFF687888) : const Color(0xFF2E7D32),
            icon: _server == null ? Icons.pause_circle_outline : Icons.sensors,
          ),
          const SizedBox(height: 16),
          if (_server == null) ...[
            const Text(
              'Activa el punto de acceso en los ajustes del equipo y comparte los datos de conexión con los operadores.',
              style: TextStyle(color: _ink, height: 1.5),
            ),
            const SizedBox(height: 18),
            _primaryButton(
              'Iniciar recepción',
              Icons.play_arrow_rounded,
              _busy ? null : () => _run(_start),
            ),
          ] else ...[
            if (_addresses.isEmpty)
              const Text(
                'No hay una IP local disponible. Activa el punto de acceso.',
              )
            else
              for (final address in _addresses)
                _connectionValue('IP de la maestra', address),
            _connectionValue('Código de recepción', _server!.code),
            const SizedBox(height: 4),
            for (final address in _addresses.where(
              LocalTransferClient.privateAddress,
            )) ...[
              _primaryButton(
                _addresses.where(LocalTransferClient.privateAddress).length > 1
                    ? 'Mostrar QR · $address'
                    : 'Mostrar QR de conexión',
                Icons.qr_code_2,
                () => _showPairing(address),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'El operador escanea el QR desde su tablet para cargar la IP y el código.',
              style: TextStyle(
                color: Color(0xFF687888),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 18, color: _primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recibido de ${sources.length} operadores',
                    style: const TextStyle(color: _ink, fontSize: 13),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: Color(0xFFE5EBEF)),
            ),
            const Text(
              'Mantén esta pantalla abierta y la misma sesión durante la recepción.',
              style: TextStyle(color: _ink, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  _timer?.cancel();
                  await _server?.close();
                  await _keepAwake(false);
                  if (mounted) setState(() => _server = null);
                },
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Detener recepción'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB14848),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFE7CCCC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _input(String label, String hint, IconData icon) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: true,
        fillColor: _background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E7ED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E7ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 17,
        ),
      );

  Widget _sender() => _card(
    icon: Icons.send_outlined,
    title: 'Enviar a la maestra',
    subtitle:
        'Comparte tus operaciones cerradas y recoge las confirmaciones anteriores.',
    child: Column(
      children: [
        OutlinedButton.icon(
          onPressed: _busy || _server != null ? null : _scanPairing,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear QR de la maestra'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Primero conecta ambas tablets al mismo Wi-Fi local. La última IP se recuerda; el código cambia al iniciar otra recepción.',
          ),
        ),
        TextField(
          controller: _host,
          decoration: _input(
            'IP local de la maestra',
            '192.168.43.1',
            Icons.router_outlined,
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          decoration: _input(
            'Código de ocho dígitos',
            'Escribe el código de recepción',
            Icons.password_rounded,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
        ),
        const SizedBox(height: 20),
        _primaryButton(
          'Enviar y recoger confirmaciones',
          Icons.sync_alt_rounded,
          _busy || _server != null
              ? null
              : () => _run(() async {
                  final client = LocalTransferClient();
                  String counts() =>
                      'Confirmadas en nube: ${client.cloudConfirmed}. '
                      'Entregadas, pendientes de nube: ${client.deliveredToMaster}. '
                      'Por conciliar: ${client.pendingReview}.';
                  try {
                    await SyncService().withLocalTransfers(
                      (coordinator) => client.send(
                        coordinator,
                        widget.source,
                        _host.text.trim(),
                        _code.text.trim(),
                      ),
                    );
                  } on StateError catch (error) {
                    // Las entregadas ya quedaron registradas; mostrar ambas cosas.
                    throw StateError(
                      '${counts()}\n${error.message}',
                    );
                  }
                  await _saveHost();
                  if (mounted) {
                    setState(
                      () => _message =
                          '${counts()} Las copias originales se conservan.',
                    );
                  }
                }),
        ),
        if (_server != null)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Detén la recepción para enviar a otra maestra.',
              style: TextStyle(color: Color(0xFF687888), fontSize: 12),
            ),
          ),
      ],
    ),
  );

  Widget _cloud() => _card(
    icon: Icons.cloud_done_outlined,
    title: 'Confirmación en nube',
    subtitle:
        'Cuando tengas internet, sube las copias o comprueba cuáles ya fueron recibidas.',
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () => _run(() async {
                final result = await SyncService().syncData();
                if (mounted) {
                  setState(
                    () => _message =
                        'Consulta terminada. ${result.message}',
                  );
                }
              }),
        icon: const Icon(Icons.cloud_sync_outlined),
        label: const Text('Subir o confirmar con internet'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _primary),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
  );

  Future<void> _showCopy(Map<String, Object?> row) async {
    final records = await _store!.db.query(
      'LocalTransfers',
      where: 'direction = ? AND type = ? AND uuid = ?',
      whereArgs: [row['direction'], row['type'], row['uuid']],
    );
    if (!mounted || records.isEmpty) return;
    final copy = records.single;
    Map<String, Object?>? current;
    if (copy['direction'] == 'outbox') {
      final originals = await _store!.db.query(
        TransferContent.tables[copy['type']]!,
        columns: ['id', 'idNube', 'envio', 'estado', 'sync_uuid'],
        where: 'id = ? AND sync_uuid = ?',
        whereArgs: [copy['local_id'], copy['uuid']],
      );
      if (originals.isNotEmpty) current = originals.single;
    }
    if (!mounted) return;
    await _showData(
      {
        'estado_transferencia_actual': labels[copy['status']] ?? copy['status'],
        'idNube_confirmado_transferencia': copy['cloud_id'],
        if (copy['direction'] == 'outbox')
          'registro_local_actual': current ?? 'No se encontró el original',
        'copia_original_al_transferir': jsonDecode(copy['payload'] as String),
      },
      explanation:
          'La copia original conserva los valores del momento de la entrega. '
          'La confirmación actual se muestra por separado.',
      onReview: copy['status'] == 'cloud'
          ? null
          : () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TransferReviewScreen(selected: copy),
                ),
              );
              await _load();
            },
    );
  }

  Future<void> _showAvailable(Map<String, Object?> row) async {
    final records = await _store!.db.query(
      TransferContent.tables[row['type']]!,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    if (!mounted || records.isEmpty) return;
    await _showData(Map<String, dynamic>.from(records.single));
  }

  Future<void> _showData(
    Map<String, dynamic> data, {
    String? explanation,
    Future<void> Function()? onReview,
  }) async {
    final payload = const JsonEncoder.withIndent('  ').convert(data);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Copia completa de la operación',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (explanation != null) ...[
                  Text(explanation, style: const TextStyle(color: _primary)),
                  const SizedBox(height: 16),
                ],
                SelectableText(payload, style: const TextStyle(color: _ink)),
              ],
            ),
          ),
        ),
        actions: [
          if (onReview != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                unawaited(onReview());
              },
              child: const Text('Conciliar con nube'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _primary),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _available() => _card(
    icon: Icons.assignment_turned_in_outlined,
    title: 'Operaciones cerradas disponibles',
    subtitle:
        'Copias pendientes y confirmadas en nube, todavía sin transferencia registrada.',
    child: _availableRows.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'No hay operaciones cerradas nuevas para compartir. Las activas no se incluyen. '
              'Puedes compartir también las ya confirmadas en nube; las entregadas aparecen en el historial.',
              style: TextStyle(color: Color(0xFF687888), height: 1.5),
            ),
          )
        : Column(
            children: [
              for (final row in _availableRows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: _background,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _showAvailable(row),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              color: _primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_names[row['type']] ?? row['type']} · ID ${row['id']}',
                                    style: const TextStyle(
                                      color: _ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${row['fecha'] ?? ''} · ${row['turno'] ?? ''}\n${row['operador'] ?? ''}',
                                    style: const TextStyle(
                                      color: Color(0xFF687888),
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  _badge(
                                    row['needs_review'] == true
                                        ? 'Copia para conciliación'
                                        : row['cloud_confirmed'] == true
                                        ? 'En nube · compartir copia'
                                        : 'Lista para transferir',
                                    row['needs_review'] == true
                                        ? const Color(0xFFB46916)
                                        : _primary,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF9AA7B3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );

  Widget _operationLists() => Column(
    children: [
      if (widget.canReceive) ...[
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _store == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReceivedSummaryScreen(store: _store!),
                    ),
                  ),
            icon: const Icon(Icons.bar_chart_rounded),
            label: const Text('Resumen de operaciones recibidas'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
      if (!widget.canReceive) ...[_available(), const SizedBox(height: 18)],
      _activity(),
    ],
  );

  Widget _activity() => _card(
    icon: Icons.inventory_2_outlined,
    title: 'Historial de transferencias',
    subtitle:
        'Copias preparadas, enviadas o recibidas. No es el listado de operaciones nuevas.',
    child: _rows.isEmpty
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: Column(
              children: [
                Icon(
                  Icons.move_to_inbox_outlined,
                  size: 48,
                  color: _primary.withValues(alpha: .35),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aún no hay transferencias',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Las copias aparecerán aquí al preparar, enviar o recibir una transferencia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF687888), fontSize: 13),
                ),
              ],
            ),
          )
        : Column(
            children: [
              for (final row in _rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: _background,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showCopy(row),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  row['status'],
                                ).withValues(alpha: .09),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                row['status'] == 'cloud'
                                    ? Icons.cloud_done_outlined
                                    : [
                                        'conflict',
                                        'review',
                                      ].contains(row['status'])
                                    ? Icons.report_problem_outlined
                                    : Icons.swap_horiz_rounded,
                                color: _statusColor(row['status']),
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _names[row['type']] ?? '${row['type']}',
                                    style: const TextStyle(
                                      color: _ink,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${row['source']} · ${row['direction'] == 'inbox' ? 'Recibido' : 'Origen'}',
                                    style: const TextStyle(
                                      color: Color(0xFF687888),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  _badge(
                                    labels[row['status']] ?? '${row['status']}',
                                    _statusColor(row['status']),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Icon(
                                Icons.chevron_right,
                                color: Color(0xFF9AA7B3),
                                size: 19,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );

  Widget _stat(String title, int count, IconData icon, Color color) =>
      Container(
        width: 132,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5EBEF)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: Text(
                      title,
                      maxLines: 2,
                      style: const TextStyle(
                        color: Color(0xFF687888),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _counters() => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      if (!widget.canReceive)
        _stat(
          'Disponibles',
          _availableRows.length,
          Icons.assignment_turned_in_outlined,
          _primary,
        ),
      _stat('Copias', _rows.length, Icons.folder_copy_outlined, _primary),
      _stat(
        'En nube',
        _rows.where((r) => r['status'] == 'cloud').length,
        Icons.cloud_done_outlined,
        const Color(0xFF2E7D32),
      ),
      _stat(
        'Por revisar',
        _rows.where((r) => ['conflict', 'review'].contains(r['status'])).length,
        Icons.fact_check_outlined,
        const Color(0xFFB46916),
      ),
    ],
  );

  Widget _heading() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.canReceive
            ? 'Recibe y conserva las operaciones'
            : 'Comparte y conserva tus operaciones',
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
      ),
      const SizedBox(height: 7),
      const Text(
        'Conecta las tablets a la misma red Wi-Fi. No necesitas internet.',
        style: TextStyle(color: Color(0xFF687888), height: 1.5),
      ),
      const SizedBox(height: 10),
      _badge('Red local', _primary, icon: Icons.wifi_rounded),
    ],
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(
      context,
    ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: _primary)),
    child: Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Transferencias sin internet',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar listas',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : () => _load(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: _badge(
                widget.canReceive ? 'MASTER' : 'OPERADOR',
                Colors.white,
                icon: widget.canReceive
                    ? Icons.hub_outlined
                    : Icons.person_outline,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          return SingleChildScrollView(
            padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 28),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _heading()),
                          const SizedBox(width: 24),
                          _counters(),
                        ],
                      )
                    else ...[
                      _heading(),
                      const SizedBox(height: 16),
                      _counters(),
                    ],
                    const SizedBox(height: 24),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 18),
                        child: LinearProgressIndicator(color: _primary),
                      ),
                    if (_message.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F1F3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: _primary,
                              size: 21,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SelectableText(
                                _message,
                                style: const TextStyle(
                                  color: _ink,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 420,
                            child: Column(
                              children: [
                                if (widget.canReceive) ...[
                                  _receiver(),
                                  const SizedBox(height: 18),
                                ],
                                if (!widget.canReceive) ...[
                                  _sender(),
                                  const SizedBox(height: 18),
                                ],
                                _cloud(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 22),
                          Expanded(child: _operationLists()),
                        ],
                      )
                    else ...[
                      if (widget.canReceive) ...[
                        _receiver(),
                        const SizedBox(height: 18),
                      ],
                      if (!widget.canReceive) ...[
                        _sender(),
                        const SizedBox(height: 18),
                      ],
                      _cloud(),
                      const SizedBox(height: 18),
                      _operationLists(),
                    ],
                    const SizedBox(height: 20),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 17,
                          color: Color(0xFF687888),
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Tus copias originales se conservan. Si hay diferencias entre versiones, la operación queda para revisión.',
                            style: TextStyle(
                              color: Color(0xFF687888),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
