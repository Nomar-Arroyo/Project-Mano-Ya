import '../../shared/models/user_role.dart';

class AuthState {
  final bool isAuthenticated;
  final String? userId;
  final String? email;
  final String? displayName;
  final UserRole? role;
  final String? phone;
  final String? city;
  final String? avatarUrl;
  final bool twoFactorEnabled;
  final bool loading;

  const AuthState({
    required this.isAuthenticated,
    this.userId,
    this.email,
    this.displayName,
    this.role,
    this.phone,
    this.city,
    this.avatarUrl,
    this.twoFactorEnabled = false,
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
    String? avatarUrl,
    bool twoFactorEnabled = false,
  }) => AuthState(
    isAuthenticated: true,
    userId: userId,
    email: email,
    displayName: displayName,
    role: role,
    phone: phone,
    city: city,
    avatarUrl: avatarUrl,
    twoFactorEnabled: twoFactorEnabled,
  );

  // Devuelve una copia con los campos indicados reemplazados.
  AuthState copyWith({
    String? userId,
    String? email,
    String? displayName,
    UserRole? role,
    String? phone,
    String? city,
    String? avatarUrl,
    bool? twoFactorEnabled,
    bool? loading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      loading: loading ?? this.loading,
    );
  }

  // Serializa la sesión para guardarla en preferencias.
  Map<String, dynamic> toJson() => {
    'isAuthenticated': isAuthenticated,
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'role': role?.name,
    'phone': phone,
    'city': city,
    'avatarUrl': avatarUrl,
    'twoFactorEnabled': twoFactorEnabled,
  };

  // Restaura una sesión previamente guardada.
  static AuthState fromJson(Map<String, dynamic> json) {
    final roleName = json['role'] as String?;
    return AuthState(
      isAuthenticated: json['isAuthenticated'] as bool? ?? false,
      userId: json['userId'] as String?,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      role: roleName == null
          ? null
          : UserRole.values.firstWhere(
              (r) => r.name == roleName,
              orElse: () => UserRole.client,
            ),
      phone: json['phone'] as String?,
      city: json['city'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
    );
  }
}
