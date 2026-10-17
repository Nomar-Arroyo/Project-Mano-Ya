import '../domain/job.dart';

/// Repositorio de trabajos (datos mock hasta integrar Supabase).
///
/// Mantiene el estado en memoria para que las mutaciones (avanzar estado,
/// calificar) se reflejen de inmediato en el panel.
class JobsRepository {
  JobsRepository() {
    final now = DateTime.now();
    _jobs = [
      // --- Trabajos donde el usuario actual es el TRABAJADOR ---
      Job(
        id: 'j1',
        title: 'Instalación eléctrica de cocina',
        category: 'Mantenimiento',
        description:
            'Instalar 4 tomas y una línea dedicada para la estufa. '
            'Materiales incluidos por el cliente.',
        clientId: 'c-ana',
        clientName: 'Ana María Gutiérrez',
        workerId: 'mock_user',
        workerName: 'Mi cuenta',
        address: 'Barrio Granada, Cali',
        price: 320000,
        scheduledAt: now.add(const Duration(days: 1, hours: 3)),
        status: JobStatus.inProgress,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      Job(
        id: 'j2',
        title: 'Reparación de fuga en baño',
        category: 'Mantenimiento',
        description: 'Cambio de sifón y sellado de tubería.',
        clientId: 'c-carlos',
        clientName: 'Carlos Ramírez',
        workerId: 'mock_user',
        workerName: 'Mi cuenta',
        address: 'Barrio San Fernando, Cali',
        price: 180000,
        scheduledAt: now.subtract(const Duration(days: 6)),
        status: JobStatus.completed,
        rating: 5,
        review: 'Muy puntual y dejó todo limpio. ¡Recomendado!',
        createdAt: now.subtract(const Duration(days: 12)),
      ),
      Job(
        id: 'j2b',
        title: 'Reparación de grifería',
        category: 'Mantenimiento',
        description: 'Cambio de mezclador en baño principal.',
        clientId: 'c-mario',
        clientName: 'Mario Salcedo',
        address: 'Barrio San Fernando, Cali',
        workerId: 'mock_user',
        workerName: 'Tú',
        price: 95000,
        scheduledAt: now.subtract(const Duration(days: 25)),
        status: JobStatus.completed,
        rating: 4.5,
        review: 'Buen trabajo, aunque tardó un poco.',
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      Job(
        id: 'j3',
        title: 'Pintura de sala y comedor',
        category: 'Construcción',
        description: 'Pintura de interiores, paredes de 3 x 4 m aprox.',
        clientId: 'c-lucia',
        clientName: 'Lucía Gómez',
        address: 'Barrio El Peñón, Cali',
        workerId: 'mock_user',
        workerName: 'Tú',
        price: 450000,
        scheduledAt: now.add(const Duration(days: 5)),
        status: JobStatus.requested,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),

      // --- Trabajos donde el usuario actual es el CLIENTE ---
      Job(
        id: 'j4',
        title: 'Arreglo de lavadora',
        category: 'Mantenimiento',
        description: 'No centrifuga y hace ruido en el tambor.',
        clientId: 'mock_user',
        clientName: 'Tú',
        workerId: '3',
        workerName: 'Luis Pérez',
        workerPhone: '+57 300 333 4455',
        address: 'Mi casa · Barrio Granada',
        price: 150000,
        scheduledAt: now.add(const Duration(days: 1, hours: 3)),
        status: JobStatus.accepted,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Job(
        id: 'j5',
        title: 'Modistería: arreglo de vestido',
        category: 'Costura',
        description: 'Ajuste de ruedo y ajuste de cintura.',
        clientId: 'mock_user',
        clientName: 'Tú',
        workerId: '4',
        workerName: 'María López',
        workerPhone: '+57 300 444 5566',
        address: 'Recogido en casa',
        price: 60000,
        scheduledAt: now.subtract(const Duration(days: 8)),
        status: JobStatus.completed,
        rating: 5,
        review: 'Quedó perfecto, muy profesional.',
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      Job(
        id: 'j5b',
        title: 'Mantenimiento de aire acondicionado',
        category: 'Mantenimiento',
        description: 'Limpieza y recarga de gas de split 12.000 BTU.',
        clientId: 'mock_user',
        clientName: 'Tú',
        workerId: '6',
        workerName: 'Jorge Silva',
        workerPhone: '+57 300 555 6677',
        address: 'Mi casa · Barrio Granada',
        price: 220000,
        scheduledAt: now.subtract(const Duration(days: 10)),
        status: JobStatus.completed,
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      Job(
        id: 'j5c',
        title: 'Instalación de tomacorrientes',
        category: 'Mantenimiento',
        description: 'Reemplazo de 3 tomas en el estudio.',
        clientId: 'mock_user',
        clientName: 'Tú',
        workerId: '3',
        workerName: 'Luis Pérez',
        workerPhone: '+57 300 333 4455',
        address: 'Mi casa · Barrio Granada',
        price: 130000,
        scheduledAt: now.subtract(const Duration(days: 40)),
        status: JobStatus.completed,
        rating: 5,
        review: 'Rápido y ordenado.',
        createdAt: now.subtract(const Duration(days: 45)),
      ),
      Job(
        id: 'j6',
        title: 'Manicure a domicilio',
        category: 'Belleza',
        description: 'Uñas acrílicas con diseño.',
        clientId: 'mock_user',
        clientName: 'Tú',
        workerId: '2',
        workerName: 'Ana Torres',
        workerPhone: '+57 300 222 3344',
        address: 'Mi casa · Barrio Granada',
        price: 80000,
        scheduledAt: now.subtract(const Duration(days: 2)),
        status: JobStatus.completed,
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      Job(
        id: 'j7',
        title: 'Mantenimiento de jardín',
        category: 'Eventos',
        description: 'Poda y limpieza general del jardín trasero.',
        clientId: 'mock_user',
        clientName: 'Tú',
        workerId: '6',
        workerName: 'Diana Ruiz',
        workerPhone: '+57 300 666 7788',
        address: 'Mi casa · Barrio Granada',
        price: 110000,
        scheduledAt: now.add(const Duration(days: 3)),
        status: JobStatus.requested,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ];
  }

  late final List<Job> _jobs;

  /// Trabajos asignados al trabajador (activos, solicitudes e historial).
  Future<List<Job>> listForWorker(String workerId) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final result = _jobs.where((j) => j.workerId == workerId).toList();
    _sortByRecent(result);
    return result;
  }

  /// Trabajos solicitados por el cliente.
  Future<List<Job>> listForClient(String clientId) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final result = _jobs.where((j) => j.clientId == clientId).toList();
    _sortByRecent(result);
    return result;
  }

  /// Obtiene un trabajo por id (pantalla de detalle).
  Future<Job?> getById(String id) async {
    await Future.delayed(const Duration(milliseconds: 250));
    for (final j in _jobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  /// Actualiza el estado de un trabajo.
  Future<Job> updateStatus(String id, JobStatus status) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _jobs.indexWhere((j) => j.id == id);
    if (index == -1) {
      throw StateError('Trabajo no encontrado: $id');
    }
    _jobs[index] = _jobs[index].copyWith(status: status);
    return _jobs[index];
  }

  /// Registra la calificación del cliente al trabajador.
  Future<Job> rate(String id, {required double rating, String? review}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _jobs.indexWhere((j) => j.id == id);
    if (index == -1) {
      throw StateError('Trabajo no encontrado: $id');
    }
    _jobs[index] = _jobs[index].copyWith(rating: rating, review: review);
    return _jobs[index];
  }

  /// Ordena dejando primero los activos/solicitudes y luego por fecha
  /// programada descendente.
  void _sortByRecent(List<Job> jobs) {
    int weight(Job j) {
      if (j.isActive) return 0;
      if (j.isRequested) return 1;
      return 2;
    }

    jobs.sort((a, b) {
      final byWeight = weight(a).compareTo(weight(b));
      if (byWeight != 0) return byWeight;
      return b.scheduledAt.compareTo(a.scheduledAt);
    });
  }
}
