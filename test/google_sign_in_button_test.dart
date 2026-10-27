import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:mano_ya/features/shared/models/user_role.dart';

void main() {
  testWidgets('shows an explicit Google demo button without credentials', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(role: UserRole.client),
          ),
        ),
      ),
    );

    expect(find.text('Continuar con Google (demo)'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
