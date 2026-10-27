import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/features/billing/data/payments_demo_repository.dart';
import 'package:mano_ya/features/billing/domain/demo_payment.dart';

void main() {
  group('DemoPaymentSplit', () {
    test('allocates 15% to the platform and the remainder to the worker', () {
      final split = DemoPaymentSplit.calculate(10000);

      expect(split.totalMinor, 10000);
      expect(split.platformFeeMinor, 1500);
      expect(split.workerNetMinor, 8500);
      expect(split.platformFeeMinor + split.workerNetMinor, split.totalMinor);
    });

    test('rounds the commission to the nearest cent without losing value', () {
      final split = DemoPaymentSplit.calculate(101);

      expect(split.platformFeeMinor, 15);
      expect(split.workerNetMinor, 86);
      expect(split.platformFeeMinor + split.workerNetMinor, 101);
    });

    test('rejects zero or negative totals', () {
      expect(() => DemoPaymentSplit.calculate(0), throwsArgumentError);
      expect(() => DemoPaymentSplit.calculate(-1), throwsArgumentError);
    });
  });

  group('PaymentsDemoRepository', () {
    test('starts with a pending payment request and its payment details', () {
      final repository = PaymentsDemoRepository();
      final payment = repository.payments.first;

      expect(repository.payments, hasLength(3));
      expect(
        repository.payments.every(
          (item) => item.status == DemoPaymentStatus.pending,
        ),
        isTrue,
      );
      expect(payment.status, DemoPaymentStatus.pending);
      expect(payment.clientEmail, contains('@'));
      expect(payment.workerEmail, contains('@'));
      expect(payment.split.totalMinor, 35000);
      expect(payment.split.platformFeeMinor, 5250);
      expect(payment.split.workerNetMinor, 29750);
    });

    test('marks the request paid once and creates a demo reference', () {
      final repository = PaymentsDemoRepository();

      final initialPayment = repository.payments.first;
      expect(() => repository.markAsPaid(initialPayment.id), throwsStateError);
      final transfer = repository.completePaymentSimulation(
        initialPayment.id,
        bank: 'Banesco',
      );
      expect(transfer.simulationCompletedAt, isNotNull);
      expect(transfer.simulationBank, 'Banesco');
      expect(transfer.simulationReference, startsWith('DEMO-'));

      final payment = repository.markAsPaid(initialPayment.id);

      expect(payment.status, DemoPaymentStatus.paid);
      expect(payment.paidAt, isNotNull);
      expect(payment.paymentReference, transfer.simulationReference);
      expect(repository.getById(payment.id), payment);
      expect(() => repository.markAsPaid(payment.id), throwsStateError);
    });
  });
}
