import '../../../core/services/supabase_service.dart';
import '../domain/saved_address.dart';
import '../domain/worker_profile.dart';

/// Repositorio del perfil extendido de Mano Ya.
///
/// Centraliza los datos que el mega-prompt define para ambos roles:
/// - Trabajador: portafolio express, bio y datos financieros de cobro.
/// - Cliente: direcciones/zonas guardadas y contratistas favoritos.
///
/// El repositorio tiene dos implementaciones:
/// 1. **Supabase** (preferida): usa las tablas `profiles`, `portfolio_items`,
///    `saved_addresses` y `favorites`.
/// 2. **Mock** (respaldo): mantiene los datos en memoria durante la sesión,
///    de modo que la app siga siendo navegable sin backend configurado.
///
/// Si una consulta a Supabase falla (por ejemplo, porque las tablas aún no
/// existen en el proyecto), el repositorio cae automáticamente en el modo
/// mock para no romper la experiencia del usuario.
class ProfileRepository {
  ProfileRepository._();

  /// Instancia única del repositorio.
  static final ProfileRepository instance = ProfileRepository._();

  // --- Nombres de las tablas en Supabase ---

  /// Tabla con el perfil base (nombre, rol, teléfono, ciudad, avatar, bio).
  static const String profilesTable = 'profiles';

  /// Tabla con las fotos del portafolio express del trabajador.
  static const String portfolioTable = 'portfolio_items';

  /// Tabla con las direcciones guardadas del cliente.
  static const String addressesTable = 'saved_addresses';

  /// Tabla con los contratistas favoritos del cliente.
  static const String favoritesTable = 'favorites';

  // --- Almacenamiento en memoria para el modo mock ---

  static final Map<String, WorkerProfile> _mockProfiles = {};
  static final Map<String, List<PortfolioItem>> _mockPortfolios = {};
  static final Map<String, List<SavedAddress>> _mockAddresses = {};
  static final Map<String, Set<String>> _mockFavorites = {};
  static int _mockSequence = 0;

  /// Genera un identificador único para los registros creados en modo mock.
  String _nextId(String prefix) {
    _mockSequence++;
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$_mockSequence';
  }

  /// Indica si el backend de Supabase está disponible.
  bool get _hasBackend => SupabaseService.client != null;

  // ------------------------------------------------------------------
  // PERFIL DEL TRABAJADOR
  // ------------------------------------------------------------------

  /// Carga el perfil extendido del trabajador.
  ///
  /// En Supabase lee la tabla `profiles`; si el usuario todavía no tiene fila
  /// se devuelve un perfil construido con los datos de la sesión activa.
  Future<WorkerProfile> loadWorkerProfile({
    required String userId,
    String displayName = '',
    String? phone,
    String? city,
    String? avatarUrl,
  }) async {
    if (_hasBackend) {
      try {
        final data = await SupabaseService.client!
            .from(profilesTable)
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (data != null) {
          final profile = WorkerProfile.fromJson(data);
          return profile.copyWith(
            displayName: profile.displayName.isEmpty
                ? displayName
                : profile.displayName,
            phone: profile.phone ?? phone,
            city: profile.city ?? city,
            avatarUrl: profile.avatarUrl ?? avatarUrl,
          );
        }
      } catch (_) {
        // Sin tablas configuradas: se continúa con el modo mock.
      }
    }

    final stored = _mockProfiles[userId];
    if (stored != null) return stored;

    return WorkerProfile(
      ownerId: userId,
      displayName: displayName,
      phone: phone,
      city: city,
      avatarUrl: avatarUrl,
    );
  }

  /// Guarda (o actualiza) el perfil extendido del trabajador.
  Future<void> saveWorkerProfile(WorkerProfile profile) async {
    if (_hasBackend) {
      try {
        await SupabaseService.client!
            .from(profilesTable)
            .upsert(profile.toJson())
            .eq('id', profile.ownerId);
      } catch (_) {
        // Si la tabla no existe, el cambio queda solo en memoria.
      }
    }
    _mockProfiles[profile.ownerId] = profile;
  }

  /// Actualiza únicamente la bio del trabajador.
  Future<void> saveBio({required String userId, required String bio}) async {
    final current = await loadWorkerProfile(userId: userId);
    await saveWorkerProfile(current.copyWith(bio: bio));
  }

  // ------------------------------------------------------------------
  // PORTAFOLIO EXPRESS (3 a 5 fotos)
  // ------------------------------------------------------------------

  /// Carga las fotos del portafolio del trabajador ordenadas por posición.
  Future<List<PortfolioItem>> loadPortfolio(String userId) async {
    if (_hasBackend) {
      try {
        final data = await SupabaseService.client!
            .from(portfolioTable)
            .select()
            .eq('worker_id', userId)
            .order('position');
        return (data as List<dynamic>)
            .map((row) => PortfolioItem.fromJson(row as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // Sin tabla: se devuelve el portafolio en memoria.
      }
    }
    return List<PortfolioItem>.unmodifiable(
      _mockPortfolios[userId] ?? const [],
    );
  }

  /// Agrega una foto al portafolio del trabajador.
  Future<PortfolioItem> addPortfolioItem({
    required String userId,
    required String imageUrl,
    String caption = '',
  }) async {
    final current = await loadPortfolio(userId);
    final item = PortfolioItem(
      id: _nextId('portfolio'),
      imageUrl: imageUrl,
      caption: caption,
      position: current.length,
    );

    if (_hasBackend) {
      try {
        final inserted = await SupabaseService.client!
            .from(portfolioTable)
            .insert({
              'worker_id': userId,
              'image_url': item.imageUrl,
              'caption': item.caption,
              'position': item.position,
            })
            .select()
            .single();
        return PortfolioItem.fromJson(inserted);
      } catch (_) {
        // Sin tabla: se conserva en memoria.
      }
    }

    _mockPortfolios.putIfAbsent(userId, () => []).add(item);
    return item;
  }

  /// Elimina una foto del portafolio y reordena las posiciones.
  Future<void> removePortfolioItem({
    required String userId,
    required String itemId,
  }) async {
    if (_hasBackend) {
      try {
        await SupabaseService.client!
            .from(portfolioTable)
            .delete()
            .eq('id', itemId)
            .eq('worker_id', userId);
      } catch (_) {
        // Sin tabla: se elimina de memoria.
      }
    }

    final items = _mockPortfolios[userId] ?? <PortfolioItem>[];
    items.removeWhere((item) => item.id == itemId);
    // Se reasignan las posiciones para mantener la galería ordenada.
    _mockPortfolios[userId] = [
      for (var index = 0; index < items.length; index++)
        items[index].copyWith(position: index),
    ];
  }

  // ------------------------------------------------------------------
  // DIRECCIONES GUARDADAS DEL CLIENTE
  // ------------------------------------------------------------------

  /// Carga las direcciones/zonas guardadas por el cliente.
  Future<List<SavedAddress>> loadAddresses(String userId) async {
    if (_hasBackend) {
      try {
        final data = await SupabaseService.client!
            .from(addressesTable)
            .select()
            .eq('client_id', userId)
            .order('is_primary', ascending: false);
        return (data as List<dynamic>)
            .map((row) => SavedAddress.fromJson(row as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // Sin tabla: se devuelven las direcciones en memoria.
      }
    }
    return List<SavedAddress>.unmodifiable(_mockAddresses[userId] ?? const []);
  }

  /// Guarda una nueva dirección del cliente.
  Future<SavedAddress> addAddress({
    required String userId,
    required SavedAddress address,
  }) async {
    final saved = address.copyWith(
      id: address.id.isEmpty ? _nextId('addr') : address.id,
    );

    if (_hasBackend) {
      try {
        final inserted = await SupabaseService.client!
            .from(addressesTable)
            .insert({
              'client_id': userId,
              'label': saved.label,
              'address': saved.address,
              'latitude': saved.latitude,
              'longitude': saved.longitude,
              'is_primary': saved.isPrimary,
            })
            .select()
            .single();
        return SavedAddress.fromJson(inserted);
      } catch (_) {
        // Sin tabla: se conserva en memoria.
      }
    }

    final list = _mockAddresses.putIfAbsent(userId, () => []);
    list.add(saved);
    return saved;
  }

  /// Elimina una dirección guardada.
  Future<void> removeAddress({
    required String userId,
    required String addressId,
  }) async {
    if (_hasBackend) {
      try {
        await SupabaseService.client!
            .from(addressesTable)
            .delete()
            .eq('id', addressId)
            .eq('client_id', userId);
      } catch (_) {
        // Sin tabla: se elimina de memoria.
      }
    }
    _mockAddresses[userId]?.removeWhere((item) => item.id == addressId);
  }

  /// Marca una dirección como principal (y desmarca las demás).
  Future<void> setPrimaryAddress({
    required String userId,
    required String addressId,
  }) async {
    if (_hasBackend) {
      try {
        await SupabaseService.client!
            .from(addressesTable)
            .update({'is_primary': false})
            .eq('client_id', userId);
        await SupabaseService.client!
            .from(addressesTable)
            .update({'is_primary': true})
            .eq('id', addressId)
            .eq('client_id', userId);
      } catch (_) {
        // Sin tabla: se actualiza en memoria.
      }
    }

    final list = _mockAddresses[userId] ?? <SavedAddress>[];
    for (var index = 0; index < list.length; index++) {
      list[index] = list[index].copyWith(
        isPrimary: list[index].id == addressId,
      );
    }
  }

  // ------------------------------------------------------------------
  // CONTRATISTAS FAVORITOS DEL CLIENTE
  // ------------------------------------------------------------------

  /// Carga los ids de los trabajadores favoritos del cliente.
  Future<List<String>> loadFavoriteWorkerIds(String userId) async {
    if (_hasBackend) {
      try {
        final data = await SupabaseService.client!
            .from(favoritesTable)
            .select('worker_id')
            .eq('client_id', userId);
        return (data as List<dynamic>)
            .map((row) => (row as Map<String, dynamic>)['worker_id'].toString())
            .toList();
      } catch (_) {
        // Sin tabla: se devuelven los favoritos en memoria.
      }
    }
    return List<String>.unmodifiable(_mockFavorites[userId] ?? const {});
  }

  /// Marca un trabajador como favorito del cliente.
  Future<void> addFavorite({
    required String userId,
    required String workerId,
  }) async {
    if (_hasBackend) {
      try {
        await SupabaseService.client!.from(favoritesTable).insert({
          'client_id': userId,
          'worker_id': workerId,
        });
      } catch (_) {
        // Sin tabla: se conserva en memoria.
      }
    }
    _mockFavorites.putIfAbsent(userId, () => {}).add(workerId);
  }

  /// Quita un trabajador de los favoritos del cliente.
  Future<void> removeFavorite({
    required String userId,
    required String workerId,
  }) async {
    if (_hasBackend) {
      try {
        await SupabaseService.client!
            .from(favoritesTable)
            .delete()
            .eq('client_id', userId)
            .eq('worker_id', workerId);
      } catch (_) {
        // Sin tabla: se elimina de memoria.
      }
    }
    _mockFavorites[userId]?.remove(workerId);
  }
}
