import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Estructura compartida para las pantallas de autenticación.
///
/// En pantallas anchas (web/tablet) muestra el diseño split-screen con el
/// panel de marca a la izquierda y el formulario a la derecha. En pantallas
/// angostas (móvil) apila un banner de marca sobre el formulario.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.splitScreen;
          if (isWide) {
            return Row(
              children: [
                const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(
                  flex: 4,
                  child: _FormPanel(
                    title: title,
                    subtitle: subtitle,
                    form: form,
                    footer: footer,
                  ),
                ),
              ],
            );
          }
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const _BrandPanel(compact: true),
                  _FormPanel(
                    title: title,
                    subtitle: subtitle,
                    form: form,
                    footer: footer,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Panel de marca con degradado azul (paleta ITSU).
class _BrandPanel extends StatelessWidget {
  final bool compact;

  const _BrandPanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: compact ? 200 : double.infinity,
      decoration: BoxDecoration(
        gradient: ManoYaColors.brandGradient,
        borderRadius: compact
            ? const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl))
            : null,
      ),
      child: Stack(
        children: [
          const _DecoCircle(top: -60, right: -40, size: 220, opacity: 0.10),
          const _DecoCircle(bottom: -70, left: -50, size: 260, opacity: 0.08),
          const _DecoCircle(top: 130, left: -30, size: 120, opacity: 0.12),
          Padding(
            padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
            child: compact
                ? const _BrandHeader(compact: true)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FadeSlideIn(child: const _BrandHeader()),
                      const SizedBox(height: AppSpacing.xxl),
                      _FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: const _FeatureList(),
                      ),
                      const Spacer(),
                      Text(
                        '© ${DateTime.now().year} Mano Ya · Proyecto ITSU',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Logo + nombre + eslogan.
class _BrandHeader extends StatelessWidget {
  final bool compact;

  const _BrandHeader({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 48.0 : 60.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: logoSize,
          width: logoSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Icon(
            Icons.handyman,
            color: Colors.white,
            size: compact ? 26 : 32,
          ),
        ),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        Text(
          'Mano Ya',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 26 : 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tus Oficios a la Mano',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: compact ? 14 : 15,
          ),
        ),
      ],
    );
  }
}

/// Lista de beneficios mostrada en el panel de marca (solo escritorio).
class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const List<_FeatureData> _features = [
    _FeatureData(
      icon: Icons.location_on,
      text: 'Encuentra profesionales cerca de tu zona',
    ),
    _FeatureData(
      icon: Icons.verified_user,
      text: 'Identidad verificada y trabajo garantizado',
    ),
    _FeatureData(icon: Icons.chat, text: 'Contacto directo por WhatsApp'),
    _FeatureData(
      icon: Icons.receipt_long,
      text: 'Pagos por cuotas con recibo en PDF',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final feature in _features)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(feature.icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    feature.text,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String text;
  const _FeatureData({required this.icon, required this.text});
}

/// Panel con el formulario, centrado y con animación de entrada.
class _FormPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;

  const _FormPanel({
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.formMaxWidth,
            ),
            child: _FadeSlideIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: ManoYaColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  form,
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo decorativo translúcido para el panel de marca.
class _DecoCircle extends StatelessWidget {
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double size;
  final double opacity;

  const _DecoCircle({
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.size,
    this.opacity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

/// Animación de entrada (fade + deslizamiento) reutilizable.
class _FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;

  const _FadeSlideIn({required this.child, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.slow + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 24),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
