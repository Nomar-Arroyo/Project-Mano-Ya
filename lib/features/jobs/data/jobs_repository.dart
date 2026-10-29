import '../../../core/services/supabase_service.dart';
import '../domain/job.dart';

/// Repositorio de trabajos (servicios).
///
/// Tiene dos implementaciones:
/// 1. **Supabase** (preferida): lee y escribe la tabla `jobs`, deja el
///    historial de estados en `job_events` y las calificaciones en `reviews`.
///    Los estados de la base de datos son 'requested', 'accepted',
///    'in_progress', 'completed' y 'cancelled'.
/// 2. **Mock** (respaldo): mantiene los datos en memoria durante la sesión
///    para que las mutaciones (avanzar estado, calificar) se reflejen de
///    inmediato en el panel.
///
/// Si una operación en Supabase falla (tabla inexistente, permisos o red) el
/// repositorio cae automáticamente en el modo mock para no romper la
/// experiencia del usuario.
class JobsRepository {
  /// Tabla con los trabajos (servicios) de los clientes y trabajadores.
  static const String jobsTable = 'jobs';

  /// Tabla con el historial de estados de cada trabajo.
  static const String jobEventsTable = 'job_events';

  /// Tabla con las reseñas de los trabajos completados.
  static const String reviewsTable = 'reviews';

  /// Tabla con la ficha pública del trabajador (para resolver su perfil).
  static const String workersTable = 'workers';

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
        address: 'Los Palos Grandes, Caracas',
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
        address: 'Las Mercedes, Caracas',
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
        address: 'Las Mercedes, Caracas',
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
        address: 'El Peñón, Maracay',
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
        workerPhone: '+58 414 333 4455',
        address: 'Mi casa · Los Palos Grandes',
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
        workerPhone: '+58 416 444 5566',
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
        workerPhone: '+58 424 555 6677',
        address: 'Mi casa · Los Palos Grandes',
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
        workerPhone: '+58 414 333 4455',
        address: 'Mi casa · Los Palos Grandes',
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
        workerPhone: '+58 412 222 3344',
        address: 'Mi casa · Los Palos Grandes',
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
        workerPhone: '+58 426 666 7788',
        address: 'Mi casa · Los Palos Grandes',
        price: 110000,
        scheduledAt: now.add(const Duration(days: 3)),
        status: JobStatus.requested,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ];
  }

  late final List<Job> _jobs;

  bool _isCurrentUser(String? userId) {
    final user = SupabaseService.client?.auth.currentUser;
    return user != null && user.id == userId;
  }

  bool get _hasAuthenticatedBackend =>
      SupabaseService.client?.auth.currentUser != null;

  /// Trabajos asignados al trabajador (activos, solicitudes e historial).
  Future<List<Job>> listForWorker(String workerId) async {
    if (_isCurrentUser(workerId)) {
      try {
        final rows = await SupabaseService.client!
            .from(jobsTable)
            .select()
            .eq('worker_id', workerId);
        final jobs = rows.map(_jobFromRow).toList();
        _sortByRecent(jobs);
        return jobs;
      } catch (_) {
        // Sin tabla o id no válido: se usan los datos en memoria.
      }
    }
    await Future.delayed(const Duration(milliseconds: 350));
    final result = _jobs.where((j) => j.workerId == workerId).toList();
    _sortByRecent(result);
    return result;
  }

  /// Trabajos solicitados por el cliente.
  Future<List<Job>> listForClient(String clientId) async {
    if (_isCurrentUser(clientId)) {
      try {
        final rows = await SupabaseService.client!
            .from(jobsTable)
            .select()
            .eq('client_id', clientId);
        final jobs = rows.map(_jobFromRow).toList();
        _sortByRecent(jobs);
        return jobs;
      } catch (_) {
        // Sin tabla o id no válido: se usan los datos en memoria.
      }
    }
    await Future.delayed(const Duration(milliseconds: 350));
    final result = _jobs.where((j) => j.clientId == clientId).toList();
    _sortByRecent(result);
    return result;
  }

  /// Obtiene un trabajo por id (pantalla de detalle).
  Future<Job?> getById(String id) async {
    if (_hasAuthenticatedBackend && _isRealId(id)) {
      try {
        final row = await SupabaseService.client!
            .from(jobsTable)
            .select()
            .eq('id', id)
            .maybeSingle();
        return row == null ? null : _jobFromRow(row);
      } catch (_) {
        // Sin tabla o id no válido: se busca en memoria.
      }
    }
    await Future.delayed(const Duration(milliseconds: 250));
    for (final j in _jobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  /// Actualiza el estado de un trabajo y deja el cambio en el historial.
  ///
  /// Además de la columna `status` se inserta una fila en `job_events` con
  /// el nuevo estado: así queda registrada la auditoría del trabajo.
  ///
  /// Cuando el trabajo viene de Supabase (id uuid) el error se propaga para
  /// que la interfaz avise que el cambio no se pudo guardar.
  Future<Job> updateStatus(String id, JobStatus status) async {
    if (_hasAuthenticatedBackend && _isRealId(id)) {
      final row = await SupabaseService.client!
          .from(jobsTable)
          .update({'status': _statusToDb(status)})
          .eq('id', id)
          .select()
          .single();
      final job = _jobFromRow(row);
      await _recordEvent(id, _statusToDb(status));
      return job;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    final index = _jobs.indexWhere((j) => j.id == id);
    if (index == -1) {
      throw StateError('Trabajo no encontrado: $id');
    }
    _jobs[index] = _jobs[index].copyWith(status: status);
    return _jobs[index];
  }

  /// Registra la calificación del cliente al trabajador.
  ///
  /// Actualiza la calificación y el comentario del trabajo y guarda la
  /// reseña en la tabla `reviews`.
  Future<Job> rate(String id, {required double rating, String? review}) async {
    if (_hasAuthenticatedBackend && _isRealId(id)) {
      final row = await SupabaseService.client!
          .from(jobsTable)
          .update({'rating': rating, 'review': review})
          .eq('id', id)
          .select()
          .single();
      final job = _jobFromRow(row);
      await _saveReview(job, rating, review);
      return job;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    final index = _jobs.indexWhere((j) => j.id == id);
    if (index == -1) {
      throw StateError('Trabajo no encontrado: $id');
    }
    _jobs[index] = _jobs[index].copyWith(rating: rating, review: review);
    return _jobs[index];
  }

  /// Crea una nueva solicitud de servicio.
  ///
  /// En Supabase se inserta el trabajo con estado 'requested' y el cliente
  /// es el usuario de la sesión activa (`client_id = auth.uid()`). Cuando no
  /// hay backend (o no hay sesión real) la solicitud se guarda en memoria.
  Future<Job> createRequest({
    required String title,
    required String category,
    required String description,
    required double price,
    required DateTime scheduledAt,
    required String address,
    String? workerId,
    String? workerName,
    String? workerPhone,
    String? clientId,
    String? clientName,
  }) async {
    final client = SupabaseService.client;
    final userId = client?.auth.currentUser?.id;

    if (client != null && userId != null) {
      final payload = <String, dynamic>{
        'title': title,
        'category': category,
        'description': description,
        'client_id': userId,
        'client_name': clientName ?? '',
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': _statusToDb(JobStatus.requested),
        'price': price,
        'address': address,
        if (workerName != null && workerName.isNotEmpty)
          'worker_name': workerName,
        if (workerPhone != null && workerPhone.isNotEmpty)
          'worker_phone': workerPhone,
      };

      // La tabla `jobs` referencia al usuario del trabajador, no a su ficha
      // pública: se resuelve el perfil asociado antes de asignarlo.
      final workerProfileId = await _resolveWorkerProfileId(workerId);
      if (workerProfileId != null) {
        payload['worker_id'] = workerProfileId;
      }

      // Si la inserción falla el error se propaga: la interfaz avisa que la
      // solicitud no se pudo guardar.
      final row = await client
          .from(jobsTable)
          .insert(payload)
          .select()
          .single();
      final job = _jobFromRow(row);
      await _recordEvent(job.id, _statusToDb(JobStatus.requested));
      return job;
    }

    return _createMockRequest(
      title: title,
      category: category,
      description: description,
      price: price,
      scheduledAt: scheduledAt,
      address: address,
      workerId: workerId,
      workerName: workerName,
      workerPhone: workerPhone,
      clientId: clientId,
      clientName: clientName,
    );
  }

  /// Guarda el cambio de estado en el historial `job_events`.
  Future<void> _recordEvent(String jobId, String status) async {
    try {
      await SupabaseService.client!.from(jobEventsTable).insert({
        'job_id': jobId,
        'status': status,
      });
    } catch (_) {
      // El historial es un extra: si no se puede escribir, el cambio de
      // estado ya quedó guardado en la tabla de trabajos.
    }
  }

  /// Guarda la reseña del trabajo en la tabla `reviews`.
  Future<void> _saveReview(Job job, double rating, String? review) async {
    if (job.workerId.isEmpty || job.clientId.isEmpty) return;
    try {
      await SupabaseService.client!.from(reviewsTable).insert({
        'job_id': job.id,
        'worker_id': job.workerId,
        'client_id': job.clientId,
        'rating': rating,
        'comment': review,
      });
    } catch (_) {
      // La reseña es un extra: el trabajo conserva su calificación.
    }
  }

  /// Resuelve el id de perfil del trabajador a partir de su ficha pública.
  ///
  /// La tabla `workers` guarda la ficha del catálogo (`id`) y el usuario
  /// asociado (`profile_id`); la tabla `jobs` referencia al usuario.
  Future<String?> _resolveWorkerProfileId(String? workerId) async {
    if (workerId == null || workerId.isEmpty) return null;
    try {
      final row = await SupabaseService.client!
          .from(workersTable)
          .select('profile_id')
          .eq('id', workerId)
          .maybeSingle();
      final profileId = row?['profile_id']?.toString();
      if (profileId == null || profileId.isEmpty) return null;
      return profileId;
    } catch (_) {
      return null;
    }
  }

  /// Crea la solicitud en memoria (modo mock).
  Job _createMockRequest({
    required String title,
    required String category,
    required String description,
    required double price,
    required DateTime scheduledAt,
    required String address,
    String? workerId,
    String? workerName,
    String? workerPhone,
    String? clientId,
    String? clientName,
  }) {
    final now = DateTime.now();
    final job = Job(
      id: 'j-${now.millisecondsSinceEpoch}',
      title: title,
      category: category,
      description: description,
      clientId: clientId ?? 'mock_user',
      clientName: clientName ?? 'Tú',
      workerId: workerId ?? '',
      workerName: workerName ?? '',
      workerPhone: workerPhone,
      address: address,
      price: price,
      scheduledAt: scheduledAt,
      status: JobStatus.requested,
      createdAt: now,
    );
    _jobs.add(job);
    return job;
  }

  /// Convierte una fila de `jobs` en el modelo [Job].
  Job _jobFromRow(Map<String, dynamic> row) {
    return Job(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      category: row['category']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      clientId: row['client_id']?.toString() ?? '',
      clientName: row['client_name']?.toString() ?? '',
      workerId: row['worker_id']?.toString() ?? '',
      workerName: row['worker_name']?.toString() ?? '',
      workerPhone: row['worker_phone']?.toString(),
      address: row['address']?.toString() ?? '',
      price: (row['price'] as num?)?.toDouble() ?? 0,
      scheduledAt:
          DateTime.tryParse(row['scheduled_at']?.toString() ?? '') ??
          DateTime.now(),
      status: _statusFromDb(row['status']?.toString()),
      rating: (row['rating'] as num?)?.toDouble(),
      review: row['review']?.toString(),
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// Indica si el identificador corresponde a un registro de Supabase.
  ///
  /// Los datos en memoria del modo mock usan identificadores simples
  /// ('j1', 'mock_user') que nunca existen en la base de datos.
  bool _isRealId(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  /// Traduce el estado de la app al valor guardado en la base de datos.
  String _statusToDb(JobStatus status) {
    switch (status) {
      case JobStatus.requested:
        return 'requested';
      case JobStatus.accepted:
        return 'accepted';
      case JobStatus.inProgress:
        return 'in_progress';
      case JobStatus.completed:
        return 'completed';
      case JobStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Traduce el valor de la base de datos al estado de la app.
  JobStatus _statusFromDb(String? value) {
    switch (value) {
      case 'accepted':
        return JobStatus.accepted;
      case 'in_progress':
        return JobStatus.inProgress;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      default:
        return JobStatus.requested;
    }
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
