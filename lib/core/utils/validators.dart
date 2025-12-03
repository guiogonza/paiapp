/// Utilidades para validación y sanitización de datos
class Validators {
  /// Valida y sanitiza la placa del vehículo
  /// Formato: Solo letras y números, sin caracteres especiales
  static String? validatePlaca(String? value) {
    if (value == null || value.isEmpty) {
      return 'La placa es requerida';
    }

    // Sanitización: Remover espacios y convertir a mayúsculas
    final sanitized = value.trim().toUpperCase();

    // Validación: Solo letras y números
    final placaRegex = RegExp(r'^[A-Z0-9]+$');
    if (!placaRegex.hasMatch(sanitized)) {
      return 'La placa solo puede contener letras y números';
    }

    // Validación de longitud (típicamente 6-7 caracteres)
    if (sanitized.length < 4 || sanitized.length > 10) {
      return 'La placa debe tener entre 4 y 10 caracteres';
    }

    return null;
  }

  /// Sanitiza la placa (remueve caracteres especiales y convierte a mayúsculas)
  static String sanitizePlaca(String value) {
    // Remover caracteres especiales, mantener solo letras y números
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    return sanitized;
  }

  /// Valida que un campo no esté vacío
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }
    return null;
  }

  /// Valida el año del vehículo
  static String? validateAno(String? value) {
    if (value == null || value.isEmpty) {
      return 'El año es requerido';
    }

    final ano = int.tryParse(value);
    if (ano == null) {
      return 'Ingresa un año válido';
    }

    final currentYear = DateTime.now().year;
    if (ano < 1900 || ano > currentYear + 1) {
      return 'El año debe estar entre 1900 y ${currentYear + 1}';
    }

    return null;
  }
}

