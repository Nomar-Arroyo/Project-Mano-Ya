import '../../shared/models/user_role.dart';

class AuthState {
  final bool isAuthenticated;
  final String? userId;
  final String? email;
  final String? displayName;
  final UserRole? role;
  final String? phone;
  final String? city;
  final bool loading;

  const AuthState({
    required this.isAuthenticated,
    this.userId,
    this.email,
    this.displayName,
    this.role,
    this.phone,
    this.city,
    this.loading = false,
  });

  const AuthState.unauthenticated() : this(isAuthenticated: false);
  const AuthState.loading() : this(isAuthenticated: false, loading: true);

  static AuthState authenticated({
    required String userId,
    required String email,
    required String displayName,
    required UserRole role,
    String? phone,
    String? city,
  }) => AuthState(
    isAuthenticated: true,
    userId: userId,
    email: email,
    displayName: displayName,
    role: role,
    phone: phone,
    city: city,
  );
}
