import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/report.dart';

/// Resultado del envío de un reporte.
class ReportSubmission {
  /// Indica si el reporte quedó registrado en la base de datos.
  final bool saved;

  /// Indica si el webhook de n8n recibió la notificación.
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

/// Repositorio de reportes.
///
/// El reporte siempre se guarda en la tabla `reports` de Supabase. Si hay un
/// webhook de n8n configurado, ademas se envía la notificación para que el
/// equipo de soporte reciba el aviso por correo y Slack.
class ReportRepository {
  static const String _table = 'reports';

  /// Guarda un reporte y notifica a n8n.
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

    final client = SupabaseService.client;
    String? reportId;
    var saved = false;

    if (client != null) {
      try {
        final response = await client
            .from(_table)
            .insert(report.toInsertMap())
            .select('id')
            .single();
        reportId = response['id'] as String?;
        saved = true;
      } catch (_) {
        saved = false;
      }
    }

    final notified = await _notifyWebhook(report, reportId);

    if (saved && notified) {
      return const ReportSubmission(
        saved: true,
        notified: true,
        message:
            'Reporte enviado. Nuestro equipo lo revisará lo antes posible.',
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
    return ReportSubmission(
      saved: false,
      notified: notified,
      reportId: reportId,
      message: notified
          ? 'Reporte enviado. Guardaremos la evidencia al recuperar la conexión.'
          : 'No pudimos enviar el reporte. Revisa tu conexión e inténtalo de nuevo.',
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

  /// Envía la notificación al webhook de n8n.
  Future<bool> _notifyWebhook(Report report, String? reportId) async {
    if (!AppConfig.hasReportWebhook) return false;
    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.n8nWebhookUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'evento': 'nuevo_reporte',
              'id': reportId ?? report.id,
              'categoria': report.category.value,
              'categoria_label': report.category.label,
              'severidad': report.severity.value,
              'motivo': report.reason,
              'detalle': report.details,
              'reporta': report.reporterName,
              'reporta_id': report.reporterId,
              'correo': report.reporterEmail,
              'reportado': report.targetName,
              'reportado_id': report.targetUserId,
              'servicio_id': report.jobId,
              'creado': report.createdAt.toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
