import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/report_repository.dart';
import '../domain/report.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(),
);

/// Reportes enviados por el usuario actual.
final myReportsProvider = FutureProvider.autoDispose
    .family<List<Report>, String>((ref, reporterId) {
      return ref.read(reportRepositoryProvider).myReports(reporterId);
    });

/// Estado del envío de un reporte.
class ReportSubmissionState {
  final bool loading;
  final bool success;
  final String? message;

  const ReportSubmissionState({
    this.loading = false,
    this.success = false,
    this.message,
  });
}

/// Controlador del formulario de reporte.
class ReportController extends Notifier<ReportSubmissionState> {
  @override
  ReportSubmissionState build() => const ReportSubmissionState();

  ReportRepository get _repo => ref.read(reportRepositoryProvider);

  /// Envía el reporte y actualiza el estado para la interfaz.
  Future<bool> submit({
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
    state = const ReportSubmissionState(loading: true);
    final result = await _repo.submit(
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
    );
    state = ReportSubmissionState(
      loading: false,
      success: result.saved,
      message: result.message,
    );
    if (result.saved) {
      ref.invalidate(myReportsProvider(reporterId));
    }
    return state.success;
  }
}

final reportControllerProvider =
    NotifierProvider<ReportController, ReportSubmissionState>(
      ReportController.new,
    );
