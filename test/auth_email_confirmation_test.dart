import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/features/auth/domain/auth_state.dart';

void main() {
  test('pending email confirmation does not authenticate the user', () {
    final state = AuthState.emailConfirmationPending('usuario@ejemplo.com');

    expect(state.isAuthenticated, isFalse);
    expect(state.successMessage, contains('usuario@ejemplo.com'));
    expect(state.successMessage, contains('código de verificación'));
  });
}
