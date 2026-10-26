import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:i_miner/core/sync/sync_service.dart';

class TransferReviewScreen extends StatefulWidget {
  const TransferReviewScreen({
    super.key,
    required this.selected,
    this.inspect,
    this.commit,
  });
  final Map<String, Object?> selected;
  final Future<Map<String, dynamic>> Function()? inspect;
  final Future<void> Function(Map<String, dynamic>, bool)? commit;
  @override
  State<TransferReviewScreen> createState() => _TransferReviewScreenState();
}

class _TransferReviewScreenState extends State<TransferReviewScreen> {
  static const _primary = Color(0xFF1B5E6B);
  Map<String, dynamic>? _plan;
  bool _busy = false;
  bool _approved = false;
  String? _message;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _inspect();
  }

  Future<void> _inspect() async {
    setState(() {
      _busy = true;
      _approved = false;
      _plan = null;
      _message = null;
      _done = false;
    });
    try {
      final result =
          await (widget.inspect?.call() ??
              SyncService().withTransfers(
                (c) => c.inspectForReview(widget.selected),
              ));
      if (mounted) setState(() => _plan = result);
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit() async {
    final plan = _plan!;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (widget.commit != null) {
        await widget.commit!(plan, _approved);
      } else {
        await SyncService().withTransfers(
          (c) => c.applyReviewed(plan, verifiedAbsent: _approved),
        );
      }
      if (mounted) {
        setState(() {
          _done = true;
          _message =
              'Conciliación confirmada. El estado y el ID de nube se actualizaron.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _plan = null;
          _approved = false;
          _message = '$error';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _version(String title, Map data) => Card(
    elevation: 0,
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in {
            'fecha': 'Fecha',
            'turno': 'Turno',
            'operador': 'Operador',
            'n_equipo': 'Equipo',
            'estado': 'Estado',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text('${entry.value}: ${data[entry.key] ?? '—'}'),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Ver contenido completo'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(data),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final remote = _plan?['remote'] as Map?;
    final missing = remote?['status'] == 'missing';
    final identical = remote?['status'] == 'confirmed';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Conciliar operación'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Consulta y compara antes de decidir. La aplicación comprueba de nuevo la versión de nube al confirmar.',
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(color: _primary),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: SelectableText(_message!),
            ),
          if (_plan != null && !_done) ...[
            LayoutBuilder(
              builder: (context, size) {
                final local = _version(
                  'Copia de esta tablet',
                  _plan!['payload'] as Map,
                );
                final cloud = missing
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No se encontró ese UUID en nube. Esto no descarta una copia antigua guardada sin UUID.',
                          ),
                        ),
                      )
                    : _version(
                        'Versión actual de nube · ID ${remote?['server_id']}',
                        remote?['remote_payload'] as Map? ?? {},
                      );
                return size.maxWidth >= 900
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: local),
                          const SizedBox(width: 16),
                          Expanded(child: cloud),
                        ],
                      )
                    : Column(children: [local, cloud]);
              },
            ),
            if (!identical)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _approved,
                title: Text(
                  missing
                      ? 'Verifiqué en la base de nube que este registro NO existe, incluso entre las copias antiguas sin UUID.'
                      : 'Revisé ambas versiones y elijo actualizar la nube con la copia de esta tablet.',
                ),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _approved = value == true),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || (!identical && !_approved) ? null : _commit,
              icon: Icon(
                identical
                    ? Icons.cloud_done_outlined
                    : Icons.fact_check_outlined,
              ),
              label: Text(
                identical
                    ? 'Recuperar confirmación'
                    : missing
                    ? 'Crear registro verificado ausente'
                    : 'Confirmar versión elegida',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _inspect,
            icon: const Icon(Icons.refresh),
            label: const Text('Consultar nuevamente'),
          ),
        ],
      ),
    );
  }
}
