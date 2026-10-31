import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mano_ya/core/constants/colors.dart';
import 'package:mano_ya/features/auth/presentation/pages/login_page.dart';
import 'package:mano_ya/features/auth/presentation/pages/register_page.dart';
import 'package:mano_ya/features/auth/presentation/pages/terms_and_conditions_page.dart';
import 'package:mano_ya/features/legal/presentation/pages/cookie_policy_page.dart';
import 'package:mano_ya/features/legal/presentation/widgets/cookie_notice.dart';

void main() {
  testWidgets('cookie notice is disabled outside the web surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CookieNotice(
          enabled: false,
          child: const Text('Aplicación'),
          onOpenPolicy: () {},
        ),
      ),
    );

    expect(find.text('Aplicación'), findsOneWidget);
    expect(find.text('Uso de cookies y almacenamiento'), findsNothing);
  });

  testWidgets('web cookie notice links to policy and saves a decision', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final router = _authRouter(register: false);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => CookieNotice(
            enabled: true,
            child: child ?? const SizedBox.shrink(),
            onOpenPolicy: () => router.push('/cookies'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uso de cookies y almacenamiento'), findsOneWidget);
    await tester.tap(find.text('Política de cookies'));
    await tester.pumpAndSettle();
    expect(find.byType(CookiePolicyPage), findsOneWidget);
    expect(find.text('1. Tecnologías esenciales'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(find.text('Uso de cookies y almacenamiento'), findsNothing);
    expect(find.text('Cookies'), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('cookie_consent_v2'), 'accepted');

    await tester.pumpWidget(
      MaterialApp(
        home: CookieNotice(
          key: const ValueKey('rejection-notice'),
          enabled: true,
          child: const Scaffold(),
          onOpenPolicy: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Uso de cookies y almacenamiento'), findsNothing);
    expect(find.text('Cookies'), findsNothing);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: CookieNotice(
          enabled: true,
          child: const Scaffold(),
          onOpenPolicy: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();
    expect(find.text('Uso de cookies y almacenamiento'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString('cookie_consent_v2'),
      'rejected',
    );

    router.dispose();
  });

  testWidgets('agreement remains readable with the dark app theme', (
    tester,
  ) async {
    const paragraph =
        'Los servicios convenidos a través de la plataforma Mano Ya '
        'corresponden exclusivamente a contratos de obra y arrendamiento de '
        'servicios de carácter eminentemente civil, regulados por los '
        'Artículos 1.629 y 1.630 del Código Civil venezolano.';
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const TermsAndConditionsPage(),
      ),
    );

    final paragraphFinder = find.text(paragraph);
    final paragraphWidget = tester.widget<Text>(paragraphFinder);
    expect(paragraphWidget.style?.color, ManoYaColors.textSecondary);

    final documentCard = tester.widget<DecoratedBox>(
      find
          .ancestor(of: paragraphFinder, matching: find.byType(DecoratedBox))
          .first,
    );
    expect(
      (documentCard.decoration as BoxDecoration).color,
      ManoYaColors.surface,
    );
  });

  testWidgets('login does not repeat the terms acceptance prompt', (
    tester,
  ) async {
    final router = _authRouter(register: false);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    final loginButton = find.widgetWithText(ElevatedButton, 'Iniciar sesión');
    expect(tester.widget<ElevatedButton>(loginButton).onPressed, isNotNull);
    final googleButton = find.widgetWithText(
      OutlinedButton,
      'Continuar con Google (demo)',
    );
    expect(tester.widget<OutlinedButton>(googleButton).onPressed, isNotNull);
    expect(find.byType(Checkbox), findsNothing);

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
      GoRoute(path: '/cookies', builder: (_, _) => const CookiePolicyPage()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/verify-email', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/home', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/two-factor', builder: (_, _) => const Scaffold()),
    ],
  );
}
