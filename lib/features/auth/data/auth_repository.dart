import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/auth_state.dart';
import '../../shared/models/user_role.dart';

/// Error de autenticación (credenciales inválidas, cuenta inexistente, etc.).
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  // final GoogleSignIn _googleSignIn = GoogleSignIn();
  AuthState _state = const AuthState.unauthenticated();
  AuthState get state => _state;

  Future<AuthState> restoreSession() async {
    final user = SupabaseService.client?.auth.currentUser;
    if (user == null) return const AuthState.unauthenticated();
    _state = _stateFromUser(user);
    return _state;
  }

  Future<AuthState> loginEmailPassword(
    String email,
    String password, {
    UserRole role = UserRole.client,
    bool twoFactorEnabled = false,
  }) async {
    final client = SupabaseService.client;
    if (client != null) {
      try {
        final response = await client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        final user = response.user;
        if (user == null) {
          throw const AuthException('Supabase no devolvió un usuario válido.');
        }
        _state = _stateFromUser(user, fallbackRole: role);
        return _state;
      } on supabase.AuthException catch (error) {
        throw AuthException(error.message);
      }
    }

    // MOCK: simulacion de login
    await Future.delayed(const Duration(milliseconds: 600));
    // Defensivo: con backend real aquí se validarían las credenciales.
    if (email.trim().isEmpty || password.length < 6) {
      throw const AuthException('Correo o contraseña incorrectos.');
    }
    _state = AuthState.authenticated(
      userId: 'mock_user',
      email: email,
      displayName: email.split('@').first,
      role: role,
      twoFactorEnabled: twoFactorEnabled,
    );
    return _state;
  }

  Future<AuthState> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
    String? city,
  }) async {
    final client = SupabaseService.client;
    if (client != null) {
      try {
        final response = await client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'full_name': name,
            'role': role.name,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
            if (city != null && city.isNotEmpty) 'city': city,
          },
        );
        final user = response.user;
        if (user == null) {
          throw const AuthException('Supabase no devolvió un usuario válido.');
        }
        if (response.session == null) {
          throw const AuthException(
            'Cuenta creada. Confirma tu correo electrónico y luego inicia sesión.',
          );
        }
        _state = _stateFromUser(user, fallbackRole: role);
        return _state;
      } on supabase.AuthException catch (error) {
        throw AuthException(error.message);
      }
    }

    // MOCK: simulacion de registro con rol obligatorio
    await Future.delayed(const Duration(milliseconds: 700));
    _state = AuthState.authenticated(
      userId: 'mock_user',
      email: email,
      displayName: name,
      role: role,
      phone: phone,
      city: city,
    );
    return _state;
  }

  /// Inicia sesión con Google.
  ///
  /// Cuando Supabase y las credenciales de Google están configurados se hace
  /// el flujo real: se obtiene el `id_token` de Google y Supabase lo valida
  /// para crear la sesión. El rol siempre es obligatorio: se guarda en los
  /// metadatos del usuario para que la app sepa si es cliente o trabajador.
  Future<AuthState> signInWithGoogle({required UserRole role}) async {
    final client = SupabaseService.client;
    if (client == null) {
      // MOCK de Google Sign-In (no requiere credenciales reales por ahora)
      await Future.delayed(const Duration(milliseconds: 700));
      _state = AuthState.authenticated(
        userId: 'mock_google',
        email: 'usuario.mock@gmail.com',
        displayName: 'Usuario Mock',
        role: role,
      );
      return _state;
    }

    if (!AppConfig.hasGoogleCredentials) {
      throw const AuthException(
        'Faltan las credenciales de Google (GOOGLE_CLIENT_ID y '
        'GOOGLE_SERVER_CLIENT_ID) en el archivo .env.',
      );
    }

    try {
      await GoogleSignIn.instance.initialize(
        clientId: AppConfig.googleClientId.isEmpty
            ? null
            : AppConfig.googleClientId,
        serverClientId: AppConfig.googleServerClientId.isEmpty
            ? null
            : AppConfig.googleServerClientId,
      );

      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );

      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'Google no devolvió un token de sesión. Revisa la configuración '
          'del cliente web en Google Cloud.',
        );
      }

      final response = await client.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('Supabase no devolvió un usuario válido.');
      }

      // El rol y el nombre se guardan en los metadatos del usuario para que
      // la app los use en las pantallas de perfil y panel.
      final updated = await client.auth.updateUser(
        supabase.UserAttributes(
          data: {
            'full_name': account.displayName ?? user.userMetadata?['full_name'],
            'role': role.name,
          },
        ),
      );

      _state = _stateFromUser(updated.user ?? user, fallbackRole: role);
      return _state;
    } on supabase.AuthException catch (error) {
      throw AuthException(error.message);
    } on AuthException {
      rethrow;
    } catch (error) {
      throw AuthException('No se pudo iniciar sesión con Google: $error');
    }
  }

  // Actualiza los datos editables del perfil.
  Future<AuthState> updateProfile({
    String? displayName,
    String? phone,
    String? city,
    String? avatarUrl,
  }) async {
    final client = SupabaseService.client;
    if (client != null) {
      final data = <String, dynamic>{
        'full_name': ?displayName,
        'phone': ?phone,
        'city': ?city,
        'avatar_url': ?avatarUrl,
      };
      try {
        final response = await client.auth.updateUser(
          supabase.UserAttributes(data: data),
        );
        final user = response.user;
        if (user == null) {
          throw const AuthException('No se pudo actualizar el perfil.');
        }
        _state = _stateFromUser(user);
        return _state;
      } on supabase.AuthException catch (error) {
        throw AuthException(error.message);
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));
    _state = _state.copyWith(
      displayName: displayName,
      phone: phone,
      city: city,
      avatarUrl: avatarUrl,
    );
    return _state;
  }

  // Activa o desactiva el segundo factor (2FA).
  Future<AuthState> setTwoFactor(bool enabled) async {
    if (SupabaseService.isConfigured) {
      throw const AuthException(
        'La verificación 2FA todavía no está configurada en Supabase.',
      );
    }
    await Future.delayed(const Duration(milliseconds: 200));
    _state = _state.copyWith(twoFactorEnabled: enabled);
    return _state;
  }

  // Verifica el codigo 2FA. En modo mock acepta cualquier codigo de 6 digitos.
  Future<bool> verifyTwoFactor(String code) async {
    if (SupabaseService.isConfigured) {
      throw const AuthException(
        'La verificación 2FA todavía no está configurada en Supabase.',
      );
    }
    await Future.delayed(const Duration(milliseconds: 400));
    return code.length == 6 && int.tryParse(code) != null;
  }

  Future<void> logout() async {
    final client = SupabaseService.client;
    if (client != null) {
      try {
        await client.auth.signOut();
      } on supabase.AuthException catch (error) {
        throw AuthException(error.message);
      }
    }
    _state = const AuthState.unauthenticated();
  }

  AuthState _stateFromUser(
    supabase.User user, {
    UserRole fallbackRole = UserRole.client,
  }) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final roleName = metadata['role'];
    final role = UserRole.values.where((value) => value.name == roleName);
    return AuthState.authenticated(
      userId: user.id,
      email: user.email ?? '',
      displayName:
          metadata['full_name'] as String? ??
          metadata['name'] as String? ??
          user.email?.split('@').first ??
          '',
      role: role.isNotEmpty ? role.first : fallbackRole,
      phone: metadata['phone'] as String?,
      city: metadata['city'] as String?,
      avatarUrl: metadata['avatar_url'] as String?,
    );
  }
}
