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
/// El servicio devuelve `false` cuando Supabase no está configurado; los
/// errores reales de escritura se propagan para poder informar al usuario.
///
/// Se invoca desde el flujo de registro de la app (`AuthNotifier.register`),
/// una vez la cuenta ya fue creada y la sesión quedó activa.
class WorkerRegistrationService {
  WorkerRegistrationService({WorkersRepository? repository})
    : _repository = repository ?? WorkersRepository();

  final WorkersRepository _repository;

  /// Tabla con el perfil base del usuario.
  static const String profilesTable = 'profiles';

  /// Crea (o actualiza) la ficha del trabajador en la tabla `workers`.
  ///
  /// Devuelve `true` cuando la ficha quedó guardada y `false` cuando no hay
  /// backend configurado. Los errores reales se propagan.
  Future<bool> registerWorkerProfile({
    required String userId,
    required String name,
    String? phone,
    String? city,
    String? category,
    String? subcategory,
    String? bio,
    String? avatarUrl,
    double? latitude,
    double? longitude,
  }) async {
    if (userId.isEmpty) return false;
    if (SupabaseService.client == null) return false;
    final resolvedCategory = await _resolveCategory(userId, category);
    final resolvedSubcategory = subcategory?.trim() ?? '';
    final resolvedCity = city?.trim() ?? '';
    if (resolvedSubcategory.isEmpty || resolvedCity.isEmpty) {
      throw StateError(
        'Selecciona el oficio, la especialidad y la zona de trabajo para '
        'publicar tu perfil.',
      );
    }

    final client = SupabaseService.client!;
    final profileRows = await client
        .from(profilesTable)
        .update({
          'category': resolvedCategory,
          'subcategory': resolvedSubcategory,
          'bio': bio,
          'latitude': latitude,
          'longitude': longitude,
        })
        .eq('id', userId)
        .select('id');
    if (profileRows.isEmpty) {
      throw StateError(
        'No se pudo actualizar el perfil privado del trabajador.',
      );
    }

    final workerId = await _repository.upsertMyWorkerProfile(
      profileId: userId,
      name: name,
      category: resolvedCategory,
      subcategory: resolvedSubcategory,
      city: resolvedCity,
      phone: phone,
      bio: bio,
      avatarUrl: avatarUrl,
      latitude: latitude,
      longitude: longitude,
    );
    if (workerId == null) {
      throw StateError('No se pudo guardar la ficha del trabajador.');
    }
    return true;
  }

  /// Atajo para el flujo de registro: crea la ficha con los datos del
  /// formulario de registro. Si algo falla, el error llega a la interfaz.
  static Future<bool> registerAfterSignUp({
    required String userId,
    required String name,
    String? phone,
    String? city,
    String? category,
    String? subcategory,
    String? bio,
    double? latitude,
    double? longitude,
  }) async {
    return WorkerRegistrationService().registerWorkerProfile(
      userId: userId,
      name: name,
      phone: phone,
      city: city,
      category: category,
      subcategory: subcategory,
      bio: bio,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Resuelve el oficio elegido por el trabajador.
  Future<String> _resolveCategory(String userId, String? category) async {
    if (category != null && category.isNotEmpty) return category;

    final row = await SupabaseService.client!
        .from(profilesTable)
        .select('category')
        .eq('id', userId)
        .maybeSingle();
    final saved = row?['category']?.toString();
    if (saved != null && saved.isNotEmpty) return saved;
    throw StateError('Selecciona el oficio principal de tu perfil.');
  }
}
