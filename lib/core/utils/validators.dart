/// Validadores de formularios reutilizables (mensajes en español).
class Validators {
  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static const _venezuelanMobilePrefixes = {
    '412',
    '414',
    '416',
    '422',
    '424',
    '426',
  };

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

  /// Código numérico que Supabase envía por correo.
  ///
  /// La longitud la define el panel de Supabase (por defecto 8), así que se
  /// acepta cualquier valor entre 6 y 10 dígitos en vez de exigir seis.
  static String? emailCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return 'Ingresa el código';
    if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
      return 'El código debe tener entre 6 y 10 dígitos';
    }
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
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('58') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }

    if (digits.length != 10 ||
        digits[0] != '4' ||
        !_venezuelanMobilePrefixes.contains(digits.substring(0, 3))) {
      return 'Ingresa un móvil venezolano válido (412, 414, 416, 422, 424 o 426)';
    }
    return null;
  }
}
