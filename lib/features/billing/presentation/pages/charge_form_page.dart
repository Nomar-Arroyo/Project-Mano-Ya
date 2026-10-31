import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../shared/widgets/async_state_views.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../domain/billable_job.dart';
import '../billing_provider.dart';

/// Plan de pago elegido por el trabajador al crear una solicitud de cobro.
enum PaymentPlan { single, two, four, biweekly }

/// Formulario de cobro asociado a un trabajo real.
class ChargeFormPage extends ConsumerStatefulWidget {
  const ChargeFormPage({super.key});

  @override
  ConsumerState<ChargeFormPage> createState() => _ChargeFormPageState();
}

class _ChargeFormPageState extends ConsumerState<ChargeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _conceptCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();

  String? _selectedJobId;
  PaymentPlan _plan = PaymentPlan.single;
  bool _saving = false;

  @override
  void dispose() {
    _conceptCtrl.dispose();
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
    final jobId = _selectedJobId;
    if (jobId == null) return;
    setState(() => _saving = true);

    try {
      await ref
          .read(billingRepositoryProvider)
          .create(
            jobId: jobId,
            concept: _conceptCtrl.text.trim(),
            total: _total,
            bankInfo: _bankCtrl.text.trim(),
            installmentCount: _installmentCount,
            spacingDays: _spacingDays,
          );
      ref.invalidate(chargesListProvider);
      ref.invalidate(billableJobsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud de cobro creada'),
          backgroundColor: ManoYaColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear el cobro: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(billableJobsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud de cobro')),
      body: jobsAsync.when(
        loading: () => const LoadingView(message: 'Cargando trabajos...'),
        error: (error, stackTrace) => ErrorView(
          message: 'No se pudieron cargar los trabajos',
          onRetry: () => ref.invalidate(billableJobsProvider),
        ),
        data: (jobs) => jobs.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Necesitas un trabajo aceptado, en curso o completado '
                    'para crear un cobro.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _buildForm(jobs, isDemo: SupabaseService.client == null),
      ),
    );
  }

  Widget _buildForm(List<BillableJob> jobs, {required bool isDemo}) {
    final selectedJob = jobs.where((job) => job.id == _selectedJobId);
    final selectedJobId = jobs.any((job) => job.id == _selectedJobId)
        ? _selectedJobId
        : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDemo) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: ManoYaColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: ManoYaColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'DEMO · Este cobro solo se guarda en memoria.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              DropdownButtonFormField<String>(
                initialValue: selectedJobId,
                decoration: const InputDecoration(
                  labelText: 'Trabajo',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                items: jobs
                    .map(
                      (job) => DropdownMenuItem(
                        value: job.id,
                        child: Text(
                          '${job.title} · ${job.clientName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _selectedJobId = value),
                validator: (value) =>
                    value == null ? 'Selecciona un trabajo' : null,
              ),
              if (selectedJob.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Cliente: ${selectedJob.first.clientName}',
                  style: const TextStyle(color: ManoYaColors.muted),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _conceptCtrl,
                label: 'Concepto del cobro',
                hint: 'Ej: Anticipo de instalación eléctrica',
                prefixIcon: Icons.receipt_long_outlined,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    Validators.required(v, message: 'Ingresa el concepto'),
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
