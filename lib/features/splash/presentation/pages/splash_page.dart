import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/presentation/auth_provider.dart';

/// Pantalla de bienvenida (splash) de **Mano Ya**.
///
/// Presenta el **logotipo oficial** del equipo sobre el degradado de marca con
/// una animación de entrada combinada de *fade-in* y *scale* (crecimiento
/// suave). La animación dura ~1,3 s y la pantalla permanece visible hasta
/// completar los ~2,3 s exigidos antes de navegar a la pantalla de
/// autenticación (o al home si ya existe una sesión restaurada).
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

/// Estado interno del splash: controla la animación y la navegación diferida.
class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  /// Controlador maestro de la animación de entrada.
  late final AnimationController _controller;

  /// Opacidad del logotipo (fade-in) durante la primera parte de la animación.
  late final Animation<double> _logoOpacity;

  /// Escala del logotipo: crece de 0.82 a 1.0 con un rebote suave.
  late final Animation<double> _logoScale;

  /// Opacidad del eslogan y del indicador de carga, con retardo visual.
  late final Animation<double> _taglineOpacity;

  /// Temporizador que ejecuta la navegación automática al terminar el splash.
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Duración de la animación principal (fade-in + escala del logotipo).
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    // El logo aparece progresivamente durante el primer 70% de la animación.
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    // Escala elástica: da sensación de "entrada con vida" al logotipo.
    _logoScale = Tween<double>(
      begin: 0.82,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    // El eslogan entra después que el logo para no saturar la pantalla.
    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeIn),
    );

    // Arranca la animación de entrada.
    _controller.forward();

    // Tras 2,3 s (dentro del rango pedido de 2 a 3 s) se navega.
    _navigationTimer = Timer(const Duration(milliseconds: 2300), _goNext);
  }

  /// Redirige al `home` si la sesión está activa o al `login` en caso contrario.
  void _goNext() {
    if (!mounted) return;
    final authenticated = ref.read(authStateProvider).isAuthenticated;
    context.go(authenticated ? '/home' : '/login');
  }

  @override
  void dispose() {
    // Se liberan el temporizador y el controlador para evitar fugas de memoria.
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // En tablets y web el logotipo se muestra a mayor tamaño.
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final logoSize = isWide ? 220.0 : 168.0;

    return Scaffold(
      // Fondo con el degradado institucional: el PNG del logo es transparente,
      // por lo que se renderiza correctamente tanto en claro como en oscuro.
      body: Container(
        decoration: const BoxDecoration(gradient: ManoYaColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logotipo oficial de Mano Ya con fade-in + escala.
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Image.asset(
                      'assets/icons/app_logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      // Accesibilidad: el lector de pantalla anuncia la marca.
                      semanticLabel: '${AppConfig.appName} - logotipo oficial',
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Eslogan oficial de la marca.
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: Text(
                    AppConfig.appTagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: isWide ? 18 : 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Indicador de progreso: comunica que la app está iniciando.
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
