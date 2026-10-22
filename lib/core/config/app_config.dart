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

  // Credenciales de Google (OAuth) inyectadas en tiempo de compilación.
  // - GOOGLE_CLIENT_ID: client id de la app web/iOS (Google Cloud Console).
  // - GOOGLE_SERVER_CLIENT_ID: client id de tipo "web" (Android exige el
  //   server client id para obtener el id_token que valida Supabase).
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  // URL publica de la app web (PWA). Se usa para abrir la version
  // instalable desde el movil y para los enlaces de los correos.
  static const String webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://mano-ya.app',
  );

  // Webhook de n8n que recibe los reportes y las alertas operativas.
  // Si esta vacio el reporte queda registrado solo en la base de datos.
  static const String n8nWebhookUrl = String.fromEnvironment(
    'N8N_WEBHOOK_URL',
    defaultValue: '',
  );

  // Correo de soporte que recibe los reportes enviados desde la app.
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'soporte@manoya.app',
  );

  // Mientras no existan credenciales reales la app opera en modo mock.
  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Indica si hay credenciales de Google para el inicio de sesión con OAuth.
  ///
  /// Se exigen las dos: sin el `serverClientId` Android no puede validar
  /// el `id_token` contra Supabase.
  static bool get hasGoogleCredentials =>
      googleClientId.isNotEmpty && googleServerClientId.isNotEmpty;

  /// Indica si hay un webhook de n8n configurado para el envío de reportes.
  static bool get hasReportWebhook => n8nWebhookUrl.isNotEmpty;
}
