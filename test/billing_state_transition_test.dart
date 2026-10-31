import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/features/billing/data/billing_repository.dart';
import 'package:mano_ya/features/billing/domain/charge.dart';

void main() {
  test('worker cannot confirm a payment before client notification', () async {
    final repository = BillingRepository();

    await expectLater(
      repository.confirmPayment('demo0002'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'El cliente aún no ha reportado el pago.',
        ),
      ),
    );
  });

  test(
    'confirming a reported payment advances one installment at a time',
    () async {
      final repository = BillingRepository();

      final first = await repository.confirmPayment('demo0001');
      expect(first.status, ChargeStatus.pending);
      expect(first.paidAmount, 900);
      expect(first.pendingAmount, 300);
      expect(first.installments.where((item) => item.paid), hasLength(3));

      await expectLater(
        repository.confirmPayment('demo0001'),
        throwsA(isA<StateError>()),
      );

      await repository.notifyPayment('demo0001');
      final finalPayment = await repository.confirmPayment('demo0001');
      expect(finalPayment.status, ChargeStatus.paid);
      expect(finalPayment.paidAmount, finalPayment.total);
      expect(finalPayment.paidAt, isNotNull);
    },
  );

  test('a new demo charge stays linked to its selected job', () async {
    final repository = BillingRepository();
    final jobs = await repository.listBillableJobs();
    final charge = await repository.create(
      jobId: jobs.single.id,
      concept: 'Anticipo de obra',
      total: 1000.01,
      bankInfo: 'Pago móvil',
      installmentCount: 2,
    );

    expect(charge.jobId, jobs.single.id);
    expect(charge.clientName, jobs.single.clientName);
    expect(
      charge.installments.map((item) => item.amount).reduce((a, b) => a + b),
      1000.01,
    );
    expect((await repository.getById(charge.id))?.id, charge.id);
  });
}
