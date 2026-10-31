import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/app_config.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_button.dart';
import '../../data/auth_repository.dart';
import '../auth_provider.dart';
import 'google_sign_in_platform_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_platform_web.dart'
    as platform;

/// Botón de inicio de sesión con Google que funciona en todas las plataformas.
///
/// En Android e iOS se usa el diálogo nativo del SDK. En la web, Google
/// Identity Services **solo permite** iniciar sesión con el botón que
/// proporciona el propio SDK: por eso ahí se dibuja ese botón y se escucha
/// el evento de autenticación para pasarle el token a Supabase.
class GoogleSignInButton extends ConsumerStatefulWidget {
  /// Rol con el que se creará la cuenta (cliente o trabajador).
  final UserRole role;

  /// Texto del botón en Android e iOS.
  final String label;
  final bool termsAccepted;
  final bool isRegistration;
  final String? phone;
  final String? city;
  final String? category;
  final String? subcategory;
  final String? bio;
  final double? latitude;
  final double? longitude;

  const GoogleSignInButton({
    super.key,
    required this.role,
    this.label = 'Continuar con Google',
    this.termsAccepted = false,
    this.isRegistration = false,
    this.phone,
    this.city,
    this.category,
    this.subcategory,
    this.bio,
    this.latitude,
    this.longitude,
  });

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _listo = false;
  bool _modoDemo = false;
  bool _signingIn = false;
  String? _errorMessage;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEvents;

  @override
  void dispose() {
    unawaited(_googleEvents?.cancel());
    super.dispose();
  }

  bool get _registrationDataValid {
    if (!widget.isRegistration || widget.role != UserRole.worker) return true;
    final phoneDigits = (widget.phone ?? '').replaceAll(RegExp(r'\D'), '');
    return widget.category?.isNotEmpty == true &&
        widget.subcategory?.isNotEmpty == true &&
        widget.city?.isNotEmpty == true &&
        widget.latitude != null &&
        widget.longitude != null &&
        phoneDigits.length >= 12 &&
        widget.bio?.trim().isNotEmpty == true;
  }

  @override
  void initState() {
    super.initState();
    if (!AppConfig.hasSupabaseCredentials && kDebugMode) {
      _modoDemo = true;
      return;
    }
    if (kIsWeb) _prepararWeb();
  }

  /// Prepara el SDK de Google en la web y escucha el evento de inicio de
  /// sesión que emite el botón oficial.
  Future<void> _prepararWeb() async {
    try {
      await ref.read(authRepositoryProvider).prepareGoogleSignIn();

      if (!mounted) return;
      _googleEvents = GoogleSignIn.instance.authenticationEvents.listen(
        (evento) {
          if (evento is GoogleSignInAuthenticationEventSignIn) {
            final token = evento.user.authentication.idToken;
            if (token != null && token.isNotEmpty) {
              unawaited(_iniciarSesion(token, evento.user.displayName));
            }
          }
        },
        onError: (Object error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error de Google: $error')));
        },
      );

      if (mounted) setState(() => _listo = true);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _listo = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _listo = false;
        _errorMessage =
            'No se pudo cargar Google. Revisa la configuración OAuth.';
      });
    }
  }

  /// Valida el token de Google en Supabase.
  Future<void> _iniciarSesion(String idToken, String? displayName) async {
    if (_signingIn) return;
    if (widget.isRegistration && !widget.termsAccepted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Debes aceptar los términos y condiciones para continuar.',
            ),
          ),
        );
      }
      return;
    }
    if (!_registrationDataValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completa teléfono, oficio, especialidad, descripción y zona '
              'seleccionada antes de registrarte como trabajador.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _signingIn = true);
    try {
      await ref
          .read(authStateProvider.notifier)
          .signInWithGoogleToken(
            idToken,
            role: widget.role,
            acceptedTerms: widget.termsAccepted,
            isRegistration: widget.isRegistration,
            phone: widget.phone,
            city: widget.city,
            category: widget.category,
            subcategory: widget.subcategory,
            bio: widget.bio,
            latitude: widget.latitude,
            longitude: widget.longitude,
            displayName: displayName,
          );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_modoDemo) {
      return AppButton(
        label: 'Continuar con Google (demo)',
        icon: Icons.g_mobiledata,
        variant: AppButtonVariant.outline,
        onPressed:
            (widget.termsAccepted || !widget.isRegistration) &&
                _registrationDataValid
            ? () => ref
                  .read(authStateProvider.notifier)
                  .signInWithGoogle(
                    widget.role,
                    acceptedTerms: widget.termsAccepted,
                    isRegistration: widget.isRegistration,
                    phone: widget.phone,
                    city: widget.city,
                    category: widget.category,
                    subcategory: widget.subcategory,
                    bio: widget.bio,
                    latitude: widget.latitude,
                    longitude: widget.longitude,
                  )
            : null,
      );
    }

    if (kIsWeb) {
      if (_errorMessage != null) {
        return SizedBox(
          height: 44,
          child: Center(
            child: Text(_errorMessage!, textAlign: TextAlign.center),
          ),
        );
      }
      if (!_listo) {
        return const SizedBox(
          height: 44,
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        );
      }
      if (widget.isRegistration &&
          (!widget.termsAccepted || !_registrationDataValid)) {
        return const SizedBox(
          height: 44,
          child: Center(
            child: Text(
              'Completa los datos obligatorios y acepta los términos',
            ),
          ),
        );
      }
      return platform.buildWebGoogleButton();
    }

    return AppButton(
      label: widget.label,
      icon: Icons.g_mobiledata,
      variant: AppButtonVariant.outline,
      onPressed:
          (widget.termsAccepted || !widget.isRegistration) &&
              _registrationDataValid
          ? () => ref
                .read(authStateProvider.notifier)
                .signInWithGoogle(
                  widget.role,
                  acceptedTerms: widget.termsAccepted,
                  isRegistration: widget.isRegistration,
                  phone: widget.phone,
                  city: widget.city,
                  category: widget.category,
                  subcategory: widget.subcategory,
                  bio: widget.bio,
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                )
          : null,
    );
  }
}
