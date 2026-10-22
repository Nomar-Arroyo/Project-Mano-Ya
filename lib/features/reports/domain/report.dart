/// Categorías de los reportes enviados desde la app.
enum ReportCategory {
  calidad('calidad', 'Calidad del servicio'),
  pago('pago', 'Problema de pago'),
  conducta('conducta', 'Conducta inappropriada'),
  noShow('no_show', 'No se presentó'),
  datos('datos', 'Datos incorrectos'),
  otro('otro', 'Otro motivo');

  const ReportCategory(this.value, this.label);

  /// Valor almacenado en la base de datos.
  final String value;

  /// Texto mostrado al usuario.
  final String label;

  static ReportCategory fromValue(String? value) {
    return ReportCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => ReportCategory.otro,
    );
  }
}

/// Severidad del reporte.
enum ReportSeverity {
  baja('baja', 'Baja'),
  normal('normal', 'Normal'),
  alta('alta', 'Alta');

  const ReportSeverity(this.value, this.label);

  final String value;
  final String label;

  static ReportSeverity fromValue(String? value) {
    return ReportSeverity.values.firstWhere(
      (severity) => severity.value == value,
      orElse: () => ReportSeverity.normal,
    );
  }
}

/// Estado en el que se encuentra el reporte.
enum ReportStatus {
  abierto('abierto', 'Abierto'),
  enRevision('en_revision', 'En revisión'),
  resuelto('resuelto', 'Resuelto'),
  cerrado('cerrado', 'Cerrado');

  const ReportStatus(this.value, this.label);

  final String value;
  final String label;

  static ReportStatus fromValue(String? value) {
    return ReportStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ReportStatus.abierto,
    );
  }
}

/// Reporte enviado por un usuario sobre un trabajador o un servicio.
class Report {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reporterEmail;
  final String? targetUserId;
  final String targetName;
  final String? jobId;
  final ReportCategory category;
  final String reason;
  final String details;
  final ReportSeverity severity;
  final ReportStatus status;
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reporterEmail,
    this.targetUserId,
    required this.targetName,
    this.jobId,
    required this.category,
    required this.reason,
    required this.details,
    required this.severity,
    required this.status,
    required this.createdAt,
  });

  /// Construye el reporte a partir de una fila de Supabase.
  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'] as String? ?? '',
      reporterId: map['reporter_id'] as String? ?? '',
      reporterName: map['reporter_name'] as String? ?? '',
      reporterEmail: map['reporter_email'] as String? ?? '',
      targetUserId: map['target_user_id'] as String?,
      targetName: map['target_name'] as String? ?? '',
      jobId: map['job_id'] as String?,
      category: ReportCategory.fromValue(map['category'] as String?),
      reason: map['reason'] as String? ?? '',
      details: map['details'] as String? ?? '',
      severity: ReportSeverity.fromValue(map['severity'] as String?),
      status: ReportStatus.fromValue(map['status'] as String?),
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Datos listos para insertar en la tabla `reports`.
  Map<String, dynamic> toInsertMap() {
    return {
      'reporter_id': reporterId.isEmpty ? null : reporterId,
      'reporter_name': reporterName,
      'reporter_email': reporterEmail,
      'target_user_id': targetUserId,
      'target_name': targetName,
      'job_id': jobId,
      'category': category.value,
      'reason': reason,
      'details': details,
      'severity': severity.value,
    };
  }
}
