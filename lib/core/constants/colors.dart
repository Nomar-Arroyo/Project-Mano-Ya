import 'package:flutter/material.dart';

class ManoYaColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color primaryDeep = Color(0xFF1D3D8F);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color secondary = Color(0xFFF97316);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF334155);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF64748B);

  // Paleta para el tema oscuro.
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkBorder = Color(0xFF334155);

  // Degradados de marca reutilizables (p. ej. panel de autenticación).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primaryDark, primary],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, Color(0xFFFB923C)],
  );
}
