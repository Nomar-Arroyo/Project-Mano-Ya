import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/async_state_views.dart';
import '../../domain/charge.dart';
import '../billing_provider.dart';
import '../payments_demo_config.dart';
import 'charge_detail_page.dart';
import 'charge_form_page.dart';
import 'payments_demo_list_page.dart';
import '../widgets/charge_status_chip.dart';

/// Lista de solicitudes de cobro/pagos. El trabajador puede crear nuevas;
/// ambos roles pueden abrir el detalle para notificar o confirmar el pago.
class ChargesListPage extends ConsumerWidget {
  const ChargesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PaymentsDemoConfig.enabled) return const PaymentsDemoListPage();

    final chargesAsync = ref.watch(chargesListProvider);
    final isWorker = ref.watch(authStateProvider).role == UserRole.worker;

    return Scaffold(
      appBar: AppBar(title: Text(isWorker ? 'Cobros' : 'Mis pagos')),
      floatingActionButton: isWorker
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChargeFormPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo cobro'),
            )
          : null,
      body: chargesAsync.when(
        loading: () => const LoadingView(message: 'Cargando cobros...'),
        error: (error, stackTrace) => ErrorView(
          message: 'No se pudieron cargar los cobros',
          onRetry: () => ref.invalidate(chargesListProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'Sin cobros todavía',
              message: isWorker
                  ? 'Crea tu primera solicitud con el botón "Nuevo cobro".'
                  : 'Cuando te generen un cobro aparecerá aquí.',
            );
          }
          final total = list.fold<double>(0, (sum, c) => sum + c.total);
          final pending = list.fold<double>(
            0,
            (sum, c) => sum + c.pendingAmount,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: isWorker ? 'Total facturado' : 'Total',
                        value: Formatters.currency(total),
                        icon: Icons.account_balance_wallet_outlined,
                        color: ManoYaColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Por pagar',
                        value: Formatters.currency(pending),
                        icon: Icons.hourglass_bottom,
                        color: ManoYaColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) =>
                      _ChargeCard(charge: list[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tarjeta de resumen (total / por pagar).
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: ManoYaColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta resumen de una solicitud de cobro.
class _ChargeCard extends StatelessWidget {
  final Charge charge;

  const _ChargeCard({required this.charge});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: ManoYaColors.border),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChargeDetailPage(chargeId: charge.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: ManoYaColors.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: ManoYaColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          charge.concept,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cliente: ${charge.clientName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ManoYaColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ChargeStatusChip(status: charge.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(charge.total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Pagado: ${Formatters.currency(charge.paidAmount)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ManoYaColors.success,
                    ),
                  ),
                  const Spacer(),
                  if (charge.hasInstallments)
                    Text(
                      '${charge.installments.length} cuotas',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ManoYaColors.muted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: charge.total == 0
                      ? 0
                      : (charge.paidAmount / charge.total).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: ManoYaColors.border,
                  valueColor: const AlwaysStoppedAnimation(
                    ManoYaColors.success,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Creado el ${Formatters.date(charge.createdAt)}',
                style: const TextStyle(fontSize: 11, color: ManoYaColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
