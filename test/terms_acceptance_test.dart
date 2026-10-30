import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mano_ya/core/constants/colors.dart';
import 'package:mano_ya/features/auth/presentation/pages/login_page.dart';
import 'package:mano_ya/features/auth/presentation/pages/register_page.dart';
import 'package:mano_ya/features/auth/presentation/pages/terms_and_conditions_page.dart';

void main() {
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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    expect(find.text('Términos y condiciones'), findsOneWidget);
    expect(
      find.textContaining('INSTRUMENTO JURÍDICO VINCULANTE'),
      findsOneWidget,
    );
    expect(
      find.text('NATURALEZA CIVIL DEL VÍNCULO Y PRIMACÍA DE LA REALIDAD'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('CÓDIGO DE CONDUCTA Y RÉGIMEN SANCIONATORIO'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('CÓDIGO DE CONDUCTA Y RÉGIMEN SANCIONATORIO'),
      findsOneWidget,
    );
    expect(find.text('FUNDAMENTO LEGAL'), findsNWidgets(5));
    await tester.scrollUntilVisible(
      find.text('Arts. 1.167 y 1.630 del Código Civil'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('FUNDAMENTO LEGAL'), findsNWidgets(5));
    expect(find.text('Arts. 1.167 y 1.630 del Código Civil'), findsOneWidget);

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
