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
class ChargesListPage extends ConsumerStatefulWidget {
  const ChargesListPage({super.key});

  @override
  ConsumerState<ChargesListPage> createState() => _ChargesListPageState();
}

enum _WorkerChargeFilter { inProgress, unpaid, notified, received }

class _ChargesListPageState extends ConsumerState<ChargesListPage> {
  _WorkerChargeFilter _workerFilter = _WorkerChargeFilter.inProgress;

  @override
  Widget build(BuildContext context) {
    final isWorker = ref.watch(authStateProvider).role == UserRole.worker;
    if (PaymentsDemoConfig.enabled && !isWorker) {
      return const PaymentsDemoListPage();
    }
    final chargesAsync = ref.watch(chargesListProvider);

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
          if (isWorker) return _workerContent(context, ref, list);

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
                      _ChargeCard(charge: list[index], isWorker: false),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _workerContent(
    BuildContext context,
    WidgetRef ref,
    List<Charge> charges,
  ) {
    final received = charges.fold<double>(
      0,
      (sum, charge) => sum + charge.paidAmount,
    );
    final pending = charges
        .where((charge) => charge.status != ChargeStatus.paid)
        .fold<double>(0, (sum, charge) => sum + charge.pendingAmount);
    final filteredCharges = charges.where(_matchesWorkerFilter).toList();

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
                  label: 'Recibido',
                  value: Formatters.currency(received),
                  icon: Icons.account_balance_wallet_outlined,
                  color: ManoYaColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryCard(
                  label: 'Por recibir',
                  value: Formatters.currency(pending),
                  icon: Icons.hourglass_bottom,
                  color: ManoYaColors.warning,
                ),
              ),
            ],
          ),
        ),
        if (PaymentsDemoConfig.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: ManoYaColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: ManoYaColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'DEMO · Solicitudes y datos ficticios. No se mueve dinero.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final filter in _WorkerChargeFilter.values)
                  ChoiceChip(
                    label: Text(
                      '${filter.label} (${charges.where(filter.matches).length})',
                    ),
                    selected: _workerFilter == filter,
                    onSelected: (_) => setState(() => _workerFilter = filter),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filteredCharges.isEmpty
              ? EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: 'Sin ${_workerFilter.label.toLowerCase()}',
                  message: _workerFilter.emptyMessage,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  itemCount: filteredCharges.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) => _ChargeCard(
                    charge: filteredCharges[index],
                    isWorker: true,
                  ),
                ),
        ),
      ],
    );
  }

  bool _matchesWorkerFilter(Charge charge) => _workerFilter.matches(charge);
}

extension on _WorkerChargeFilter {
  String get label => switch (this) {
    _WorkerChargeFilter.inProgress => 'Trabajos en curso',
    _WorkerChargeFilter.unpaid => 'Clientes por pagar',
    _WorkerChargeFilter.notified => 'Pagos notificados',
    _WorkerChargeFilter.received => 'Pagos recibidos',
  };

  String get emptyMessage => switch (this) {
    _WorkerChargeFilter.inProgress => 'No tienes trabajos en curso.',
    _WorkerChargeFilter.unpaid => 'No hay clientes con pagos pendientes.',
    _WorkerChargeFilter.notified =>
      'No tienes pagos notificados por confirmar.',
    _WorkerChargeFilter.received => 'Aún no tienes pagos confirmados.',
  };

  bool matches(Charge charge) => switch (this) {
    _WorkerChargeFilter.inProgress => charge.status != ChargeStatus.paid,
    _WorkerChargeFilter.unpaid => charge.status == ChargeStatus.pending,
    _WorkerChargeFilter.notified =>
      charge.status == ChargeStatus.clientNotified,
    _WorkerChargeFilter.received => charge.status == ChargeStatus.paid,
  };
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
  final bool isWorker;

  const _ChargeCard({required this.charge, required this.isWorker});

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
                          '${isWorker ? 'Cliente' : 'Trabajador'}: '
                          '${isWorker ? charge.clientName : charge.workerName}',
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
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(
                    Formatters.currency(charge.total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isWorker
                        ? 'Recibido: ${Formatters.currency(charge.paidAmount)}'
                        : 'Pagado: ${Formatters.currency(charge.paidAmount)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ManoYaColors.success,
                    ),
                  ),
                ],
              ),
              if (charge.installments.length > 1) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Abonos: ${charge.installments.where((item) => item.paid).length} '
                  'de ${charge.installments.length} cuotas · '
                  'Por recibir: ${Formatters.currency(charge.pendingAmount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ManoYaColors.muted,
                  ),
                ),
              ],
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
