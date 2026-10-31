import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/auth_state.dart';
import '../domain/mfa_enrollment.dart';
import '../domain/terms_policy.dart';
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
    required bool acceptedTerms,
    String? phone,
    String? city,
    String? category,
    String? subcategory,
    String? bio,
    double? latitude,
    double? longitude,
  }) async {
    if (!acceptedTerms) {
      throw const AuthException(
        'Debes aceptar los términos y condiciones para crear una cuenta.',
      );
    }
    final client = SupabaseService.client;
    if (client != null) {
      try {
        final response = await client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'full_name': name,
            'role': role.name,
            'terms_accepted': true,
            'terms_version': TermsPolicy.version,
            if (phone?.isNotEmpty == true) 'phone': phone,
            if (city?.isNotEmpty == true) 'city': city,
            if (category?.isNotEmpty == true) 'category': category,
            if (subcategory?.isNotEmpty == true) 'subcategory': subcategory,
            if (bio?.isNotEmpty == true) 'bio': bio,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
          },
        );
        final user = response.user;
        if (user == null) {
          throw const AuthException('Supabase no devolvió un usuario válido.');
        }
        // Supabase responde 200 con `identities` vacío cuando el correo ya
        // tiene cuenta. Es una medida anti-enumeración y no envía ningún
        // correo, así que conviene decirlo en vez de dejar al usuario
        // esperando un código que nunca va a llegar.
        if (user.identities != null && user.identities!.isEmpty) {
          throw const AuthException(
            'Ese correo ya tiene una cuenta. Inicia sesión con tu contraseña.',
          );
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
      if (user.userMetadata?['terms_version'] != TermsPolicy.version ||
          user.userMetadata?['terms_accepted'] != true) {
        await client.auth.signOut();
        throw const AuthException(
          'Debes aceptar los términos y condiciones antes de crear tu cuenta.',
        );
      }
      final acceptedUser = await _recordTermsAcceptance(client);
      _state = await _stateFromUser(acceptedUser);
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

  /// Envía un código de recuperación de contraseña al correo indicado.
  ///
  /// Supabase responde con éxito aunque el correo no tenga cuenta (medida
  /// anti-enumeración) y en ese caso no envía nada, así que la app muestra
  /// siempre el mismo mensaje para no revelar qué correos están registrados.
  Future<void> requestPasswordReset(String email) async {
    final client = SupabaseService.client;
    if (client == null) {
      throw const AuthException(
        'Supabase no está configurado; no se pueden enviar códigos.',
      );
    }
    try {
      await client.auth.resetPasswordForEmail(email.trim());
    } on supabase.AuthException catch (error) {
      throw _emailDeliveryError(error);
    }
  }

  /// Verifica el código de recuperación y abre la sesión temporal.
  ///
  /// Esa sesión solo sirve para guardar la contraseña nueva: la app no la usa
  /// para entrar directamente, y [updatePassword] la cierra al terminar.
  Future<void> verifyPasswordResetCode({
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
        type: supabase.OtpType.recovery,
      );
      if (response.session == null) {
        throw const AuthException(
          'El código no es válido o ya venció. Solicita uno nuevo.',
        );
      }
    } on supabase.AuthException catch (error) {
      final errorCode = error.code ?? '';
      final message = error.message.toLowerCase();
      if (errorCode == 'otp_expired' || message.contains('expired')) {
        throw const AuthException(
          'El código venció. Pide uno nuevo e inténtalo otra vez.',
        );
      }
      if (errorCode == 'otp_disabled' || message.contains('invalid')) {
        throw const AuthException(
          'El código no es correcto. Revísalo e inténtalo de nuevo.',
        );
      }
      throw _emailDeliveryError(error);
    }
  }

  /// Guarda la contraseña nueva usando la sesión del código de recuperación.
  Future<void> updatePassword(String password) async {
    final client = SupabaseService.client;
    if (client == null) {
      throw const AuthException(
        'Supabase no está configurado; no se puede cambiar la contraseña.',
      );
    }
    try {
      await client.auth.updateUser(supabase.UserAttributes(password: password));
      // La sesión abierta por el código solo sirve para este cambio: se
      // cierra para que la persona entre con la contraseña nueva.
      await client.auth.signOut();
    } on supabase.AuthException catch (error) {
      final errorCode = error.code ?? '';
      final message = error.message.toLowerCase();
      if (errorCode == 'same_password' || message.contains('same password')) {
        throw const AuthException(
          'La contraseña nueva debe ser diferente a la anterior.',
        );
      }
      if (errorCode == 'weak_password' || message.contains('weak')) {
        throw const AuthException(
          'La contraseña es demasiado débil. Usa al menos 6 caracteres.',
        );
      }
      throw _emailDeliveryError(error);
    }
  }

  /// Cierra la sesión temporal que dejó el código de recuperación.
  ///
  /// Solo se usa cuando la persona abandona el flujo después de verificar el
  /// código y antes de guardar la contraseña nueva.
  Future<void> cancelPasswordReset() async {
    final client = SupabaseService.client;
    if (client != null && client.auth.currentSession != null) {
      await client.auth.signOut();
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
  Future<AuthState> signInWithGoogle({
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
  }) async {
    if (isRegistration && !acceptedTerms) {
      throw const AuthException(
        'Debes aceptar los términos y condiciones para continuar.',
      );
    }
    final client = SupabaseService.client;
    if (client == null) {
      // MOCK de Google Sign-In (no requiere credenciales reales por ahora)
      await Future.delayed(const Duration(milliseconds: 700));
      _state = AuthState.authenticated(
        userId: 'mock_google',
        email: 'usuario.mock@gmail.com',
        displayName: 'Usuario Mock',
        role: role,
        phone: phone,
        city: city,
        category: category,
        subcategory: subcategory,
        bio: bio,
        latitude: latitude,
        longitude: longitude,
        termsVersion: isRegistration ? TermsPolicy.version : null,
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
        acceptedTerms: acceptedTerms,
        isRegistration: isRegistration,
        phone: phone,
        city: city,
        category: category,
        subcategory: subcategory,
        bio: bio,
        latitude: latitude,
        longitude: longitude,
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
    if (isRegistration && !acceptedTerms) {
      throw const AuthException(
        'Debes aceptar los términos y condiciones para continuar.',
      );
    }
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

      final metadata = user.userMetadata ?? const <String, dynamic>{};
      if (isRegistration ||
          metadata['role'] != UserRole.client.name &&
              metadata['role'] != UserRole.worker.name) {
        await client.auth.updateUser(
          supabase.UserAttributes(
            data: {
              if (displayName != null) 'full_name': displayName,
              'role': role.name,
              if (isRegistration && phone?.isNotEmpty == true) 'phone': phone,
              if (isRegistration && city?.isNotEmpty == true) 'city': city,
              if (isRegistration && category?.isNotEmpty == true)
                'category': category,
              if (isRegistration && subcategory?.isNotEmpty == true)
                'subcategory': subcategory,
              if (isRegistration && bio?.isNotEmpty == true) 'bio': bio,
              if (isRegistration && latitude != null) 'latitude': latitude,
              if (isRegistration && longitude != null) 'longitude': longitude,
            },
          ),
        );
      }

      final authenticatedUser = client.auth.currentUser;
      if (authenticatedUser == null) {
        throw const AuthException('Supabase no devolvió un usuario válido.');
      }
      if (isRegistration) {
        final acceptedUser = await _recordTermsAcceptance(client);
        _state = await _stateFromUser(acceptedUser, fallbackRole: role);
      } else {
        final acceptedTermsVersion =
            authenticatedUser.userMetadata?['terms_version'];
        if (acceptedTermsVersion == null ||
            authenticatedUser.userMetadata?['terms_accepted'] != true) {
          await client.auth.signOut();
          throw const AuthException(
            'Esta cuenta aún debe aceptar los términos. Regístrate para '
            'confirmar tu aceptación.',
          );
        }
        _state = await _stateFromUser(authenticatedUser, fallbackRole: role);
      }
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

  Future<supabase.User> _recordTermsAcceptance(
    supabase.SupabaseClient client,
  ) async {
    try {
      final response = await client.functions.invoke(
        'accept-terms',
        body: {'accepted': true, 'terms_version': TermsPolicy.version},
      );
      final data = response.data;
      if (response.status < 200 ||
          response.status >= 300 ||
          data is! Map ||
          data['ok'] != true ||
          data['terms_version'] != TermsPolicy.version ||
          data['accepted_at'] is! String) {
        final message = data is Map && data['error'] is String
            ? data['error'] as String
            : 'No se pudo confirmar el registro de aceptación.';
        throw AuthException(message);
      }

      final updated = await client.auth.updateUser(
        supabase.UserAttributes(
          data: {
            'terms_accepted': true,
            'terms_version': TermsPolicy.version,
            'terms_accepted_at': data['accepted_at'],
          },
        ),
      );
      if (updated.user == null) {
        throw const AuthException(
          'No se pudo guardar la aceptación en tu cuenta.',
        );
      }
      return updated.user!;
    } on AuthException {
      await client.auth.signOut();
      rethrow;
    } catch (error) {
      await client.auth.signOut();
      throw AuthException(
        'No se pudo guardar la aceptación de los términos. '
        'Inténtalo de nuevo. ($error)',
      );
    }
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
      category: metadata['category'] as String?,
      subcategory: metadata['subcategory'] as String?,
      bio: metadata['bio'] as String?,
      latitude: (metadata['latitude'] as num?)?.toDouble(),
      longitude: (metadata['longitude'] as num?)?.toDouble(),
      avatarUrl: metadata['avatar_url'] as String?,
      termsVersion: metadata['terms_version'] as String?,
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
