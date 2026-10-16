class AppConfig {
  static const String appName = 'Mano Ya';
  static const String appTagline = 'Tus Oficios a la Mano';

  // Credenciales de Supabase inyectadas en tiempo de compilación.
  // Ejemplo:
  //   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  //               --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Mientras no existan credenciales reales la app opera en modo mock.
  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
