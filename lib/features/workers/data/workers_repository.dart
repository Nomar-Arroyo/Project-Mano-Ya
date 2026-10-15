import '../domain/worker.dart';

class WorkersRepository {
  Future<List<Worker>> list({
    String? category,
    String? city,
    bool onlyAvailable = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final data = _mockWorkers;
    return data.where((w) {
      if (onlyAvailable && w.status != WorkerStatus.available) return false;
      if (category != null && category.isNotEmpty && w.category != category) {
        return false;
      }
      if (city != null &&
          city.isNotEmpty &&
          !w.city.toLowerCase().contains(city.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> toggleAvailability(String workerId, bool available) async {
    await Future.delayed(const Duration(milliseconds: 150));
  }

  static final List<Worker> _mockWorkers = [
    Worker(
      id: '1',
      name: 'Carlos Ramírez',
      category: 'Construcción',
      subcategory: 'Albañil',
      city: 'Cali, Valle',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.8,
      reviewsCount: 42,
    ),
    Worker(
      id: '2',
      name: 'Ana Torres',
      category: 'Belleza',
      subcategory: 'Manicure',
      city: 'Palmira, Valle',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.9,
      reviewsCount: 28,
    ),
    Worker(
      id: '3',
      name: 'Luis Pérez',
      category: 'Mantenimiento',
      subcategory: 'Electricista',
      city: 'Cali, Valle',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.busy,
      rating: 4.7,
      reviewsCount: 15,
    ),
    Worker(
      id: '4',
      name: 'María López',
      category: 'Costura',
      subcategory: 'Modista',
      city: 'Cali, Valle',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.9,
      reviewsCount: 36,
    ),
    Worker(
      id: '5',
      name: 'Jorge Silva',
      category: 'Automotriz',
      subcategory: 'Mecánico',
      city: 'Palmira, Valle',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.available,
      rating: 4.6,
      reviewsCount: 21,
    ),
    Worker(
      id: '6',
      name: 'Diana Ruiz',
      category: 'Eventos',
      subcategory: 'Decoración',
      city: 'Cali, Valle',
      identityVerified: true,
      workGuaranteed: true,
      status: WorkerStatus.busy,
      rating: 4.8,
      reviewsCount: 19,
    ),
  ];
}
