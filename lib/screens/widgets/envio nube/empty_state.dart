import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String mensaje;
  final String? subtitulo;
  final IconData icono;
  final Color? color;

  const EmptyState({
    Key? key,
    required this.mensaje,
    this.subtitulo,
    this.icono = Icons.inbox,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (color ?? Colors.grey).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icono,
              size: 64,
              color: color ?? Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            mensaje,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.grey.shade600,
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitulo!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}