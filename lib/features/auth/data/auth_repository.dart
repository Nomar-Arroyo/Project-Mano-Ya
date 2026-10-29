import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/auth_state.dart';
import '../domain/mfa_enrollment.dart';
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

  // Evita inicializar dos veces el SDK de Google (el navegador reconstruye
  // el boton y el SDK lanza un error si se inicializa dos veces).
  bool _googleInicializado = false;
  String? _googleRawNonce;

  // Enrolamiento TOTP pendiente de confirmar con el primer código.
  MfaEnrollment? _pendingEnrollment;

  /// Devuelve el enrolamiento TOTP pendiente de confirmar, si existe.
  MfaEnrollment? get pendingEnrollment => _pendingEnrollment;

  Future<AuthState> restoreSession() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (user == null) return const AuthState.unauthenticated();
    if (user.emailConfirmedAt == null) {
      await client!.auth.signOut();
      return const AuthState.unauthenticated();
    }
    _state = await _stateFromUser(user);
    return _state;
  }

  Future<AuthState> loginEmailPassword(
    String email,
    String password, {
    UserRole role = UserRole.client,
  }) async {
    final client = SupabaseService.client;
    if (client == null) {
      throw const AuthException(
        'No hay conexión con Supabase. Configura el backend para iniciar sesión.',
      );
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('Supabase no devolvió un usuario válido.');
      }
      if (user.emailConfirmedAt == null) {
        await client.auth.signOut();
        throw const AuthException(
          'Confirma tu correo electrónico antes de iniciar sesión.',
        );
      }
      _state = await _stateFromUser(user, fallbackRole: role);
      return _state;
    } on supabase.AuthException catch (error) {
      if (error.code == 'invalid_credentials' ||
          error.code == 'user_not_found' ||
          error.message.toLowerCase().contains('invalid login credentials')) {
        throw const AuthException(
          'No se pudo iniciar sesión. Verifica tu correo y contraseña. '
          'Si aún no tienes cuenta, regístrate.',
        );
      }
      if (error.code == 'email_not_confirmed') {
        throw const AuthException(
          'Confirma tu correo electrónico antes de iniciar sesión.',
        );
      }
      throw AuthException(error.message);
    }
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
        if (user.emailConfirmedAt != null) {
          if (response.session != null) {
            await client.auth.signOut();
          }
          throw const AuthException(
            'Supabase está permitiendo el registro sin verificar el correo. '
            'Activa la confirmación de correo en la configuración de Auth '
            'para impedir el acceso antes de verificar.',
          );
        }
        if (response.session != null) {
          await client.auth.signOut();
        }
        _state = AuthState.emailConfirmationPending(email.trim());
        return _state;
      } on supabase.AuthException catch (error) {
        throw _emailDeliveryError(error);
      }
    }

    throw const AuthException(
      'La app está en modo de prueba y no puede enviar correos. '
      'Configura Supabase para habilitar el registro con verificación.',
    );
  }

  Future<AuthState> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final client = SupabaseService.client;
    if (client == null) {
      throw const AuthException(
        'Supabase no está configurado; no se pueden verificar códigos.',
      );
    }

    try {
      final response = await client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: supabase.OtpType.signup,
      );
      final user = response.user;
      if (user == null || response.session == null) {
        throw const AuthException(
          'No se pudo verificar el correo. Solicita un código nuevo.',
        );
      }
      if (user.emailConfirmedAt == null) {
        await client.auth.signOut();
        throw const AuthException(
          'El correo aún no aparece verificado. Revisa el código e inténtalo de nuevo.',
        );
      }
      _state = await _stateFromUser(user);
      return _state;
    } on supabase.AuthException catch (error) {
      throw _emailDeliveryError(error);
    }
  }

  Future<void> resendEmailCode(String email) async {
    final client = SupabaseService.client;
    if (client == null) {
      throw const AuthException(
        'Supabase no está configurado; no se pueden enviar códigos.',
      );
    }
    try {
      await client.auth.resend(
        email: email.trim(),
        type: supabase.OtpType.signup,
      );
    } on supabase.AuthException catch (error) {
      throw _emailDeliveryError(error);
    }
  }

  /// Traduce los errores de envío de correo de Supabase a un mensaje útil.
  ///
  /// El SMTP integrado de Supabase limita los envíos por hora. Cuando se
  /// agota, GoTrue responde `over_email_send_rate_limit` y no envía nada,
  /// así que conviene decirlo con claridad en vez de mostrar el texto en
  /// inglés.
  AuthException _emailDeliveryError(supabase.AuthException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    if (code == 'over_email_send_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('too many')) {
      return const AuthException(
        'Se enviaron demasiados correos en poco tiempo. Espera unos minutos '
        'antes de pedir otro código, revisa la carpeta de spam o entra con '
        'Google.',
      );
    }
    if (code == 'email_address_invalid' || message.contains('invalid email')) {
      return const AuthException(
        'Ese correo no parece válido. Revísalo e inténtalo de nuevo.',
      );
    }
    return AuthException(error.message);
  }

  /// Prepara el SDK de Google Sign-In.
  ///
  /// En Android e iOS se llama antes de `authenticate()`. En la web el SDK
  /// oficial (Google Identity Services) exige que se use su propio boton,
  /// asi que este metodo solo deja el SDK listo para dibujarlo.
  ///
  /// El SDK lanza un error si se inicializa dos veces, por eso se guarda
  /// una bandera: la pagina web puede reconstruir el boton varias veces.
  Future<void> prepareGoogleSignIn() async {
    if (!AppConfig.hasGoogleCredentials) {
      throw const AuthException(
        'Faltan las credenciales de Google (GOOGLE_CLIENT_ID y '
        'GOOGLE_SERVER_CLIENT_ID) en el archivo .env.',
      );
    }
    if (_googleInicializado) return;
    final client = SupabaseService.client;
    _googleRawNonce = client?.auth.generateRawNonce();
    final hashedNonce = _googleRawNonce == null
        ? null
        : sha256.convert(utf8.encode(_googleRawNonce!)).toString();
    await GoogleSignIn.instance.initialize(
      clientId: AppConfig.googleClientId.isEmpty
          ? null
          : AppConfig.googleClientId,
      serverClientId: kIsWeb || AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
      nonce: hashedNonce,
    );
    _googleInicializado = true;
  }

  /// Inicia sesión con Google.
  ///
  /// Cuando Supabase y las credenciales de Google están configurados se hace
  /// el flujo real: se obtiene el `id_token` de Google y Supabase lo valida
  /// para crear la sesión. El rol siempre es obligatorio: se guarda en los
  /// metadatos del usuario para que la app sepa si es cliente o trabajador.
  ///
  /// En la web este metodo no se usa: el boton oficial de Google devuelve el
  /// token y el flujo continua en [signInWithGoogleToken].
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
      await prepareGoogleSignIn();

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

      return await signInWithGoogleToken(
        idToken,
        role: role,
        displayName: account.displayName,
      );
    } on AuthException {
      rethrow;
    } catch (error) {
      throw AuthException('No se pudo iniciar sesión con Google: $error');
    }
  }

  /// Valida en Supabase el `id_token` que devolvio Google.
  ///
  /// Es el paso comun a todas las plataformas: en Android e iOS el token
  /// llega de [signInWithGoogle] y en la web llega del boton oficial de
  /// Google Identity Services.
  Future<AuthState> signInWithGoogleToken(
    String idToken, {
    required UserRole role,
    String? displayName,
  }) async {
    final client = SupabaseService.client;
    if (client == null) {
      throw const AuthException(
        'Supabase no está configurado. Revisa el archivo .env.',
      );
    }

    try {
      final response = await client.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        nonce: _googleRawNonce,
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
            'full_name': displayName ?? user.userMetadata?['full_name'],
            'role': role.name,
          },
        ),
      );

      _state = await _stateFromUser(updated.user ?? user, fallbackRole: role);
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
        _state = await _stateFromUser(user);
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

  // Activa o desactiva el segundo factor (2FA) con TOTP de Supabase.
  //
  // Al activar se genera el secreto y el codigo QR; el factor queda pendiente
  // hasta que el usuario confirma con el primer codigo de su aplicacion
  // autenticadora. Al desactivar se elimina el factor verificado.
  Future<AuthState> setTwoFactor(bool enabled) async {
    final client = SupabaseService.client;
    if (client == null) {
      await Future.delayed(const Duration(milliseconds: 200));
      _state = _state.copyWith(twoFactorEnabled: enabled);
      return _state;
    }

    try {
      if (enabled) {
        final enrollment = await client.auth.mfa.enroll(
          factorType: supabase.FactorType.totp,
          issuer: AppConfig.appName,
          friendlyName: 'Aplicacion autenticadora',
        );
        final totp = enrollment.totp;
        if (totp == null) {
          throw const AuthException(
            'Supabase no devolvio los datos del codigo QR. Intenta de nuevo.',
          );
        }
        _pendingEnrollment = MfaEnrollment(
          factorId: enrollment.id,
          secret: totp.secret,
          qrCode: totp.qrCode,
          uri: totp.uri,
        );
        // El factor aun no esta verificado: la sesion sigue en aal1.
        _state = await _stateFromUser(
          client.auth.currentUser!,
          fallbackRole: _state.role ?? UserRole.client,
        );
        return _state;
      }

      final factors = await client.auth.mfa.listFactors();
      for (final factor in factors.totp) {
        await client.auth.mfa.unenroll(factor.id);
      }
      _pendingEnrollment = null;
      _state = await _stateFromUser(
        client.auth.currentUser!,
        fallbackRole: _state.role ?? UserRole.client,
      );
      return _state;
    } on supabase.AuthException catch (error) {
      throw AuthException(error.message);
    } catch (error) {
      throw AuthException(
        'No se pudo actualizar la verificación en 2 pasos: $error',
      );
    }
  }

  /// Verifica el codigo TOTP de 6 digitos.
  ///
  /// Con Supabase configurado se resuelve el reto real (challenge + verify).
  /// En modo mock se acepta cualquier codigo numerico de 6 digitos.
  Future<bool> verifyTwoFactor(String code) async {
    final client = SupabaseService.client;
    if (client == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      return code.length == 6 && int.tryParse(code) != null;
    }

    try {
      // Primero se confirma un enrolamiento pendiente (activacion).
      final pending = _pendingEnrollment;
      if (pending != null) {
        await client.auth.mfa.challengeAndVerify(
          factorId: pending.factorId,
          code: code,
        );
        _pendingEnrollment = null;
        _state = await _stateFromUser(
          client.auth.currentUser!,
          fallbackRole: _state.role ?? UserRole.client,
        );
        return true;
      }

      // Verificacion normal de una sesion que ya tiene factor TOTP.
      final factors = await client.auth.mfa.listFactors();
      if (factors.totp.isEmpty) {
        throw const AuthException(
          'No hay ningun metodo de verificacion registrado para esta cuenta.',
        );
      }
      await client.auth.mfa.challengeAndVerify(
        factorId: factors.totp.first.id,
        code: code,
      );
      _state = await _stateFromUser(
        client.auth.currentUser!,
        fallbackRole: _state.role ?? UserRole.client,
      );
      return true;
    } on supabase.AuthException catch (error) {
      throw AuthException(error.message);
    } catch (error) {
      throw AuthException('El codigo no es valido: $error');
    }
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
    _pendingEnrollment = null;
    _state = const AuthState.unauthenticated();
  }

  Future<AuthState> _stateFromUser(
    supabase.User user, {
    UserRole fallbackRole = UserRole.client,
  }) async {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final roleName = metadata['role'];
    final role = UserRole.values.where((value) => value.name == roleName);
    final twoFactor = await _hasVerifiedFactor();
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
      twoFactorEnabled: twoFactor,
    );
  }

  /// Indica si la cuenta ya tiene un factor TOTP verificado.
  Future<bool> _hasVerifiedFactor() async {
    final client = SupabaseService.client;
    if (client == null) return _state.twoFactorEnabled;
    try {
      final factors = await client.auth.mfa.listFactors();
      return factors.totp.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
