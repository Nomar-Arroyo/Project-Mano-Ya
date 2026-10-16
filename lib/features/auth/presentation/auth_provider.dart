import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';
import '../../shared/models/user_role.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

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
    final twoFactor = await StorageService.getTwoFactorEnabled();
    state = await repo.loginEmailPassword(
      email,
      password,
      role: role,
      twoFactorEnabled: twoFactor,
    );
    await _persist();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
    String? city,
  }) async {
    state = const AuthState.loading();
    state = await repo.register(
      name: name,
      email: email,
      password: password,
      role: role,
      phone: phone,
      city: city,
    );
    await _persist();
  }

  Future<void> signInWithGoogle(UserRole role) async {
    state = const AuthState.loading();
    state = await repo.signInWithGoogle(role: role);
    final twoFactor = await StorageService.getTwoFactorEnabled();
    if (twoFactor != state.twoFactorEnabled) {
      state = await repo.setTwoFactor(twoFactor);
    }
    await _persist();
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

  Future<bool> verifyTwoFactor(String code) => repo.verifyTwoFactor(code);

  Future<void> logout() async {
    await repo.logout();
    await StorageService.clearSession();
    state = const AuthState.unauthenticated();
  }
}
