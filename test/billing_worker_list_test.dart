import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/features/auth/domain/auth_state.dart';
import 'package:mano_ya/features/auth/presentation/auth_provider.dart';
import 'package:mano_ya/features/billing/data/billing_repository.dart';
import 'package:mano_ya/features/billing/presentation/billing_provider.dart';
import 'package:mano_ya/features/billing/presentation/pages/charges_list_page.dart';
import 'package:mano_ya/features/shared/models/user_role.dart';

void main() {
  testWidgets('worker sees client payment statuses and received installments', (
    tester,
  ) async {
    final repository = BillingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAuthStateProvider.overrideWithValue(
            AuthState.authenticated(
              userId: 'worker-1',
              email: 'worker@example.com',
              displayName: 'Luis Pérez',
              role: UserRole.worker,
            ),
          ),
          billingRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ChargesListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selecciona a quién pagar'), findsNothing);
    expect(find.text('Trabajos en curso (2)'), findsOneWidget);
    expect(find.text('Clientes por pagar (1)'), findsOneWidget);
    expect(find.text('Pagos notificados (1)'), findsOneWidget);
    expect(find.text('Pagos recibidos (1)'), findsOneWidget);
    expect(find.textContaining('Abonos: 2 de 4 cuotas'), findsOneWidget);
    expect(find.textContaining('Cliente: Laura Gómez'), findsOneWidget);

    await tester.tap(find.text('Pagos recibidos (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Pintura y acabado de sala'), findsOneWidget);
    expect(find.textContaining('Cliente: Gabriela Torres'), findsOneWidget);
    expect(find.textContaining('Abonos: 2 de 4 cuotas'), findsNothing);
  });
}
