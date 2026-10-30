import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/features/auth/data/auth_repository.dart';
import 'package:mano_ya/features/auth/domain/password_recovery_state.dart';
import 'package:mano_ya/features/auth/presentation/auth_provider.dart';

/// Repositorio de prueba: registra las llamadas sin tocar Supabase.
class _FakeAuthRepository extends AuthRepository {
  bool failRequest = false;
  String? requestedEmail;
  String? verifiedEmail;
  String? verifiedCode;
  String? updatedPassword;
  bool cancelled = false;

  @override
  Future<void> requestPasswordReset(String email) async {
    if (failRequest) {
      throw const AuthException('Se enviaron demasiados correos.');
    }
    requestedEmail = email;
  }

  @override
  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    verifiedEmail = email;
    verifiedCode = code;
  }

  @override
  Future<void> updatePassword(String password) async {
    updatedPassword = password;
  }

  @override
  Future<void> cancelPasswordReset() async {
    cancelled = true;
  }
}

void main() {
  test('recorre correo, código y contraseña nueva', () async {
    final repo = _FakeAuthRepository();
    final container = ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    final notifier = container.read(passwordRecoveryProvider.notifier);

    expect(await notifier.requestCode('  ana@ejemplo.com '), isTrue);
    var state = container.read(passwordRecoveryProvider);
    expect(state.step, PasswordRecoveryStep.code);
    expect(state.email, 'ana@ejemplo.com');
    expect(repo.requestedEmail, 'ana@ejemplo.com');

    expect(await notifier.verifyCode('123456'), isTrue);
    state = container.read(passwordRecoveryProvider);
    expect(state.step, PasswordRecoveryStep.password);
    expect(repo.verifiedEmail, 'ana@ejemplo.com');
    expect(repo.verifiedCode, '123456');

    expect(await notifier.updatePassword('Nueva2026!'), isTrue);
    expect(repo.updatedPassword, 'Nueva2026!');
  });

  test('si el envío falla, muestra el error y no avanza', () async {
    final repo = _FakeAuthRepository()..failRequest = true;
    final container = ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    final notifier = container.read(passwordRecoveryProvider.notifier);

    expect(await notifier.requestCode('ana@ejemplo.com'), isFalse);
    final state = container.read(passwordRecoveryProvider);
    expect(state.step, PasswordRecoveryStep.email);
    expect(state.errorMessage, contains('demasiados correos'));
    expect(state.loading, isFalse);
  });

  test(
    'abandonar tras verificar el código cierra la sesión temporal',
    () async {
      final repo = _FakeAuthRepository();
      final container = ProviderContainer.test(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      final notifier = container.read(passwordRecoveryProvider.notifier);

      await notifier.requestCode('ana@ejemplo.com');
      await notifier.verifyCode('123456');
      await notifier.cancel();

      expect(repo.cancelled, isTrue);
      final state = container.read(passwordRecoveryProvider);
      expect(state.step, PasswordRecoveryStep.email);
      expect(state.email, isEmpty);
    },
  );
}
