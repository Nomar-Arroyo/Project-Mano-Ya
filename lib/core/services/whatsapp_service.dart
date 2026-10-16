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
    // Limpiamos el teléfono y conservamos solo dígitos para wa.me.
    final number = phone.replaceAll(RegExp(r'[^0-9]'), '');
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
}
