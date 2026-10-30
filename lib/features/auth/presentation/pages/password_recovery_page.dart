import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/async_state_views.dart';
import '../../domain/password_recovery_state.dart';
import '../auth_provider.dart';
import '../widgets/auth_scaffold.dart';

/// Recuperación de contraseña en tres pasos: correo, código y contraseña.
///
/// Usa el SMTP configurado en Supabase Auth, el mismo que envía el código de
/// verificación del registro.
class PasswordRecoveryPage extends ConsumerStatefulWidget {
  const PasswordRecoveryPage({super.key, this.initialEmail});

  /// Correo que la persona ya había escrito en el inicio de sesión.
  final String? initialEmail;

  @override
  ConsumerState<PasswordRecoveryPage> createState() =>
      _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends ConsumerState<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  /// Permite que el router cierre la ruta. Mientras es falso, el retroceso
  /// del sistema entra en [PopScope] y esta pantalla decide el paso.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail ?? '';
    // Cada entrada a la pantalla empieza el flujo desde el correo.
    ref.read(passwordRecoveryProvider.notifier).reset();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit(PasswordRecoveryNotifier notifier, PasswordRecoveryState state) {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    switch (state.step) {
      case PasswordRecoveryStep.email:
        notifier.requestCode(_emailCtrl.text);
      case PasswordRecoveryStep.code:
        notifier.verifyCode(_codeCtrl.text.trim());
      case PasswordRecoveryStep.password:
        _savePassword(notifier);
    }
  }

  Future<void> _savePassword(PasswordRecoveryNotifier notifier) async {
    final updated = await notifier.updatePassword(_passCtrl.text);
    if (!mounted || !updated) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contraseña actualizada. Inicia sesión con la nueva.'),
        backgroundColor: ManoYaColors.success,
      ),
    );
    _leave();
  }

  Future<void> _resend(PasswordRecoveryNotifier notifier) async {
    final sent = await notifier.resendCode();
    if (!mounted || !sent) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Enviamos otro código.')));
  }

  /// Retrocede un paso. Al abandonar después de verificar el código se cierra
  /// la sesión temporal que abrió Supabase.
  Future<void> _back(
    PasswordRecoveryNotifier notifier,
    PasswordRecoveryState state,
  ) async {
    if (state.loading || _leaving) return;
    switch (state.step) {
      case PasswordRecoveryStep.email:
        await _leave();
      case PasswordRecoveryStep.code:
        notifier.backToEmail();
      case PasswordRecoveryStep.password:
        await _leave(after: notifier.cancel);
    }
  }

  /// Cierra esta ruta. [PopScope] rechaza el pop mientras [canPop] es falso,
  /// así que primero se habilita la salida y el pop ocurre en el siguiente
  /// frame. [after] corre antes de salir, por ejemplo para cerrar la sesión
  /// temporal del código ya verificado.
  Future<void> _leave({Future<void> Function()? after}) async {
    if (!mounted || _leaving) return;
    setState(() => _leaving = true);
    if (after != null) await after();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordRecoveryProvider);
    final notifier = ref.read(passwordRecoveryProvider.notifier);

    final (title, subtitle) = switch (state.step) {
      PasswordRecoveryStep.email => (
        'Recupera tu contraseña',
        'Escribe el correo de tu cuenta y te enviaremos un código para '
            'restablecerla.',
      ),
      PasswordRecoveryStep.code => (
        'Revisa tu correo',
        'Enviamos un código a ${state.email}. Escríbelo para '
            'continuar. Si no llega, revisa la carpeta de spam.',
      ),
      PasswordRecoveryStep.password => (
        'Crea una contraseña nueva',
        'El código se verificó correctamente. Elige una contraseña que no '
            'hayas usado antes.',
      ),
    };

    if (_leaving) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(notifier, state);
      },
      child: AuthScaffold(
        title: title,
        subtitle: subtitle,
        form: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._stepFields(state),
              if (state.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                InlineMessage(
                  message: state.errorMessage!,
                  type: MessageType.error,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: switch (state.step) {
                  PasswordRecoveryStep.email => 'Enviar código',
                  PasswordRecoveryStep.code => 'Verificar código',
                  PasswordRecoveryStep.password => 'Guardar contraseña',
                },
                icon: switch (state.step) {
                  PasswordRecoveryStep.email => Icons.send_outlined,
                  PasswordRecoveryStep.code => Icons.verified_outlined,
                  PasswordRecoveryStep.password => Icons.lock_reset,
                },
                loading: state.loading,
                onPressed: () => _submit(notifier, state),
              ),
              if (state.step == PasswordRecoveryStep.code)
                TextButton(
                  onPressed: state.loading ? null : () => _resend(notifier),
                  child: const Text('Reenviar código'),
                ),
            ],
          ),
        ),
        footer: state.step == PasswordRecoveryStep.email
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿Ya tienes cuenta?'),
                  TextButton(
                    onPressed: state.loading ? null : _leave,
                    child: const Text('Inicia sesión'),
                  ),
                ],
              )
            : TextButton.icon(
                onPressed: state.loading ? null : () => _back(notifier, state),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(
                  state.step == PasswordRecoveryStep.password
                      ? 'Cancelar'
                      : 'Volver',
                ),
              ),
      ),
    );
  }

  /// Campos del formulario según el paso actual.
  List<Widget> _stepFields(PasswordRecoveryState state) {
    switch (state.step) {
      case PasswordRecoveryStep.email:
        return [
          AppTextField(
            controller: _emailCtrl,
            label: 'Correo electrónico',
            hint: 'tucorreo@ejemplo.com',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            enabled: !state.loading,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
            onFieldSubmitted: (_) =>
                _submit(ref.read(passwordRecoveryProvider.notifier), state),
            onChanged: (_) =>
                ref.read(passwordRecoveryProvider.notifier).clearError(),
          ),
        ];
      case PasswordRecoveryStep.code:
        return [
          TextFormField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 10,
            textAlign: TextAlign.center,
            enabled: !state.loading,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Código de recuperación',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            validator: Validators.emailCode,
            onFieldSubmitted: (_) =>
                _submit(ref.read(passwordRecoveryProvider.notifier), state),
            onChanged: (_) =>
                ref.read(passwordRecoveryProvider.notifier).clearError(),
          ),
        ];
      case PasswordRecoveryStep.password:
        return [
          AppTextField(
            controller: _passCtrl,
            label: 'Contraseña nueva',
            prefixIcon: Icons.lock_outline,
            obscure: true,
            enabled: !state.loading,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: Validators.password,
            onChanged: (_) =>
                ref.read(passwordRecoveryProvider.notifier).clearError(),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _confirmCtrl,
            label: 'Repite la contraseña',
            prefixIcon: Icons.lock_outline,
            obscure: true,
            enabled: !state.loading,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Repite la contraseña';
              }
              if (value != _passCtrl.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
            onFieldSubmitted: (_) =>
                _submit(ref.read(passwordRecoveryProvider.notifier), state),
            onChanged: (_) =>
                ref.read(passwordRecoveryProvider.notifier).clearError(),
          ),
        ];
    }
  }
}
