/// Datos del enrolamiento TOTP pendiente de confirmar.
///
/// Contiene el secreto, el codigo QR en formato SVG y el URI `otpauth://`
/// para registrar la cuenta en Google Authenticator, Microsoft Authenticator
/// o cualquier aplicacion compatible con TOTP.
class MfaEnrollment {
  /// Identificador del factor en Supabase.
  final String factorId;

  /// Secreto Base32 entregado por Supabase.
  final String secret;

  /// Codigo QR en formato `data:image/svg+xml;utf-8,...`.
  final String qrCode;

  /// URI `otpauth://totp/...` con el secreto.
  final String uri;

  const MfaEnrollment({
    required this.factorId,
    required this.secret,
    required this.qrCode,
    required this.uri,
  });
}
