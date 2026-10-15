// MOCK Supabase (pendiente de integración real por compañero)
// Usado temporalmente hasta recibir credenciales reales
class SupabaseMock {
  static bool get isConnected => false;
  static Future<void> init() async {}
}
