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
  final String? termsVersion;
  final bool twoFactorEnabled;
  final bool loading;

  /// Mensaje de error del último intento fallido (null si no hay error).
  final String? errorMessage;
  final String? successMessage;

  const AuthState({
    required this.isAuthenticated,
    this.userId,
    this.email,
    this.displayName,
    this.role,
    this.phone,
    this.city,
    this.avatarUrl,
    this.termsVersion,
    this.twoFactorEnabled = false,
    this.loading = false,
    this.errorMessage,
    this.successMessage,
  });

  const AuthState.unauthenticated() : this(isAuthenticated: false);
  const AuthState.loading() : this(isAuthenticated: false, loading: true);

  /// Estado de error producido durante un intento de autenticación.
  const AuthState.failure(String message)
    : this(isAuthenticated: false, errorMessage: message);

  factory AuthState.emailConfirmationPending(String email, {String? message}) =>
      AuthState(
        isAuthenticated: false,
        successMessage:
            message ??
            'Enviamos un código de verificación a $email. '
                'Escríbelo para confirmar tu correo y continuar.',
      );

  static AuthState authenticated({
    required String userId,
    required String email,
    required String displayName,
    required UserRole role,
    String? phone,
    String? city,
    String? avatarUrl,
    String? termsVersion,
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
    termsVersion: termsVersion,
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
    String? termsVersion,
    bool? twoFactorEnabled,
    bool? loading,
    bool clearMessages = false,
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
      termsVersion: termsVersion ?? this.termsVersion,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      loading: loading ?? this.loading,
      errorMessage: clearMessages ? null : errorMessage,
      successMessage: clearMessages ? null : successMessage,
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
    'termsVersion': termsVersion,
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
      termsVersion: json['termsVersion'] as String?,
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
    );
  }
}
