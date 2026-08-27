import 'package:flutter/material.dart';

class CustomMaterialDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final Function(String?)? onChanged;
  final IconData icon;
  final String hint;
  final Color? primaryColor;

  const CustomMaterialDropdown({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    required this.hint,
    this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = primaryColor ?? colorScheme.primary;
    final bool isEnabled = onChanged != null && items.isNotEmpty;

    // ✅ Validar que el value exista en items
    final bool valueExists = value != null && items.contains(value);
    final String? safeValue = valueExists ? value : null;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isEnabled ? Colors.grey[600] : Colors.grey[400],
        ),
        prefixIcon: Icon(
          icon,
          size: 16,
          color: isEnabled ? primary : Colors.grey,
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        filled: !isEnabled,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue, // ✅ Usar el valor validado
          hint: Text(
            hint,
            style: TextStyle(
              fontSize: 13,
              color: isEnabled ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: isEnabled ? primary : Colors.grey,
          ),
          iconSize: 18,
          isExpanded: true,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isEnabled ? const Color(0xFF2C3E50) : Colors.grey[500],
          ),
          items: items.isEmpty
              ? [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'No hay opciones',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                  ),
                ]
              : items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
          onChanged: isEnabled 
              ? (newValue) {
                  if (newValue != null) {
                    onChanged!(newValue);
                  }
                }
              : null,
        ),
      ),
    );
  }
}