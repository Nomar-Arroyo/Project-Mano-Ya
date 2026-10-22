import '../../../core/services/maps_service.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/worker.dart';

/// Repositorio del catálogo de trabajadores.
///
/// Tiene dos implementaciones:
/// 1. **Supabase** (preferida): lee la tabla `workers`, donde la columna
///    `category` guarda el nombre del oficio ('Construcción', 'Belleza',
///    'Costura', 'Mantenimiento', 'Automotriz', 'Eventos') y la columna
///    `status` solo admite 'available' o 'busy'.
/// 2. **Mock** (respaldo): mantiene el catálogo de ejemplo del MVP.
///
/// Si la consulta a Supabase falla (tabla inexistente, permisos o red) el
/// repositorio cae automáticamente en el modo mock para no romper la
/// experiencia del usuario.
class WorkersRepository {
  /// Tabla con la ficha pública de cada trabajador.
  static const String workersTable = 'workers';

  /// Indica si el backend de Supabase está disponible.
  bool get _hasBackend => SupabaseService.client != null;

  /// Lista trabajadores aplicando filtros por oficio, ciudad y disponibilidad.
  /// Si se envían coordenadas (`originLat`/`originLng`) los ordena por cercanía.
  Future<List<Worker>> list({
    String? category,
    String? city,
    bool onlyAvailable = false,
    double? originLat,
    double? originLng,
  }) async {
    if (_hasBackend) {
      try {
        return await _listFromSupabase(
          category: category,
          city: city,
          onlyAvailable: onlyAvailable,
          originLat: originLat,
          originLng: originLng,
        );
      } catch (_) {
        // Sin tabla o sin permisos: se usa el catálogo de ejemplo.
      }
    }
    return _listMock(
      category: category,
      city: city,
      onlyAvailable: onlyAvailable,
      originLat: originLat,
      originLng: originLng,
    );
  }

  /// Obtiene un trabajador por su id (para la pantalla de detalle).
  Future<Worker?> getById(String id) async {
    if (_hasBackend) {
      try {
        final row = await SupabaseService.client!
            .from(workersTable)
            .select()
            .eq('id', id)
            .maybeSingle();
        return row == null ? null : _workerFromRow(row);
      } catch (_) {
        // Sin tabla o id no válido: se busca en el catálogo de ejemplo.
      }
    }
    return _getMockById(id);
  }

  /// Crea o actualiza la ficha del trabajador autenticado en `workers`.
  ///
  /// La operación es idempotente: si ya existe una fila con el mismo
  /// `profile_id` se actualiza; si no existe se inserta una nueva. Así el
  /// trabajador recién registrado aparece en el catálogo de oficios.
  ///
  /// Devuelve el id de la fila creada o `null` cuando Supabase no está
  /// configurado o la escritura no fue posible.
  Future<String?> upsertMyWorkerProfile({
    required String profileId,
    required String name,
    required String category,
    String subcategory = '',
    String city = '',
    String? phone,
    String? bio,
    String? avatarUrl,
    double? latitude,
    double? longitude,
    bool identityVerified = false,
    bool workGuaranteed = true,
    String status = 'available',
  }) async {
    final client = SupabaseService.client;
    if (client == null || profileId.isEmpty) return null;

    final payload = <String, dynamic>{
      'profile_id': profileId,
      'name': name,
      'category': category,
      'subcategory': subcategory,
      'city': city,
      'phone': phone,
      'bio': bio,
      'avatar_url': avatarUrl,
      'identity_verified': identityVerified,
      'work_guaranteed': workGuaranteed,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
    };

    try {
      final rows = await client
          .from(workersTable)
          .upsert(payload, onConflict: 'profile_id')
          .select();
      if (rows.isNotEmpty) {
        return rows.first['id']?.toString();
      }
    } catch (_) {
      // La columna profile_id puede no tener restricción única todavía:
      // se hace el upsert manual (buscar la ficha y actualizarla o crearla).
    }

    try {
      final existing = await client
          .from(workersTable)
          .select('id')
          .eq('profile_id', profileId)
          .maybeSingle();
      if (existing != null) {
        await client
            .from(workersTable)
            .update(payload)
            .eq('id', existing['id']);
        return existing['id']?.toString();
      }
      final inserted = await client
          .from(workersTable)
          .insert(payload)
          .select()
          .single();
      return inserted['id']?.toString();
    } catch (_) {
      // Sin permisos o tabla inexistente: la ficha se podrá crear después.
      return null;
    }
  }

  /// Consulta el catálogo de trabajadores en Supabase.
  Future<List<Worker>> _listFromSupabase({
    String? category,
    String? city,
    bool onlyAvailable = false,
    double? originLat,
    double? originLng,
  }) async {
    // Cada filtro devuelve una consulta nueva, por eso se va reasignando.
    var query = SupabaseService.client!.from(workersTable).select();
    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (city != null && city.isNotEmpty) {
      final needle = city.split(',').first.trim();
      if (needle.isNotEmpty) {
        query = query.ilike('city', '%$needle%');
      }
    }
    if (onlyAvailable) {
      query = query.eq('status', 'available');
    }
    final rows = await query.order('rating', ascending: false);
    final workers = rows.map(_workerFromRow).toList();

    // Ordenamos por cercanía cuando conocemos el punto de origen.
    if (originLat != null && originLng != null) {
      workers.sort(
        (a, b) => _distance(
          a,
          originLat,
          originLng,
        ).compareTo(_distance(b, originLat, originLng)),
      );
    }
    return workers;
  }

  /// Convierte una fila de `workers` en el modelo [Worker].
  Worker _workerFromRow(Map<String, dynamic> row) {
    return Worker(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      category: row['category']?.toString() ?? '',
      subcategory: row['subcategory']?.toString() ?? '',
      city: row['city']?.toString() ?? '',
      identityVerified: row['identity_verified'] == true,
      workGuaranteed: row['work_guaranteed'] != false,
      status: row['status'] == 'busy'
          ? WorkerStatus.busy
          : WorkerStatus.available,
      availableToday: true,
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: (row['reviews_count'] as num?)?.toInt() ?? 0,
      avatarUrl: row['avatar_url']?.toString(),
      phone: row['phone']?.toString(),
      bio: row['bio']?.toString(),
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
    );
  }

  /// Catálogo de ejemplo cuando no hay backend configurado.
  Future<List<Worker>> _listMock({
    String? category,
    String? city,
    bool onlyAvailable = false,
    double? originLat,
    double? originLng,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final result = _workers.where((w) {
      if (onlyAvailable && !w.isAvailable) return false;
      if (category != null && category.isNotEmpty && w.category != category) {
        return false;
      }
      if (city != null && city.isNotEmpty && !_matchesCity(w.city, city)) {
        return false;
      }
      return true;
    }).toList();

    // Ordenamos por cercanía cuando conocemos el punto de origen.
    if (originLat != null && originLng != null) {
      result.sort(
        (a, b) => _distance(
          a,
          originLat,
          originLng,
        ).compareTo(_distance(b, originLat, originLng)),
      );
    }
    return result;
  }

  /// Busca un trabajador en el catálogo de ejemplo.
  Future<Worker?> _getMockById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    for (final w in _workers) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Compara la ciudad del trabajador con el texto del filtro. El filtro
  /// puede venir como "Caracas, Distrito Capital, Venezuela" y el trabajador
  /// como "Caracas, Distrito Capital"; comparamos por el primer segmento.
  bool _matchesCity(String workerCity, String filterCity) {
    final needle = filterCity.split(',').first.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return workerCity.toLowerCase().contains(needle);
  }

  /// Distancia en km del trabajador al punto de origen (infinito si no
  /// tiene coordenadas registradas).
  double _distance(Worker worker, double lat, double lng) {
    if (worker.latitude == null || worker.longitude == null) {
      return double.infinity;
    }
    return MapsService.distanceKm(
      lat,
      lng,
      worker.latitude!,
      worker.longitude!,
    );
  }

  /// Datos de ejemplo para el MVP.
  static const List<Worker> _workers = [
    Worker(
      id: '1',
      name: 'Carlos Ramírez',
      category: 'Construcción',
      subcategory: 'Albañil',
      city: 'Caracas, Distrito Capital',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.8,
      reviewsCount: 42,
      phone: '+58 412 111 2233',
      bio:
          'Maestro de obra con 15 años de experiencia en mampostería, '
          'pañetes y acabados. Trabajos garantizados y puntuales.',
      latitude: 10.4806,
      longitude: -66.9036,
    ),
    Worker(
      id: '2',
      name: 'Ana Torres',
      category: 'Belleza',
      subcategory: 'Manicure',
      city: 'Maracay, Aragua',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.9,
      reviewsCount: 28,
      phone: '+58 412 222 3344',
      bio:
          'Especialista en uñas acrílicas, semipermanentes y diseños '
          'personalizados. Atención a domicilio.',
      latitude: 10.2469,
      longitude: -67.5958,
    ),
    Worker(
      id: '3',
      name: 'Luis Pérez',
      category: 'Mantenimiento',
      subcategory: 'Electricista',
      city: 'Caracas, Distrito Capital',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.busy,
      rating: 4.7,
      reviewsCount: 15,
      phone: '+58 414 333 4455',
      bio:
          'Instalaciones eléctricas residenciales, tableros y '
          'certificados RETIE.',
      latitude: 10.1620,
      longitude: -68.0077,
    ),
    Worker(
      id: '4',
      name: 'María López',
      category: 'Costura',
      subcategory: 'Modista',
      city: 'Caracas, Distrito Capital',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.9,
      reviewsCount: 36,
      phone: '+58 416 444 5566',
      bio:
          'Confección y arreglo de prendas, diseños a medida y servicios '
          'de modistería rápida.',
      latitude: 10.1620,
      longitude: -68.0077,
    ),
    Worker(
      id: '5',
      name: 'Jorge Silva',
      category: 'Automotriz',
      subcategory: 'Mecánico',
      city: 'Maracay, Aragua',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.6,
      reviewsCount: 21,
      phone: '+58 424 555 6677',
      bio:
          'Mecánica general, revisión de frenos, suspensión y '
          'mantenimiento preventivo a domicilio.',
      latitude: 10.2469,
      longitude: -67.5958,
    ),
    Worker(
      id: '6',
      name: 'Diana Ruiz',
      category: 'Eventos',
      subcategory: 'Decoración',
      city: 'Caracas, Distrito Capital',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.busy,
      rating: 4.8,
      reviewsCount: 19,
      phone: '+58 426 666 7788',
      bio:
          'Decoración de eventos, montajes temáticos, globos y '
          'ambientación de fiestas.',
      latitude: 10.4806,
      longitude: -66.9036,
    ),
  ];
}
