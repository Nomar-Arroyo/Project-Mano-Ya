import '../../../core/services/supabase_service.dart';
import '../domain/report.dart';

typedef ReportSaver = Future<String?> Function(Map<String, dynamic> payload);

/// Resultado del envío de un reporte.
class ReportSubmission {
  /// Indica si el reporte quedó registrado en la base de datos.
  final bool saved;

  /// Identificador del reporte creado.
  final String? reportId;

  /// Mensaje para mostrar al usuario.
  final String message;

  const ReportSubmission({
    required this.saved,
    this.reportId,
    required this.message,
  });
}

/// Guarda reportes en Supabase.
///
/// La notificación al equipo de soporte la hace el trigger
/// `notify_new_report()` de la base de datos, en segundo plano. La app solo
/// confirma que la fila quedó guardada: así el secreto del webhook nunca sale
/// del servidor y un fallo de n8n no impide registrar el reporte.
class ReportRepository {
  static const String _table = 'reports';

  final ReportSaver? _reportSaver;

  ReportRepository({this._reportSaver});

  /// Guarda el reporte en la tabla `reports`.
  Future<ReportSubmission> submit({
    required String reporterId,
    required String reporterName,
    required String reporterEmail,
    String? targetUserId,
    required String targetName,
    String? jobId,
    required ReportCategory category,
    required String reason,
    required String details,
    ReportSeverity severity = ReportSeverity.normal,
  }) async {
    final report = Report(
      id: '',
      reporterId: reporterId,
      reporterName: reporterName,
      reporterEmail: reporterEmail,
      targetUserId: targetUserId,
      targetName: targetName,
      jobId: jobId,
      category: category,
      reason: reason,
      details: details,
      severity: severity,
      status: ReportStatus.abierto,
      createdAt: DateTime.now(),
    );

    final reportId = await _saveReport(report.toInsertMap());
    if (reportId != null) {
      return ReportSubmission(
        saved: true,
        reportId: reportId,
        message:
            'Reporte enviado. Nuestro equipo lo revisará lo antes posible.',
      );
    }
    return const ReportSubmission(
      saved: false,
      message: 'No pudimos guardar el reporte. Revisa tu conexión e inténtalo de nuevo.',
    );
  }

  /// Lista los reportes enviados por el usuario.
  Future<List<Report>> myReports(String reporterId) async {
    final client = SupabaseService.client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from(_table)
          .select()
          .eq('reporter_id', reporterId)
          .order('created_at', ascending: false)
          .limit(50);
      return rows.map((row) => Report.fromMap(row)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _saveReport(Map<String, dynamic> payload) async {
    if (_reportSaver != null) return _reportSaver(payload);
    final client = SupabaseService.client;
    if (client == null) return null;

    try {
      final response = await client
          .from(_table)
          .insert(payload)
          .select('id')
          .single();
      return response['id'] as String?;
    } catch (_) {
      return null;
    }
  }
}
