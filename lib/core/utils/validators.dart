/// Validadores de formularios reutilizables (mensajes en español).
class Validators {
  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static final RegExp _phone = RegExp(r'^[0-9+\s()-]{7,}$');

  /// Campo obligatorio genérico.
  static String? required(
    String? value, {
    String message = 'Campo obligatorio',
  }) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  /// Correo electrónico válido.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ingresa tu correo';
    if (!_email.hasMatch(value.trim())) return 'Correo no válido';
    return null;
  }

  /// Contraseña con longitud mínima.
  static String? password(String? value, {int min = 6}) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
    if (value.length < min) return 'Mínimo $min caracteres';
    return null;
  }

  /// Nombre completo (al menos dos palabras).
  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ingresa tu nombre';
    if (value.trim().split(' ').where((p) => p.isNotEmpty).length < 2) {
      return 'Escribe nombre y apellido';
    }
    return null;
  }

  /// Número de teléfono.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ingresa tu teléfono';
    if (!_phone.hasMatch(value.trim())) return 'Teléfono no válido';
    return null;
  }
}
