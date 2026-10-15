import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_state.dart';
import '../../shared/models/user_role.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier(AuthRepository());
});

class AuthNotifier extends Notifier<AuthState> {
  final AuthRepository repo;
  AuthNotifier(this.repo);

  @override
  AuthState build() {
    return const AuthState.unauthenticated();
  }

  Future<void> loginEmail(String email, String password) async {
    state = const AuthState.loading();
    state = await repo.loginEmailPassword(email, password);
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
  }

  Future<void> signInWithGoogle(UserRole role) async {
    state = const AuthState.loading();
    state = await repo.signInWithGoogle(role: role);
  }

  Future<void> logout() async {
    await repo.logout();
    state = const AuthState.unauthenticated();
  }
}
