import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/venezuelan_phone_input_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/async_state_views.dart';
import '../../../shared/widgets/city_autocomplete_field.dart';
import '../../../shared/widgets/or_divider.dart';
import '../../../shared/models/user_role.dart';
import '../../domain/auth_state.dart';
import '../auth_provider.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/role_selector.dart';
import '../widgets/terms_acceptance_field.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _cityName;
  UserRole _role = UserRole.client;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_acceptedTerms) return;
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authStateProvider.notifier)
        .register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          role: _role,
          acceptedTerms: _acceptedTerms,
          phone: VenezuelanPhoneInputFormatter.formatInternational(
            _phoneCtrl.text,
          ),
          city: _cityName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);

    ref.listen<AuthState>(authStateProvider, (prev, next) {
      final wasAuthenticated = prev?.isAuthenticated ?? false;
      if (next.isAuthenticated && !wasAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta creada correctamente'),
            backgroundColor: ManoYaColors.success,
          ),
        );
        context.go('/home');
      } else if (next.successMessage != null) {
        context.go('/verify-email', extra: _emailCtrl.text.trim());
      }
    });

    return AuthScaffold(
      title: 'Crea tu cuenta',
      subtitle: 'Únete a Mano Ya en menos de un minuto',
      form: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RoleSelector(
              value: _role,
              enabled: !state.loading,
              onChanged: (r) => setState(() => _role = r),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _nameCtrl,
              label: 'Nombre completo',
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              enabled: !state.loading,
              validator: Validators.fullName,
              onChanged: (_) =>
                  ref.read(authStateProvider.notifier).clearError(),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _emailCtrl,
              label: 'Correo electrónico',
              hint: 'tucorreo@ejemplo.com',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !state.loading,
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
              enabled: !state.loading,
              textInputAction: TextInputAction.next,
              validator: Validators.password,
              onChanged: (_) =>
                  ref.read(authStateProvider.notifier).clearError(),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _phoneCtrl,
              label: 'Teléfono',
              hint: '412 123 4567',
              prefixIcon: Icons.phone_outlined,
              prefixText: '+58 ',
              inputFormatters: const [VenezuelanPhoneInputFormatter()],
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              enabled: !state.loading,
              validator: Validators.phone,
              onChanged: (_) =>
                  ref.read(authStateProvider.notifier).clearError(),
            ),
            const SizedBox(height: AppSpacing.md),
            // Zona/ciudad con autocompletado geolocalizado (Nominatim).
            CityAutocompleteField(
              label: 'Ciudad/Zona',
              initialText: _cityName,
              onSelected: (place) => _cityName = place.displayName,
              onCleared: () => _cityName = null,
            ),
            if (_role == UserRole.worker) ...[
              const SizedBox(height: AppSpacing.md),
              const _WorkerInfoCard(),
            ],
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
            const SizedBox(height: AppSpacing.md),
            TermsAcceptanceField(
              value: _acceptedTerms,
              enabled: !state.loading,
              onChanged: (value) => setState(() => _acceptedTerms = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Crear cuenta',
              icon: Icons.person_add_alt_1,
              loading: state.loading,
              onPressed: _acceptedTerms ? _submit : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            const OrDivider(),
            const SizedBox(height: AppSpacing.lg),
            GoogleSignInButton(
              role: _role,
              label: 'Registrarme con Google',
              termsAccepted: _acceptedTerms,
            ),
          ],
        ),
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('¿Ya tienes cuenta?'),
          TextButton(
            onPressed: state.loading ? null : () => context.go('/login'),
            child: const Text('Inicia sesión'),
          ),
        ],
      ),
    );
  }
}

/// Aviso informativo mostrado cuando el rol seleccionado es Trabajador.
class _WorkerInfoCard extends StatelessWidget {
  const _WorkerInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ManoYaColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: ManoYaColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.construction, color: ManoYaColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perfil de Trabajador',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Elige tu oficio y zona desde tu perfil. Podrás activar tu '
                  'disponibilidad y recibir solicitudes de clientes cercanos.',
                  style: TextStyle(fontSize: 13, color: ManoYaColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
