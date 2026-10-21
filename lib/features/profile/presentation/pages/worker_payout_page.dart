import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../domain/worker_profile.dart';
import '../profile_provider.dart';

/// Pantalla de datos financieros de cobro del trabajador.
///
/// El mega-prompt pide "Configuración de cuentas bancarias o métodos de pago
/// preferidos" como parte del perfil del trabajador. La información se guarda
/// en la tabla `profiles` (columnas `payout_*`) cuando Supabase está
/// configurado y en memoria mientras tanto.
class WorkerPayoutPage extends ConsumerStatefulWidget {
  const WorkerPayoutPage({super.key});

  @override
  ConsumerState<WorkerPayoutPage> createState() => _WorkerPayoutPageState();
}

class _WorkerPayoutPageState extends ConsumerState<WorkerPayoutPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _holderCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _bankCtrl;
  String _method = '';
  bool _saving = false;

  /// Métodos de pago ofrecidos en Colombia.
  static const List<String> methods = [
    'Nequi',
    'Daviplata',
    'Transferencia bancaria',
    'PSE',
    'Efectivo',
  ];

  @override
  void initState() {
    super.initState();
    _holderCtrl = TextEditingController();
    _numberCtrl = TextEditingController();
    _bankCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _numberCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  /// Carga los datos ya guardados cuando el perfil llega de la base de datos.
  void _hydrate(PayoutInfo payout) {
    if (_holderCtrl.text.isNotEmpty || _numberCtrl.text.isNotEmpty) return;
    _holderCtrl.text = payout.accountHolder;
    _numberCtrl.text = payout.accountNumber;
    _bankCtrl.text = payout.bankName ?? '';
    if (payout.method.isNotEmpty) _method = payout.method;
  }

  /// Guarda la configuración de cobro.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref
        .read(profileControllerProvider.notifier)
        .savePayout(
          PayoutInfo(
            method: _method,
            accountHolder: _holderCtrl.text.trim(),
            accountNumber: _numberCtrl.text.trim(),
            bankName:
                _method == 'Transferencia bancaria' &&
                    _bankCtrl.text.trim().isNotEmpty
                ? _bankCtrl.text.trim()
                : null,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos de cobro actualizados')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(workerProfileProvider);
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(title: const Text('Datos de cobro')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('No se pudo cargar el perfil: $error')),
        data: (data) {
          _hydrate(data.payout);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¿Cómo quieres recibir el dinero?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Así los clientes saben dónde pagar tus servicios y '
                          'tú recibes tus cobros sin intermediarios ni '
                          'complicaciones.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _method.isEmpty ? null : _method,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago preferido',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  items: methods
                      .map(
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        ),
                      )
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Selecciona un método de pago' : null,
                  onChanged: (value) => setState(() => _method = value ?? ''),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _holderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titular de la cuenta',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Requerido'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _numberCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Número de cuenta o celular',
                    prefixIcon: Icon(Icons.dialpad),
                  ),
                  validator: (value) => value == null || value.trim().length < 4
                      ? 'Ingresa un número válido'
                      : null,
                ),
                if (_method == 'Transferencia bancaria') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bankCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Banco',
                      prefixIcon: Icon(Icons.account_balance_outlined),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar datos de cobro'),
                ),
                const SizedBox(height: 16),
                if (data.payout.isConfigured)
                  Card(
                    color: surface,
                    child: ListTile(
                      leading: const Icon(
                        Icons.verified_user_outlined,
                        color: ManoYaColors.success,
                      ),
                      title: const Text('Configuración activa'),
                      subtitle: Text(
                        '${data.payout.method} · ****'
                        '${_mask(data.payout.accountNumber)}',
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Oculta todos los dígitos salvo los últimos cuatro.
  String _mask(String value) {
    if (value.length <= 4) return value;
    return value.substring(value.length - 4);
  }
}
