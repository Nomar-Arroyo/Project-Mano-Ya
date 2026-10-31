import 'package:flutter/material.dart';

class ManoYaColors {
  static const Color primary = Color(0xFF004AC6);
  static const Color primaryDark = Color(0xFF003EA8);
  static const Color primaryDeep = Color(0xFF00174B);
  static const Color primaryLight = Color(0xFF2563EB);
  static const Color secondary = Color(0xFFF97316);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);
  static const Color background = Color(0xFFFAF8FF);
  static const Color surfaceContainer = Color(0xFFF2F3FF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF131B2E);
  static const Color textSecondary = Color(0xFF434655);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF737686);
  static const Color whatsappGreen = Color(0xFF15803D);
  static const Color whatsappSurface = Color(0xFFECFDF5);
  static const Color verifiedSurface = Color(0xFFEFF6FF);

  // Paleta para el tema oscuro.
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF161F30);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkBorder = Color(0xFF293548);

  // Degradados de marca reutilizables (p. ej. panel de autenticación).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, Color(0xFF2563EB)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, Color(0xFFFB923C)],
  );
}
