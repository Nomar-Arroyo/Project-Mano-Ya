import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mano_ya/features/auth/presentation/pages/login_page.dart';
import 'package:mano_ya/features/auth/presentation/pages/register_page.dart';
import 'package:mano_ya/features/auth/presentation/pages/terms_and_conditions_page.dart';

void main() {
  testWidgets('login requires acceptance and can open the agreement', (
    tester,
  ) async {
    final router = _authRouter(register: false);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    final loginButton = find.widgetWithText(ElevatedButton, 'Iniciar sesión');
    expect(tester.widget<ElevatedButton>(loginButton).onPressed, isNull);
    final googleButton = find.widgetWithText(
      OutlinedButton,
      'Continuar con Google (demo)',
    );
    expect(tester.widget<OutlinedButton>(googleButton).onPressed, isNull);

    await tester.ensureVisible(find.text('Términos y condiciones'));
    await tester.tap(find.text('Términos y condiciones'));
    await tester.pumpAndSettle();
    expect(find.text('Términos y condiciones'), findsOneWidget);
    expect(
      find.textContaining('INSTRUMENTO JURÍDICO VINCULANTE'),
      findsOneWidget,
    );

    router.dispose();
  });

  testWidgets('registration button remains disabled until acceptance', (
    tester,
  ) async {
    final router = _authRouter(register: true);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    final registerButton = find.widgetWithText(ElevatedButton, 'Crear cuenta');
    expect(tester.widget<ElevatedButton>(registerButton).onPressed, isNull);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(registerButton).onPressed, isNotNull);

    router.dispose();
  });
}

GoRouter _authRouter({required bool register}) {
  return GoRouter(
    initialLocation: register ? '/register' : '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: '/terms',
        builder: (_, _) => const TermsAndConditionsPage(),
      ),
      GoRoute(path: '/forgot-password', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/verify-email', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/home', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/two-factor', builder: (_, _) => const Scaffold()),
    ],
  );
}
