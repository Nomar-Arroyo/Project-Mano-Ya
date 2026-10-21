import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../billing/domain/charge.dart';
import '../../../billing/presentation/billing_provider.dart';
import '../../../billing/presentation/pages/charge_detail_page.dart';
import '../../../jobs/presentation/jobs_provider.dart';
import '../../../jobs/presentation/pages/job_detail_page.dart';
import '../profile_provider.dart';

/// Pantalla de historial de servicios del cliente.
///
/// El mega-prompt pide que el perfil del cliente muestre el historial de
/// servicios con sus comprobantes. Aquí se listan los trabajos completados y
/// los recibos de pago generados en el módulo de cobros.
class ServiceHistoryPage extends ConsumerWidget {
  const ServiceHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final jobs = ref.watch(clientJobsProvider(userId));
    final charges = ref.watch(chargesListProvider);
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de servicios')),
      body: jobs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('No se pudo cargar el historial: $error')),
        data: (items) {
          final completed = items.where((job) => job.isFinished).toList()
            ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: surface,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Consulta los servicios que ya realizaste, sus '
                    'calificaciones y los comprobantes de pago.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Servicios realizados',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (completed.isEmpty)
                Card(
                  color: surface,
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Todavía no tienes servicios completados.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                ...completed.map(
                  (job) => Card(
                    color: surface,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ManoYaColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: ManoYaColors.success,
                        ),
                      ),
                      title: Text(
                        job.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${job.workerName} · '
                        '${DateFormat('dd/MM/yyyy').format(job.scheduledAt)}\n'
                        '${Formatters.currency(job.price)}'
                        '${job.rating != null ? ' · ★ ${job.rating!.toStringAsFixed(1)}' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JobDetailPage(jobId: job.id),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Comprobantes de pago',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              charges.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Text('No se pudieron cargar los comprobantes: $error'),
                data: (items2) {
                  if (items2.isEmpty) {
                    return Card(
                      color: surface,
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Aún no hay comprobantes de pago.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: items2
                        .map((charge) => _ChargeTile(charge: charge))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tarjeta de un comprobante de pago con acceso al detalle y al recibo PDF.
class _ChargeTile extends ConsumerWidget {
  final Charge charge;

  const _ChargeTile({required this.charge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = Theme.of(context).colorScheme.surface;
    return Card(
      color: surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(
          charge.concept,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${charge.statusLabel} · ${Formatters.currency(charge.total)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChargeDetailPage(chargeId: charge.id),
          ),
        ),
      ),
    );
  }
}
