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

  // Secreto compartido con n8n. Viaja en la cabecera `X-Webhook-Secret` de
  // cada peticion al webhook para que solo quien lo conoce pueda generar
  // avisos de soporte.
  //
  // AVISO: en la web el bundle es publico, asi que cualquiera que abra el
  // codigo fuente puede leer este valor. Por eso el webhook de n8n debe
  // validar el secreto en el servidor (nodo Webhook -> Header Auth) y en la
  // Edge Function, no confiar solo en la cabecera. En el APK el valor va
  // dentro del binario y es mas dificil de extraer.
  static const String n8nWebhookSecret = String.fromEnvironment(
    'N8N_WEBHOOK_SECRET',
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

  /// Indica si hay un secreto configurado para autenticar las peticiones
  /// contra el webhook de n8n.
  static bool get hasWebhookSecret => n8nWebhookSecret.isNotEmpty;
}
