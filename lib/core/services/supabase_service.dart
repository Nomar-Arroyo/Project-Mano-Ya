import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Punto de acceso único a Supabase.
///
/// Si no hay credenciales configuradas (ver [AppConfig]) la app permanece en
/// modo mock y `client` devuelve `null`, de modo que las capas de datos deben
/// usar sus implementaciones simuladas. Cuando el compañero agregue la URL y la
/// anon key reales, basta con compilar con los `--dart-define` correspondientes
/// y la app pasará automáticamente al backend real.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  /// Indica si el cliente real de Supabase quedó inicializado.
  static bool get isConfigured => _initialized;

  // Inicializa Supabase solo si hay credenciales válidas; de lo contrario
  // permanece en modo mock sin lanzar errores.
  static Future<void> init() async {
    if (_initialized || !AppConfig.hasSupabaseCredentials) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  // Cliente activo o null cuando se trabaja con mocks.
  static SupabaseClient? get client =>
      _initialized ? Supabase.instance.client : null;
}
