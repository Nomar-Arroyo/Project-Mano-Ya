import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';
import '../../shared/models/user_role.dart';
import '../../workers/data/worker_registration_service.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';
import '../domain/mfa_enrollment.dart';
import '../domain/password_recovery_state.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

// Estado inicial restaurado desde preferencias antes de levantar la app.
final initialAuthStateProvider = Provider<AuthState>(
  (ref) => const AuthState.unauthenticated(),
);

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() => ref.watch(initialAuthStateProvider);

  // Guarda la sesión actual en preferencias para sobrevivir reinicios.
  Future<void> _persist() async {
    if (state.isAuthenticated) {
      await StorageService.saveSessionMap(state.toJson());
    }
  }

  Future<void> loginEmail(
    String email,
    String password, {
    required UserRole role,
  }) async {
    state = const AuthState.loading();
    try {
      state = await repo.loginEmailPassword(email, password, role: role);
      await _persist();
    } on AuthException catch (e) {
      state = AuthState.failure(e.message);
    } catch (_) {
      state = const AuthState.failure(
        'Ocurrió un error inesperado. Intenta de nuevo.',
      );
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    required bool acceptedTerms,
    String? phone,
    String? city,
    String? category,
    String? subcategory,
    String? bio,
    double? latitude,
    double? longitude,
  }) async {
    state = const AuthState.loading();
    try {
      state = await repo.register(
        name: name,
        email: email,
        password: password,
        role: role,
        acceptedTerms: acceptedTerms,
        phone: phone,
        city: city,
        category: category,
        subcategory: subcategory,
        bio: bio,
        latitude: latitude,
        longitude: longitude,
      );
      await _persist();
      // La ficha del trabajador se crea en el catálogo de oficios.
      if (state.isAuthenticated && role == UserRole.worker) {
        await WorkerRegistrationService.registerAfterSignUp(
          userId: state.userId ?? '',
          name: name,
          phone: phone,
          city: city,
          category: category,
          subcategory: subcategory,
          bio: bio,
          latitude: latitude,
          longitude: longitude,
        );
      }
    } on AuthException catch (e) {
      state = AuthState.failure(e.message);
    } catch (_) {
      state = const AuthState.failure(
        'No se pudo crear la cuenta. Intenta de nuevo.',
      );
    }
  }

  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    state = const AuthState.loading();
    try {
      state = await repo.verifyEmailCode(email: email, code: code);
      await _persist();
      if (state.role == UserRole.worker) {
        await WorkerRegistrationService.registerAfterSignUp(
          userId: state.userId ?? '',
          name: state.displayName ?? '',
          phone: state.phone,
          city: state.city,
          category: state.category,
          subcategory: state.subcategory,
          bio: state.bio,
          latitude: state.latitude,
          longitude: state.longitude,
        );
      }
    } on AuthException catch (e) {
      state = AuthState.failure(e.message);
    } catch (_) {
      state = const AuthState.failure(
        'No se pudo verificar el correo. Intenta de nuevo.',
      );
    }
  }

  Future<void> resendEmailCode(String email) async {
    state = const AuthState.loading();
    try {
      await repo.resendEmailCode(email);
      state = AuthState.emailConfirmationPending(
        email,
        message: 'Enviamos otro código de verificación a $email.',
      );
    } on AuthException catch (e) {
      state = AuthState.failure(e.message);
    } catch (_) {
      state = const AuthState.failure(
        'No se pudo reenviar el código. Intenta de nuevo.',
      );
    }
  }

  Future<void> signInWithGoogle(
    UserRole role, {
    required bool acceptedTerms,
    required bool isRegistration,
    String? phone,
    String? city,
    String? category,
    String? subcategory,
    String? bio,
    double? latitude,
    double? longitude,
  }) async {
    state = const AuthState.loading();
    try {
      state = await repo.signInWithGoogle(
        role: role,
        acceptedTerms: acceptedTerms,
        isRegistration: isRegistration,
        phone: phone,
        city: city,
        category: category,
        subcategory: subcategory,
        bio: bio,
        latitude: latitude,
        longitude: longitude,
      );
      await _persist();
      if (isRegistration && role == UserRole.worker && state.isAuthenticated) {
        await WorkerRegistrationService.registerAfterSignUp(
          userId: state.userId ?? '',
          name: state.displayName ?? '',
          phone: state.phone,
          city: state.city,
          category: state.category,
          subcategory: state.subcategory,
          bio: state.bio,
          latitude: state.latitude,
          longitude: state.longitude,
        );
      }
    } on AuthException catch (e) {
      state = AuthState.failure(e.message);
    } catch (_) {
      state = const AuthState.failure(
        'No se pudo iniciar sesión con Google. Intenta de nuevo.',
      );
    }
  }

  /// Inicia sesión con Google usando un token ya obtenido.
  ///
  /// Es el camino de la web: el botón oficial de Google Identity Services
  /// entrega el `id_token` y aquí se valida contra Supabase.
  Future<void> signInWithGoogleToken(
    String idToken, {
    required UserRole role,
    required bool acceptedTerms,
    required bool isRegistration,
    String? phone,
    String? city,
    String? category,
    String? subcategory,
    String? bio,
    double? latitude,
    double? longitude,
    String? displayName,
  }) async {
    state = const AuthState.loading();
    try {
      state = await repo.signInWithGoogleToken(
        idToken,
        role: role,
        acceptedTerms: acceptedTerms,
        isRegistration: isRegistration,
        phone: phone,
        city: city,
        category: category,
        subcategory: subcategory,
        bio: bio,
        latitude: latitude,
        longitude: longitude,
        displayName: displayName,
      );
      await _persist();
      if (isRegistration && role == UserRole.worker && state.isAuthenticated) {
        await WorkerRegistrationService.registerAfterSignUp(
          userId: state.userId ?? '',
          name: state.displayName ?? '',
          phone: state.phone,
          city: state.city,
          category: state.category,
          subcategory: state.subcategory,
          bio: state.bio,
          latitude: state.latitude,
          longitude: state.longitude,
        );
      }
    } on AuthException catch (e) {
      state = AuthState.failure(e.message);
    } catch (_) {
      state = const AuthState.failure(
        'No se pudo iniciar sesión con Google. Intenta de nuevo.',
      );
    }
  }

  /// Limpia los mensajes de estado cuando la persona vuelve a editar el form.
  void clearError() {
    if (state.errorMessage != null || state.successMessage != null) {
      state = state.copyWith(clearMessages: true);
    }
  }

  // Actualiza los datos del perfil y refresca la sesión guardada.
  Future<void> updateProfile({
    String? displayName,
    String? phone,
    String? city,
    String? avatarUrl,
  }) async {
    state = await repo.updateProfile(
      displayName: displayName,
      phone: phone,
      city: city,
      avatarUrl: avatarUrl,
    );
    await _persist();
  }

  Future<void> setTwoFactor(bool enabled) async {
    state = await repo.setTwoFactor(enabled);
    await StorageService.setTwoFactorEnabled(enabled);
    await _persist();
  }

  /// Enrolamiento TOTP pendiente de confirmar con el primer codigo.
  MfaEnrollment? get pendingMfaEnrollment => repo.pendingEnrollment;

  Future<bool> verifyTwoFactor(String code) => repo.verifyTwoFactor(code);

  Future<void> logout() async {
    await repo.logout();
    await StorageService.clearSession();
    state = const AuthState.unauthenticated();
  }
}

/// Flujo de recuperación de contraseña en tres pasos:
/// correo, código numérico y contraseña nueva.
final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryNotifier, PasswordRecoveryState>(
      PasswordRecoveryNotifier.new,
    );

class PasswordRecoveryNotifier extends Notifier<PasswordRecoveryState> {
  AuthRepository get repo => ref.read(authRepositoryProvider);

  @override
  PasswordRecoveryState build() => const PasswordRecoveryState.initial();

  /// Deja el flujo como nuevo cada vez que se abre la pantalla.
  void reset() {
    state = const PasswordRecoveryState.initial();
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Paso 1: pide el código de recuperación para el correo indicado.
  Future<bool> requestCode(String email) async {
    final trimmed = email.trim();
    state = state.copyWith(loading: true, clearError: true);
    try {
      await repo.requestPasswordReset(trimmed);
      state = PasswordRecoveryState(
        step: PasswordRecoveryStep.code,
        email: trimmed,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'No se pudo enviar el código. Intenta de nuevo.',
      );
      return false;
    }
  }

  /// Reenvía el código al mismo correo sin salir del paso del código.
  Future<bool> resendCode() async {
    if (state.email.isEmpty) return false;
    state = state.copyWith(loading: true, clearError: true);
    try {
      await repo.requestPasswordReset(state.email);
      state = state.copyWith(loading: false, clearError: true);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'No se pudo reenviar el código. Intenta de nuevo.',
      );
      return false;
    }
  }

  /// Paso 2: comprueba el código y abre la sesión temporal.
  Future<bool> verifyCode(String code) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await repo.verifyPasswordResetCode(email: state.email, code: code);
      state = state.copyWith(
        step: PasswordRecoveryStep.password,
        loading: false,
        clearError: true,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'No se pudo verificar el código. Intenta de nuevo.',
      );
      return false;
    }
  }

  /// Paso 3: guarda la contraseña nueva y cierra la sesión temporal.
  Future<bool> updatePassword(String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await repo.updatePassword(password);
      state = state.copyWith(loading: false, clearError: true);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'No se pudo cambiar la contraseña. Intenta de nuevo.',
      );
      return false;
    }
  }

  /// Vuelve al paso anterior sin cerrar el flujo.
  void backToEmail() {
    state = state.copyWith(
      step: PasswordRecoveryStep.email,
      email: '',
      loading: false,
      clearError: true,
    );
  }

  void backToCode() {
    state = state.copyWith(
      step: PasswordRecoveryStep.code,
      loading: false,
      clearError: true,
    );
  }

  /// Abandona el flujo y cierra la sesión temporal si ya se había verificado
  /// el código, para no quedar con una sesión abierta a medias.
  Future<void> cancel() async {
    final hadSession = state.step == PasswordRecoveryStep.password;
    reset();
    if (hadSession) {
      try {
        await repo.cancelPasswordReset();
      } catch (_) {
        // Si falla el cierre de sesión no se bloquea la salida: la próxima
        // entrada con contraseña reemplaza la sesión de todos modos.
      }
    }
  }
}
