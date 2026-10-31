/// Variables de diseño (design tokens) compartidas por toda la app.
///
/// Centralizan espaciados, radios, duraciones y puntos de quiebre para
/// mantener una interfaz consistente y fácil de ajustar.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Radios de borde estandarizados.
class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;
}

/// Duraciones de animación estándar.
class AppDurations {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);
}

/// Puntos de quiebre responsivos (ancho de pantalla).
class AppBreakpoints {
  /// A partir de este ancho usamos el diseño split-screen de dos columnas.
  static const double splitScreen = 900;

  /// Ancho máximo del formulario para que no se estire en pantallas grandes.
  static const double formMaxWidth = 440;
}
