import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/async_state_views.dart';
import '../../../shared/widgets/or_divider.dart';
import '../../domain/auth_state.dart';
import '../auth_provider.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/role_selector.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.client;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authStateProvider.notifier)
        .loginEmail(
          _emailCtrl.text.trim(),
          _passCtrl.text,
          role: _selectedRole,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    final loading = state.loading;

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      if (next.isAuthenticated && !wasAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión iniciada correctamente'),
            backgroundColor: ManoYaColors.success,
          ),
        );
        // Si el usuario tiene 2FA activo pasa primero por la verificación.
        context.go(next.twoFactorEnabled ? '/two-factor' : '/home');
      }
    });

    return AuthScaffold(
      title: 'Bienvenido de nuevo',
      subtitle: 'Inicia sesión en Mano Ya para continuar',
      form: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RoleSelector(
              value: _selectedRole,
              enabled: !loading,
              onChanged: (r) => setState(() => _selectedRole = r),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _emailCtrl,
              label: 'Correo electrónico',
              hint: 'tucorreo@ejemplo.com',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !loading,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
              onChanged: (_) =>
                  ref.read(authStateProvider.notifier).clearError(),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _passCtrl,
              label: 'Contraseña',
              prefixIcon: Icons.lock_outline,
              obscure: true,
              enabled: !loading,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: Validators.password,
              onFieldSubmitted: (_) => _submit(),
              onChanged: (_) =>
                  ref.read(authStateProvider.notifier).clearError(),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              InlineMessage(
                message: state.errorMessage!,
                type: MessageType.error,
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: loading
                    ? null
                    : () => context.push(
                        '/forgot-password',
                        extra: _emailCtrl.text.trim().isEmpty
                            ? null
                            : _emailCtrl.text.trim(),
                      ),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
            AppButton(
              label: 'Iniciar sesión',
              icon: Icons.login,
              loading: loading,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            const OrDivider(),
            const SizedBox(height: AppSpacing.lg),
            GoogleSignInButton(role: _selectedRole),
          ],
        ),
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('¿No tienes cuenta?'),
          TextButton(
            onPressed: loading ? null : () => context.push('/register'),
            child: const Text('Regístrate'),
          ),
        ],
      ),
    );
  }
}
