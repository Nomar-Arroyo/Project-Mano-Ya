import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mano_ya/features/reports/data/report_repository.dart';
import 'package:mano_ya/features/reports/domain/report.dart';

void main() {
  group('ReportRepository y webhook de n8n', () {
    test(
      'envia la cabecera X-Webhook-Secret con el secreto configurado',
      () async {
        http.Request? captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response('{"ok":true}', 200);
        });

        final repository = ReportRepository(
          httpClient: client,
          webhookUrl: 'https://n8n.example.com/webhook/reportes',
          webhookSecret: 'secreto-de-prueba',
        );

        final result = await repository.submit(
          reporterId: 'user-1',
          reporterName: 'Ana Perez',
          reporterEmail: 'ana@correo.com',
          targetName: 'Carlos Ramirez',
          category: ReportCategory.otro,
          reason: 'No respeta el acuerdo',
          details: 'Llego tarde y cobro de mas.',
        );

        expect(captured, isNotNull);
        expect(captured!.headers['X-Webhook-Secret'], 'secreto-de-prueba');
        expect(captured!.headers['Content-Type'], contains('application/json'));
        expect(result.notified, isTrue);
      },
    );

    test('el cuerpo del webhook lleva los datos del reporte', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      });

      final repository = ReportRepository(
        httpClient: client,
        webhookUrl: 'https://n8n.example.com/webhook/reportes',
        webhookSecret: 'secreto-de-prueba',
      );

      await repository.submit(
        reporterId: 'user-1',
        reporterName: 'Ana Perez',
        reporterEmail: 'ana@correo.com',
        targetName: 'Carlos Ramirez',
        jobId: 'job-9',
        category: ReportCategory.calidad,
        reason: 'Mal trabajo',
        details: 'La lavadora quedo con fuga.',
      );

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['evento'], 'nuevo_reporte');
      expect(body['reporta'], 'Ana Perez');
      expect(body['reportado'], 'Carlos Ramirez');
      expect(body['servicio_id'], 'job-9');
      expect(body['categoria'], isNotEmpty);
    });

    test('no se envia nada si no hay webhook configurado', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });

      final repository = ReportRepository(httpClient: client);

      final result = await repository.submit(
        reporterId: 'user-1',
        reporterName: 'Ana Perez',
        reporterEmail: 'ana@correo.com',
        targetName: 'Carlos Ramirez',
        category: ReportCategory.otro,
        reason: 'Motivo',
        details: 'Detalle',
      );

      expect(called, isFalse);
      expect(result.notified, isFalse);
    });

    test('un error del webhook no rompe el flujo del reporte', () async {
      final client = MockClient((request) async => http.Response('error', 500));

      final repository = ReportRepository(
        httpClient: client,
        webhookUrl: 'https://n8n.example.com/webhook/reportes',
        webhookSecret: 'secreto-de-prueba',
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

      expect(result.notified, isFalse);
    });
  });
}
