/// Servicio de envío de correos (mock de un proveedor real como SMTP o
/// SendGrid/Resend hasta integrarlo con el backend).
///
/// Se usa para enviar el reporte/recibo de pago al cliente cuando el
/// trabajador confirma que recibió el dinero.
class EmailService {
  /// Bandeja de salida simulada (útil para pruebas y para depurar).
  static final List<EmailReport> _outbox = [];

  /// Correos "enviados" durante la sesión.
  static List<EmailReport> get outbox => List.unmodifiable(_outbox);

  /// Envía un reporte por correo electrónico.
  ///
  /// [to] correo destino, [subject] asunto, [body] cuerpo en texto y
  /// [attachmentPath] ruta opcional del adjunto (p. ej. el recibo en PDF).
  /// Devuelve `true` si el envío fue aceptado.
  static Future<bool> sendReport({
    required String to,
    required String subject,
    required String body,
    String? attachmentPath,
  }) async {
    // Simula la latencia de red del proveedor de correo.
    await Future.delayed(const Duration(milliseconds: 700));

    final isValid = to.contains('@') && to.trim().length > 3;
    if (!isValid) return false;

    _outbox.add(
      EmailReport(
        to: to.trim(),
        subject: subject,
        body: body,
        attachmentPath: attachmentPath,
        sentAt: DateTime.now(),
      ),
    );
    return true;
  }
}

/// Envío registrado en la bandeja simulada.
class EmailReport {
  final String to;
  final String subject;
  final String body;
  final String? attachmentPath;
  final DateTime sentAt;

  const EmailReport({
    required this.to,
    required this.subject,
    required this.body,
    required this.sentAt,
    this.attachmentPath,
  });
}
