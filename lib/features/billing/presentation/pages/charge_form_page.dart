import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../billing_provider.dart';

/// Plan de pago elegido por el trabajador al crear una solicitud de cobro.
enum PaymentPlan { single, two, four, biweekly }

/// Formulario donde el trabajador crea una solicitud de cobro: concepto,
/// cliente, monto total, datos bancarios/pago móvil y plan de cuotas/hitos.
class ChargeFormPage extends ConsumerStatefulWidget {
  const ChargeFormPage({super.key});

  @override
  ConsumerState<ChargeFormPage> createState() => _ChargeFormPageState();
}

class _ChargeFormPageState extends ConsumerState<ChargeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _conceptCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();

  PaymentPlan _plan = PaymentPlan.single;
  bool _saving = false;

  @override
  void dispose() {
    _conceptCtrl.dispose();
    _clientCtrl.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final workerName = ref.read(authStateProvider).displayName ?? 'Trabajador';
    await ref
        .read(billingRepositoryProvider)
        .create(
          concept: _conceptCtrl.text.trim(),
          workerName: workerName,
          clientName: _clientCtrl.text.trim(),
          total: _total,
          bankInfo: _bankCtrl.text.trim(),
          installmentCount: _installmentCount,
          spacingDays: _spacingDays,
        );
    ref.invalidate(chargesListProvider);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Solicitud de cobro creada')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Las cuotas se habilitan solo para proyectos grandes (> 800).
    final isLarge = _total > 800;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud de cobro')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _conceptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Concepto del trabajo',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _clientCtrl,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Monto total',
                    prefixText: '\$ ',
                  ),
                  validator: (v) {
                    final value = double.tryParse(v?.trim() ?? '');
                    if (value == null || value <= 0) return 'Monto inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bankCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Datos bancarios / pago móvil',
                    hintText: 'Banco, tipo de cuenta, número y/o pago móvil',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Plan de pago',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Para proyectos mayores a \$800 se habilitan las cuotas.',
                  style: TextStyle(fontSize: 12, color: ManoYaColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _planChip('Pago único', PaymentPlan.single, true),
                    _planChip('2 cuotas', PaymentPlan.two, isLarge),
                    _planChip('4 cuotas', PaymentPlan.four, isLarge),
                    _planChip('Quincenal', PaymentPlan.biweekly, isLarge),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Crear solicitud de cobro'),
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
