import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/features/billing/domain/charge.dart';

void main() {
  test('maps persisted payment statuses and installment fields', () {
    final charge = Charge.fromJson({
      'id': 'charge-id',
      'job_id': 'job-id',
      'concept': 'Reparación',
      'worker_name': 'Nomar Arroyo',
      'client_name': 'Ana Anselmi',
      'client_email': 'ana@example.com',
      'total': 1000,
      'bank_info': 'Pago móvil',
      'created_at': '2026-10-31T12:00:00Z',
      'status': 'client_notified',
      'paid_at': null,
      'receipt_path': null,
      'installments': [
        {
          'id': 'installment-id',
          'label': 'Cuota 1',
          'amount': 500,
          'due_date': '2026-10-31',
          'paid': false,
        },
      ],
    });

    expect(charge.jobId, 'job-id');
    expect(charge.status, ChargeStatus.clientNotified);
    expect(charge.databaseStatus, 'client_notified');
    expect(charge.installments.single.amount, 500);
    expect(charge.installments.single.paid, isFalse);
  });

  test('rejects unknown persisted payment statuses', () {
    expect(
      () => Charge.fromJson({
        'id': 'charge-id',
        'job_id': 'job-id',
        'concept': 'Reparación',
        'worker_name': 'Nomar Arroyo',
        'client_name': 'Ana Anselmi',
        'client_email': null,
        'total': 1000,
        'bank_info': 'Pago móvil',
        'created_at': '2026-10-31T12:00:00Z',
        'status': 'unknown',
        'paid_at': null,
        'receipt_path': null,
        'installments': [],
      }),
      throwsFormatException,
    );
  });
}
