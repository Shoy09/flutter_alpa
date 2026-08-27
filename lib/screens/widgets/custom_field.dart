import 'package:flutter/material.dart';

class CustomMaterialField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool enabled;
  final Color? primaryColor;

  const CustomMaterialField({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
    this.enabled = true,
    this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = primaryColor ?? colorScheme.primary;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: enabled ? Colors.grey[600] : Colors.grey[400],
        ),
        prefixIcon: Icon(  // Solo UNA vez aquí
          icon,
          size: 16,
          color: enabled ? primary : Colors.grey,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        filled: !enabled,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: enabled ? const Color(0xFF2C3E50) : Colors.grey[600],
        ),
      ),
    );
  }
}