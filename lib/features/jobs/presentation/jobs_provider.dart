import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/jobs_repository.dart';
import '../domain/job.dart';

/// Repositorio único de trabajos (mantiene el estado en memoria).
final jobsRepositoryProvider = Provider<JobsRepository>(
  (ref) => JobsRepository(),
);

/// Contador que se incrementa tras cada mutación para refrescar las listas.
class JobsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final jobsRevisionProvider = NotifierProvider<JobsRevision, int>(
  JobsRevision.new,
);

/// Trabajos del trabajador actual (por su id de usuario).
final workerJobsProvider = FutureProvider.autoDispose.family<List<Job>, String>(
  (ref, workerId) {
    ref.watch(jobsRevisionProvider);
    return ref.read(jobsRepositoryProvider).listForWorker(workerId);
  },
);

/// Trabajos del cliente actual (por su id de usuario).
final clientJobsProvider = FutureProvider.autoDispose.family<List<Job>, String>(
  (ref, clientId) {
    ref.watch(jobsRevisionProvider);
    return ref.read(jobsRepositoryProvider).listForClient(clientId);
  },
);

/// Trabajo individual por id (pantalla de detalle).
final jobByIdProvider = FutureProvider.autoDispose.family<Job?, String>((
  ref,
  id,
) {
  ref.watch(jobsRevisionProvider);
  return ref.read(jobsRepositoryProvider).getById(id);
});

/// Acciones sobre los trabajos (avanzar estado, calificar).
class JobsController {
  JobsController(this._ref);

  final Ref _ref;

  JobsRepository get _repo => _ref.read(jobsRepositoryProvider);

  Future<void> setStatus(String id, JobStatus status) async {
    await _repo.updateStatus(id, status);
    _ref.read(jobsRevisionProvider.notifier).bump();
  }

  /// Avanza el trabajo al siguiente estado natural del flujo.
  Future<void> advance(Job job) async {
    switch (job.status) {
      case JobStatus.requested:
        await setStatus(job.id, JobStatus.accepted);
      case JobStatus.accepted:
        await setStatus(job.id, JobStatus.inProgress);
      case JobStatus.inProgress:
        await setStatus(job.id, JobStatus.completed);
      case JobStatus.completed:
      case JobStatus.cancelled:
        break;
    }
  }

  Future<void> rate(String id, {required double rating, String? review}) async {
    await _repo.rate(id, rating: rating, review: review);
    _ref.read(jobsRevisionProvider.notifier).bump();
  }
}

final jobsControllerProvider = Provider<JobsController>(
  (ref) => JobsController(ref),
);
