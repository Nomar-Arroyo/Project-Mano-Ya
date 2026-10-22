import '../../../core/services/supabase_service.dart';
import 'workers_repository.dart';

/// Servicio que da de alta la ficha pública del trabajador.
///
/// Cuando una persona se registra como trabajador se crea su perfil en la
/// tabla `profiles`, pero el catálogo de oficios se alimenta de la tabla
/// `workers` (de lectura pública). Este servicio crea o actualiza esa fila
/// con `profile_id = auth.uid()` para que el trabajador recién registrado
/// aparezca en el catálogo.
///
/// El servicio es seguro cuando Supabase no está configurado: en ese caso no
/// hace nada y devuelve `false` para que el registro del usuario termine
/// igual de bien.
///
/// Se invoca desde el flujo de registro de la app (`AuthNotifier.register`),
/// una vez la cuenta ya fue creada y la sesión quedó activa.
class WorkerRegistrationService {
  WorkerRegistrationService({WorkersRepository? repository})
    : _repository = repository ?? WorkersRepository();

  final WorkersRepository _repository;

  /// Tabla con el perfil base del usuario.
  static const String profilesTable = 'profiles';

  /// Oficio asignado cuando el usuario todavía no ha elegido uno.
  static const String defaultCategory = 'Mantenimiento';

  /// Crea (o actualiza) la ficha del trabajador en la tabla `workers`.
  ///
  /// Devuelve `true` cuando la ficha quedó guardada en Supabase y `false`
  /// cuando no hay backend configurado o la escritura no fue posible.
  Future<bool> registerWorkerProfile({
    required String userId,
    required String name,
    String? phone,
    String? city,
    String? category,
    String? bio,
    String? avatarUrl,
  }) async {
    if (userId.isEmpty) return false;
    if (SupabaseService.client == null) return false;

    try {
      final workerId = await _repository.upsertMyWorkerProfile(
        profileId: userId,
        name: name,
        category: await _resolveCategory(userId, category),
        city: city ?? '',
        phone: phone,
        bio: bio,
        avatarUrl: avatarUrl,
      );
      return workerId != null;
    } catch (_) {
      // La ficha se podrá crear más adelante desde el perfil del trabajador.
      return false;
    }
  }

  /// Atajo para el flujo de registro: crea la ficha con los datos del
  /// formulario de registro y no interrumpe el proceso si algo falla.
  static Future<bool> registerAfterSignUp({
    required String userId,
    required String name,
    String? phone,
    String? city,
    String? category,
  }) async {
    return WorkerRegistrationService().registerWorkerProfile(
      userId: userId,
      name: name,
      phone: phone,
      city: city,
      category: category,
    );
  }

  /// Resuelve el oficio del trabajador.
  ///
  /// Se usa el indicado en el registro; si no hay, se toma el que está
  /// guardado en el perfil y, como último recurso, el oficio por defecto.
  Future<String> _resolveCategory(String userId, String? category) async {
    if (category != null && category.isNotEmpty) return category;

    try {
      final row = await SupabaseService.client!
          .from(profilesTable)
          .select('category')
          .eq('id', userId)
          .maybeSingle();
      final saved = row?['category']?.toString();
      if (saved != null && saved.isNotEmpty) return saved;
    } catch (_) {
      // Sin perfil legible: se usa el oficio por defecto.
    }
    return defaultCategory;
  }
}
