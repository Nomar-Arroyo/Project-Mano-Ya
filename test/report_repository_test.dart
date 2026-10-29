import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/features/reports/data/report_repository.dart';
import 'package:mano_ya/features/reports/domain/report.dart';

void main() {
  group('ReportRepository', () {
    test('guarda el reporte y devuelve el identificador', () async {
      const reportId = '8c5c2a80-8206-4fac-9293-01d98df0a8cc';
      Map<String, dynamic>? savedPayload;
      final repository = ReportRepository(
        reportSaver: (payload) async {
          savedPayload = payload;
          return reportId;
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
      expect(result.reportId, reportId);
      expect(result.message, contains('equipo'));
      expect(savedPayload?['reporter_name'], 'Ana Perez');
      expect(savedPayload?['category'], 'calidad');
      expect(savedPayload?.containsKey('id'), isFalse);
    });

    test('informa el fallo cuando el reporte no se guarda', () async {
      final repository = ReportRepository(reportSaver: (_) async => null);

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
      expect(result.reportId, isNull);
      expect(result.message, contains('No pudimos guardar el reporte'));
    });

    test(
      'no depende de n8n: un reporte guardado siempre es un envío exitoso',
      () async {
        // El repositorio solo tiene una dependencia inyectable (el guardado).
        // La notificación la resuelve el trigger notify_new_report().
        final repository = ReportRepository(
          reportSaver: (_) async => '8c5c2a80-8206-4fac-9293-01d98df0a8cc',
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
        expect(result.reportId, isNotNull);
      },
    );
  });
}
