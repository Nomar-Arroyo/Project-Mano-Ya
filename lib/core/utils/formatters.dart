/// Utilidades de formato para mostrar datos en la interfaz (es-CO).
class Formatters {
  /// Formatea un valor monetario como `$ 320.000`.
  static String currency(num value) {
    final raw = value.toStringAsFixed(0);
    final separated = raw.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );
    return '\$ $separated';
  }

  /// Fecha corta en formato dd/mm/aaaa.
  static String date(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }

  /// Fecha con hora en formato dd/mm/aaaa hh:mm.
  static String dateTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '${date(value)} $h:$min';
  }
}
