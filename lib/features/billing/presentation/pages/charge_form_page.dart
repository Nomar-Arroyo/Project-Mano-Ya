import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../billing_provider.dart';

/// Plan de pago elegido por el trabajador al crear una solicitud de cobro.
enum PaymentPlan { single, two, four, biweekly }

/// Formulario donde el trabajador crea una solicitud de cobro: concepto,
/// cliente (con correo para enviar el recibo), monto total, datos bancarios
/// y plan de cuotas/hitos.
class ChargeFormPage extends ConsumerStatefulWidget {
  const ChargeFormPage({super.key});

  @override
  ConsumerState<ChargeFormPage> createState() => _ChargeFormPageState();
}

class _ChargeFormPageState extends ConsumerState<ChargeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _conceptCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();

  PaymentPlan _plan = PaymentPlan.single;
  bool _saving = false;

  @override
  void dispose() {
    _conceptCtrl.dispose();
    _clientCtrl.dispose();
    _emailCtrl.dispose();
    _amountCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  /// Monto actualmente escrito en el campo (0 si no es válido).
  double get _total => double.tryParse(_amountCtrl.text.trim()) ?? 0;

  /// Número de cuotas del plan seleccionado.
  int get _installmentCount {
    switch (_plan) {
      case PaymentPlan.single:
        return 1;
      case PaymentPlan.two:
        return 2;
      case PaymentPlan.four:
      case PaymentPlan.biweekly:
        return 4;
    }
  }

  /// Separación en días entre cuotas (quincenal = 15, resto = 30).
  int get _spacingDays => _plan == PaymentPlan.biweekly ? 15 : 30;

  /// El correo del cliente es opcional, pero si se escribe debe ser válido.
  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return Validators.email(value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final workerName = ref.read(authStateProvider).displayName ?? 'Trabajador';
    final email = _emailCtrl.text.trim();
    await ref
        .read(billingRepositoryProvider)
        .create(
          concept: _conceptCtrl.text.trim(),
          workerName: workerName,
          clientName: _clientCtrl.text.trim(),
          clientEmail: email.isEmpty ? null : email,
          total: _total,
          bankInfo: _bankCtrl.text.trim(),
          installmentCount: _installmentCount,
          spacingDays: _spacingDays,
        );
    ref.invalidate(chargesListProvider);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solicitud de cobro creada'),
        backgroundColor: ManoYaColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud de cobro')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _conceptCtrl,
                  label: 'Concepto del trabajo',
                  hint: 'Ej: Instalación eléctrica',
                  prefixIcon: Icons.work_outline,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      Validators.required(v, message: 'Ingresa el concepto'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _clientCtrl,
                  label: 'Nombre del cliente',
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  enabled: !_saving,
                  validator: (v) => Validators.required(
                    v,
                    message: 'Ingresa el nombre del cliente',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _emailCtrl,
                  label: 'Correo del cliente',
                  hint: 'cliente@correo.com (opcional)',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_saving,
                  validator: _emailValidator,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _amountCtrl,
                  label: 'Monto total',
                  hint: 'Ej: 250000',
                  prefixIcon: Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  enabled: !_saving,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final total = double.tryParse((v ?? '').trim());
                    if (total == null || total <= 0) {
                      return 'Ingresa un monto válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _bankCtrl,
                  label: 'Datos bancarios / pago móvil',
                  hint: 'Banco, tipo y número de cuenta y/o pago móvil',
                  prefixIcon: Icons.account_balance_outlined,
                  maxLines: 3,
                  enabled: !_saving,
                  validator: (v) => Validators.required(
                    v,
                    message: 'Ingresa los datos de pago',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Plan de pago',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Para proyectos mayores a \$800 se habilitan las cuotas.',
                  style: TextStyle(fontSize: 12, color: ManoYaColors.muted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _planChip('Pago único', PaymentPlan.single, true),
                    _planChip('2 cuotas', PaymentPlan.two, _total > 800),
                    _planChip('4 cuotas', PaymentPlan.four, _total > 800),
                    _planChip('Quincenal', PaymentPlan.biweekly, _total > 800),
                  ],
                ),
                if (_total > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _PlanPreview(
                    total: _total,
                    count: _installmentCount,
                    spacingDays: _spacingDays,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Crear solicitud de cobro',
                  icon: Icons.receipt_long,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Chip seleccionable para elegir el plan de pago. Si las cuotas no están
  /// permitidas (monto <= 800), el chip se muestra deshabilitado.
  Widget _planChip(String label, PaymentPlan plan, bool enabled) {
    return ChoiceChip(
      label: Text(label),
      selected: enabled && _plan == plan,
      onSelected: enabled ? (_) => setState(() => _plan = plan) : null,
    );
  }
}

/// Vista previa del desglose del plan de pago elegido.
class _PlanPreview extends StatelessWidget {
  final double total;
  final int count;
  final int spacingDays;

  const _PlanPreview({
    required this.total,
    required this.count,
    required this.spacingDays,
  });

  @override
  Widget build(BuildContext context) {
    final base = total / count;
    final text = count <= 1
        ? 'Pago único de ${Formatters.currency(total)}.'
        : '$count cuotas de ~${Formatters.currency(base)} cada $spacingDays días.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ManoYaColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: ManoYaColors.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: ManoYaColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
