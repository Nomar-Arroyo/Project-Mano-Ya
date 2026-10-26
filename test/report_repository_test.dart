import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/features/reports/data/report_repository.dart';
import 'package:mano_ya/features/reports/domain/report.dart';

void main() {
  group('ReportRepository', () {
    test('notifica solo el identificador del reporte persistido', () async {
      const reportId = '8c5c2a80-8206-4fac-9293-01d98df0a8cc';
      Map<String, dynamic>? savedPayload;
      String? notifiedReportId;
      final repository = ReportRepository(
        reportSaver: (payload) async {
          savedPayload = payload;
          return reportId;
        },
        reportNotifier: (id) async {
          notifiedReportId = id;
          return true;
        },
      );

      final result = await repository.submit(
        reporterId: 'user-1',
        reporterName: 'Ana Perez',
        reporterEmail: 'ana@correo.com',
        targetName: 'Carlos Ramirez',
        category: ReportCategory.calidad,
        reason: 'Mal trabajo',
        details: 'La lavadora quedo con fuga.',
      );

      expect(result.saved, isTrue);
      expect(result.notified, isTrue);
      expect(result.reportId, reportId);
      expect(notifiedReportId, reportId);
      expect(savedPayload?['reporter_name'], 'Ana Perez');
      expect(savedPayload?['category'], 'calidad');
      expect(savedPayload?.containsKey('id'), isFalse);
    });

    test('mantiene el reporte si falla la notificación', () async {
      final repository = ReportRepository(
        reportSaver: (_) async => '8c5c2a80-8206-4fac-9293-01d98df0a8cc',
        reportNotifier: (_) async => false,
      );

      final result = await repository.submit(
        reporterId: 'user-1',
        reporterName: 'Ana Perez',
        reporterEmail: 'ana@correo.com',
        targetName: 'Carlos Ramirez',
        category: ReportCategory.otro,
        reason: 'Motivo',
        details: 'Detalle',
      );

      expect(result.saved, isTrue);
      expect(result.notified, isFalse);
      expect(result.message, contains('Reporte registrado'));
    });

    test('no intenta notificar si no se guardó el reporte', () async {
      var notificationAttempted = false;
      final repository = ReportRepository(
        reportSaver: (_) async => null,
        reportNotifier: (_) async {
          notificationAttempted = true;
          return true;
        },
      );

      final result = await repository.submit(
        reporterId: 'user-1',
        reporterName: 'Ana Perez',
        reporterEmail: 'ana@correo.com',
        targetName: 'Carlos Ramirez',
        category: ReportCategory.otro,
        reason: 'Motivo',
        details: 'Detalle',
      );

      expect(result.saved, isFalse);
      expect(result.notified, isFalse);
      expect(notificationAttempted, isFalse);
    });
  });
}
