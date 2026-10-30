import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../shared/widgets/async_state_views.dart';
import '../../domain/auth_state.dart';
import '../auth_provider.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    final notifier = ref.read(authStateProvider.notifier);

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated) {
        context.go(next.twoFactorEnabled ? '/two-factor' : '/home');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifica tu correo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: state.loading ? null : () => context.go('/register'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 64,
                      color: ManoYaColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Código de verificación en tu correo',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Enviamos un código a ${widget.email}. Escríbelo aquí '
                      'para confirmar que el correo es tuyo y continuar.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Código de verificación',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: Validators.emailCode,
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      InlineMessage(
                        message: state.errorMessage!,
                        type: MessageType.error,
                      ),
                    ],
                    if (state.successMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      InlineMessage(
                        message: state.successMessage!,
                        type: MessageType.success,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: state.loading
                          ? null
                          : () {
                              if (!(_formKey.currentState?.validate() ??
                                  false)) {
                                return;
                              }
                              notifier.verifyEmailCode(
                                email: widget.email,
                                code: _codeController.text,
                              );
                            },
                      child: state.loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Verificar y continuar'),
                    ),
                    TextButton(
                      onPressed: state.loading
                          ? null
                          : () => notifier.resendEmailCode(widget.email),
                      child: const Text('Reenviar código'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
