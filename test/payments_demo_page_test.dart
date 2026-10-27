import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/core/services/email_service.dart';
import 'package:mano_ya/features/billing/data/payments_demo_repository.dart';
import 'package:mano_ya/features/billing/presentation/pages/payments_demo_list_page.dart';
import 'package:mano_ya/features/billing/presentation/pages/payments_demo_page.dart';

void main() {
  testWidgets('selecting a payment request opens its detail', (tester) async {
    final repository = PaymentsDemoRepository();
    final payment = repository.payments[1];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentsDemoRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: PaymentsDemoListPage()),
      ),
    );

    expect(find.text('Selecciona a quién pagar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(payment.concept),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining(payment.workerName), findsOneWidget);
    await tester.tap(find.text(payment.concept));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del pago'), findsOneWidget);
    expect(find.text(payment.workerPhone), findsOneWidget);
    expect(find.text(payment.workerDocument), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Realizar pago móvil (demo)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Realizar pago móvil (demo)'), findsOneWidget);
  });

  testWidgets('pays a pending request and registers reports for both parties', (
    tester,
  ) async {
    final repository = PaymentsDemoRepository();
    final outboxSizeBefore = EmailService.outbox.length;
    final payment = repository.payments.first;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentsDemoRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(home: PaymentsDemoPage(paymentId: payment.id)),
      ),
    );

    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Datos para pagar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Comisión de Mano Ya (15%)'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Comisión de Mano Ya (15%)'), findsOneWidget);
    expect(find.text('Bs. 52,50'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Realizar pago móvil (demo)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Realizar pago móvil (demo)'));
    await tester.pumpAndSettle();
    expect(find.text('Banco receptor'), findsOneWidget);
    expect(find.text(payment.workerPhone), findsAtLeastNWidgets(2));
    expect(find.text(payment.workerDocument), findsAtLeastNWidgets(2));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banesco').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simular pago móvil'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Marcar pago realizado'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Marcar pago realizado'), findsOneWidget);
    expect(find.textContaining('Pago móvil simulado'), findsOneWidget);
    await tester.tap(find.text('Marcar pago realizado'));
    await tester.pump();
    expect(repository.getById(payment.id)?.status.name, 'paid');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();

    expect(find.text('Pagado'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('DEMO-'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('DEMO-'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('bandeja simulada'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('bandeja simulada'), findsOneWidget);
    expect(repository.getById(payment.id)?.status.name, 'paid');

    final newReports = EmailService.outbox.skip(outboxSizeBefore).toList();
    expect(newReports, hasLength(2));
    expect(
      newReports.map((report) => report.to),
      containsAll([payment.clientEmail, payment.workerEmail]),
    );
  });
}
