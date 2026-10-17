/// Estados del ciclo de vida de un trabajo en Mano Ya.
enum JobStatus {
  /// El cliente envió la solicitud; el trabajador aún no acepta.
  requested,

  /// El trabajador aceptó y agendó el trabajo.
  accepted,

  /// El trabajo está en ejecución.
  inProgress,

  /// El trabajador finalizó el trabajo.
  completed,

  /// El trabajo fue cancelado por cualquiera de las partes.
  cancelled,
}

/// Extensión con etiquetas legibles para mostrar en la interfaz.
extension JobStatusLabel on JobStatus {
  String get label {
    switch (this) {
      case JobStatus.requested:
        return 'Solicitado';
      case JobStatus.accepted:
        return 'Aceptado';
      case JobStatus.inProgress:
        return 'En progreso';
      case JobStatus.completed:
        return 'Completado';
      case JobStatus.cancelled:
        return 'Cancelado';
    }
  }
}

/// Trabajo/servicio acordado entre un cliente y un trabajador.
///
/// Es la entidad que alimenta el panel principal: el trabajador ve su
/// "trabajo activo" y "sus trabajos", el cliente ve a su "trabajador
/// contratado" y su historial.
class Job {
  final String id;
  final String title;
  final String category;
  final String description;
  final String clientId;
  final String clientName;
  final String workerId;
  final String workerName;
  final String? workerPhone;
  final String address;
  final double price;
  final DateTime scheduledAt;
  final JobStatus status;

  /// Calificación que dejó el cliente al finalizar (null si aún no califica).
  final double? rating;
  final String? review;
  final DateTime createdAt;

  const Job({
    required this.id,
    required this.title,
    required this.category,
    required this.clientId,
    required this.clientName,
    required this.workerId,
    required this.workerName,
    required this.address,
    required this.price,
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
    this.description = '',
    this.workerPhone,
    this.rating,
    this.review,
  });

  /// El trabajo está en curso (aceptado o en progreso).
  bool get isActive =>
      status == JobStatus.accepted || status == JobStatus.inProgress;

  /// El trabajo ya terminó (completado o cancelado).
  bool get isFinished =>
      status == JobStatus.completed || status == JobStatus.cancelled;

  /// Pendiente de que el trabajador acepte la solicitud.
  bool get isRequested => status == JobStatus.requested;

  /// El cliente puede calificar cuando el trabajo terminó y no lo ha hecho.
  bool get canBeRated => status == JobStatus.completed && rating == null;

  /// Índice del paso actual dentro del flujo (para la barra de progreso).
  int get progressIndex {
    switch (status) {
      case JobStatus.requested:
        return 0;
      case JobStatus.accepted:
        return 1;
      case JobStatus.inProgress:
        return 2;
      case JobStatus.completed:
        return 3;
      case JobStatus.cancelled:
        return -1;
    }
  }

  Job copyWith({JobStatus? status, double? rating, String? review}) {
    return Job(
      id: id,
      title: title,
      category: category,
      description: description,
      clientId: clientId,
      clientName: clientName,
      workerId: workerId,
      workerName: workerName,
      workerPhone: workerPhone,
      address: address,
      price: price,
      scheduledAt: scheduledAt,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      createdAt: createdAt,
    );
  }
}
