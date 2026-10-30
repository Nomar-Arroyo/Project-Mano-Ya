import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';

class CookieNotice extends StatefulWidget {
  const CookieNotice({
    required this.child,
    required this.onOpenPolicy,
    this.enabled = kIsWeb,
    super.key,
  });

  final Widget child;
  final VoidCallback onOpenPolicy;
  final bool enabled;

  @override
  State<CookieNotice> createState() => _CookieNoticeState();
}

class _CookieNoticeState extends State<CookieNotice> {
  static const _acknowledgedKey = 'cookie_notice_acknowledged_v1';

  bool _expanded = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _loadAcknowledgement();
  }

  Future<void> _loadAcknowledgement() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final acknowledged = preferences.getBool(_acknowledgedKey) ?? false;
      if (!mounted) return;
      setState(() {
        _expanded = !acknowledged;
      });
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'cookie notice',
          context: ErrorDescription('while loading the cookie notice state'),
        ),
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo consultar la preferencia. El aviso permanecerá visible.';
      });
    }
  }

  Future<void> _acknowledgeNotice() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setBool(_acknowledgedKey, true);
      if (!saved) throw StateError('No se pudo guardar la preferencia.');
      if (!mounted) return;
      setState(() {
        _expanded = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'cookie notice',
          context: ErrorDescription('while saving the cookie notice state'),
        ),
      );
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo guardar el estado del aviso. Inténtalo nuevamente.';
      });
    }
  }

  void _openPolicy() {
    setState(() => _expanded = false);
    widget.onOpenPolicy();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_expanded) _buildNotice(context) else _buildShortcut(context),
      ],
    );
  }

  Widget _buildNotice(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 12,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final content = _buildMessage(context);
                  final actions = _buildActions(context);
                  if (constraints.maxWidth < 620) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        content,
                        const SizedBox(height: AppSpacing.md),
                        actions,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: content),
                      const SizedBox(width: AppSpacing.lg),
                      actions,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Uso de cookies y almacenamiento',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Usamos almacenamiento técnico para mantener tu sesión y recordar '
          'preferencias. Esta versión no activa cookies propias de publicidad '
          'ni analítica.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (_errorMessage case final message?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        TextButton(
          onPressed: _openPolicy,
          child: const Text('Política de cookies'),
        ),
        FilledButton(
          onPressed: _acknowledgeNotice,
          style: FilledButton.styleFrom(
            backgroundColor: ManoYaColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Entendido'),
        ),
      ],
    );
  }

  Widget _buildShortcut(BuildContext context) {
    return Positioned(
      right: AppSpacing.md,
      bottom: AppSpacing.md,
      child: SafeArea(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 6,
          borderRadius: BorderRadius.circular(24),
          child: TextButton.icon(
            onPressed: () => setState(() => _expanded = true),
            icon: const Icon(Icons.cookie_outlined),
            label: const Text('Cookies'),
          ),
        ),
      ),
    );
  }
}
