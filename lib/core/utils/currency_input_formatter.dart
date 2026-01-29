import 'package:flutter/services.dart';

/// Formateador de entrada para campos de moneda con separadores de miles
/// En Colombia: punto (.) para miles, coma (,) para decimales
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remover todos los caracteres que no sean dígitos o coma decimal
    String numericString = newValue.text.replaceAll(RegExp(r'[^\d,]'), '');

    // Evitar múltiples comas decimales
    final parts = numericString.split(',');
    if (parts.length > 2) {
      numericString = '${parts[0]},${parts.sublist(1).join()}';
    }

    // Limitar a 2 decimales
    if (parts.length == 2 && parts[1].length > 2) {
      numericString = '${parts[0]},${parts[1].substring(0, 2)}';
    }

    // Si está vacío después de limpiar, retornar vacío
    if (numericString.isEmpty) {
      return const TextEditingValue();
    }

    // Formatear con separadores de miles (puntos)
    String formatted;
    if (numericString.contains(',')) {
      // Si tiene decimales, separar la parte entera y decimal
      final decimalParts = numericString.split(',');
      final integerPart = decimalParts[0];
      final decimalPart = decimalParts[1];

      // Formatear la parte entera con puntos cada 3 dígitos
      final formattedInteger = _formatWithThousandsSeparator(integerPart);
      formatted = '$formattedInteger,$decimalPart';
    } else {
      // Si no tiene decimales, formatear la parte entera
      formatted = _formatWithThousandsSeparator(numericString);
    }

    // Calcular la nueva posición del cursor
    int newCursorPosition = newValue.selection.baseOffset;

    // Contar cuántos separadores hay antes del cursor
    final oldSeparatorsBeforeCursor = oldValue.text
        .substring(
          0,
          oldValue.selection.baseOffset.clamp(0, oldValue.text.length),
        )
        .replaceAll(RegExp(r'[^\.]'), '')
        .length;

    final newSeparatorsBeforeCursor = formatted
        .substring(0, newCursorPosition.clamp(0, formatted.length))
        .replaceAll(RegExp(r'[^\.]'), '')
        .length;

    // Ajustar posición del cursor basado en los separadores agregados/removidos
    newCursorPosition +=
        (newSeparatorsBeforeCursor - oldSeparatorsBeforeCursor);

    // Asegurar que el cursor esté en un rango válido
    if (newCursorPosition < 0) {
      newCursorPosition = 0;
    } else if (newCursorPosition > formatted.length) {
      newCursorPosition = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }

  /// Formatea un string numérico con puntos como separadores de miles
  String _formatWithThousandsSeparator(String numericString) {
    if (numericString.isEmpty) return '';

    // Invertir el string para facilitar el agrupamiento
    final reversed = numericString.split('').reversed.join();
    final List<String> groups = [];

    // Agrupar de 3 en 3
    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3).clamp(0, reversed.length);
      groups.add(reversed.substring(i, end));
    }

    // Unir los grupos con puntos y revertir de nuevo
    return groups.join('.').split('').reversed.join();
  }

  /// Método estático para obtener el valor numérico de un texto formateado
  static double? getNumericValue(String formattedText) {
    if (formattedText.isEmpty) return null;
    // Remover puntos de miles y reemplazar coma decimal por punto
    final numericString = formattedText
        .replaceAll('.', '') // Remover separadores de miles
        .replaceAll(',', '.'); // Cambiar coma decimal a punto
    return double.tryParse(numericString);
  }
}
