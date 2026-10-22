import 'package:url_launcher/url_launcher.dart';

/// Servicio de comunicación directa por WhatsApp.
///
/// Genera enlaces `https://wa.me/TELEFONO?text=...` con un mensaje
/// predeterminado estructurado para poner en contacto al cliente con el
/// trabajador (al solicitar o aceptar un servicio).
class WhatsAppService {
  /// Construye el mensaje predeterminado que se enviará al trabajador.
  static String buildMessage({
    required String workerName,
    String? category,
    String? subcategory,
    String? city,
    String? clientName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('¡Hola $workerName! Te contacto desde Mano Ya.');
    buffer.writeln();
    buffer.write('Vi tu perfil');
    if (category != null && category.isNotEmpty) {
      buffer.write(' de $category');
    }
    if (subcategory != null && subcategory.isNotEmpty) {
      buffer.write(' ($subcategory)');
    }
    if (city != null && city.isNotEmpty) {
      buffer.write(' en $city');
    }
    buffer.writeln('.');
    buffer.writeln('Me gustaría solicitar un servicio.');
    if (clientName != null && clientName.isNotEmpty) {
      buffer.writeln('Mi nombre es $clientName.');
    }
    buffer.write('¿Estás disponible?');
    return buffer.toString();
  }

  /// Abre la conversación de WhatsApp con el número indicado.
  /// Devuelve `true` si se pudo lanzar la app de WhatsApp.
  static Future<bool> openChat({required String phone, String? message}) async {
    final number = _normalizePhone(phone);
    if (number.isEmpty) return false;

    final text = Uri.encodeComponent(message ?? '');
    final uri = Uri.parse(
      'https://wa.me/$number${text.isEmpty ? '' : '?text=$text'}',
    );

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Ignoramos: el llamador decide cómo avisar al usuario.
    }
    return false;
  }

  /// Prepara el teléfono para el enlace de WhatsApp.
  ///
  /// En Venezuela el número local tiene 10 dígitos y empieza por 0
  /// (0412-1112233). WhatsApp espera el formato internacional sin el cero
  /// inicial (584121112233), así que se normaliza antes de construir la URL.
  static String _normalizePhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    // Número local venezolano con el cero inicial: se quita ese cero.
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // Si no trae el prefijo del país se agrega el 58 de Venezuela.
    if (digits.length == 10) {
      digits = '58$digits';
    }

    return digits;
  }
}
