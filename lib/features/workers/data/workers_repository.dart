import '../../../core/services/maps_service.dart';
import '../domain/worker.dart';

/// Repositorio de trabajadores (datos mock hasta integrar Supabase).
class WorkersRepository {
  /// Lista trabajadores aplicando filtros por oficio, ciudad y disponibilidad.
  /// Si se envían coordenadas (`originLat`/`originLng`) los ordena por cercanía.
  Future<List<Worker>> list({
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

  /// Obtiene un trabajador por su id (para la pantalla de detalle).
  Future<Worker?> getById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    for (final w in _workers) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Compara la ciudad del trabajador con el texto del filtro. El filtro
  /// puede venir como "Cali, Valle del Cauca, Colombia" y el trabajador
  /// como "Cali, Valle del Cauca"; comparamos por el primer segmento.
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
      city: 'Cali, Valle del Cauca',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.8,
      reviewsCount: 42,
      phone: '+57 300 111 2233',
      bio:
          'Maestro de obra con 15 años de experiencia en mampostería, '
          'pañetes y acabados. Trabajos garantizados y puntuales.',
      latitude: 3.4516,
      longitude: -76.5320,
    ),
    Worker(
      id: '2',
      name: 'Ana Torres',
      category: 'Belleza',
      subcategory: 'Manicure',
      city: 'Palmira, Valle del Cauca',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.9,
      reviewsCount: 28,
      phone: '+57 300 222 3344',
      bio:
          'Especialista en uñas acrílicas, semipermanentes y diseños '
          'personalizados. Atención a domicilio.',
      latitude: 3.5394,
      longitude: -76.3036,
    ),
    Worker(
      id: '3',
      name: 'Luis Pérez',
      category: 'Mantenimiento',
      subcategory: 'Electricista',
      city: 'Cali, Valle del Cauca',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.busy,
      rating: 4.7,
      reviewsCount: 15,
      phone: '+57 300 333 4455',
      bio:
          'Instalaciones eléctricas residenciales, tableros y '
          'certificados RETIE.',
      latitude: 3.4370,
      longitude: -76.5225,
    ),
    Worker(
      id: '4',
      name: 'María López',
      category: 'Costura',
      subcategory: 'Modista',
      city: 'Cali, Valle del Cauca',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.9,
      reviewsCount: 36,
      phone: '+57 300 444 5566',
      bio:
          'Confección y arreglo de prendas, diseños a medida y servicios '
          'de modistería rápida.',
      latitude: 3.4370,
      longitude: -76.5225,
    ),
    Worker(
      id: '5',
      name: 'Jorge Silva',
      category: 'Automotriz',
      subcategory: 'Mecánico',
      city: 'Palmira, Valle del Cauca',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.6,
      reviewsCount: 21,
      phone: '+57 300 555 6677',
      bio:
          'Mecánica general, revisión de frenos, suspensión y '
          'mantenimiento preventivo a domicilio.',
      latitude: 3.5394,
      longitude: -76.3036,
    ),
    Worker(
      id: '6',
      name: 'Diana Ruiz',
      category: 'Eventos',
      subcategory: 'Decoración',
      city: 'Cali, Valle del Cauca',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.busy,
      rating: 4.8,
      reviewsCount: 19,
      phone: '+57 300 666 7788',
      bio:
          'Decoración de eventos, montajes temáticos, globos y '
          'ambientación de fiestas.',
      latitude: 3.4516,
      longitude: -76.5320,
    ),
  ];
}
