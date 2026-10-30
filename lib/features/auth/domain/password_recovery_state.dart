/// Pasos del flujo de recuperación de contraseña.
enum PasswordRecoveryStep { email, code, password }

/// Estado del flujo de recuperación de contraseña.
///
/// Se mantiene aparte de `AuthState` porque este proceso ocurre antes de
/// iniciar sesión: así un error del código no aparece en la pantalla de login.
class PasswordRecoveryState {
  final PasswordRecoveryStep step;

  /// Correo al que se envió el código (vacío en el primer paso).
  final String email;
  final bool loading;
  final String? errorMessage;

  const PasswordRecoveryState({
    this.step = PasswordRecoveryStep.email,
    this.email = '',
    this.loading = false,
    this.errorMessage,
  });

  const PasswordRecoveryState.initial() : this();

  PasswordRecoveryState copyWith({
    PasswordRecoveryStep? step,
    String? email,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PasswordRecoveryState(
      step: step ?? this.step,
      email: email ?? this.email,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
