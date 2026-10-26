import '../../../core/services/supabase_service.dart';
import '../domain/report.dart';

typedef ReportSaver = Future<String?> Function(Map<String, dynamic> payload);
typedef ReportNotifier = Future<bool> Function(String reportId);

/// Resultado del envío de un reporte.
class ReportSubmission {
  /// Indica si el reporte quedó registrado en la base de datos.
  final bool saved;

  /// Indica si la notificación al servicio de soporte se completó.
  final bool notified;

  /// Identificador del reporte creado.
  final String? reportId;

  /// Mensaje para mostrar al usuario.
  final String message;

  const ReportSubmission({
    required this.saved,
    required this.notified,
    this.reportId,
    required this.message,
  });
}

/// Guarda reportes en Supabase y notifica mediante una Edge Function
/// autenticada. Ningún secreto de n8n viaja en la aplicación.
class ReportRepository {
  static const String _table = 'reports';

  final ReportSaver? _reportSaver;
  final ReportNotifier? _reportNotifier;

  ReportRepository({
    ReportSaver? reportSaver,
    ReportNotifier? reportNotifier,
  }) : _reportSaver = reportSaver,
       _reportNotifier = reportNotifier;

  /// Guarda un reporte y notifica a soporte cuando existe una fila persistida.
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
    final saved = reportId != null;
    final notified = saved ? await _notifySavedReport(reportId) : false;

    if (saved && notified) {
      return ReportSubmission(
        saved: true,
        notified: true,
        reportId: reportId,
        message: 'Reporte enviado. Nuestro equipo lo revisará lo antes posible.',
      );
    }
    if (saved) {
      return ReportSubmission(
        saved: true,
        notified: false,
        reportId: reportId,
        message: 'Reporte registrado. Te responderemos por correo.',
      );
    }
    return const ReportSubmission(
      saved: false,
      notified: false,
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

  Future<bool> _notifySavedReport(String reportId) async {
    if (_reportNotifier != null) return _reportNotifier(reportId);
    final client = SupabaseService.client;
    if (client == null) return false;

    try {
      final response = await client.functions.invoke(
        'notify-report',
        body: {'id': reportId},
      );
      final data = response.data;
      return response.status == 200 &&
          data is Map &&
          data['ok'] == true &&
          (data['enviado'] == true || data['encolado'] == true);
    } catch (_) {
      return false;
    }
  }
}
