import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/models/user_role.dart';
import '../../domain/charge.dart';
import '../billing_provider.dart';
import 'charge_detail_page.dart';
import 'charge_form_page.dart';

/// Lista de solicitudes de cobro. El trabajador puede crear nuevas; ambos
/// roles pueden abrir el detalle para notificar o confirmar el pago.
class ChargesListPage extends ConsumerWidget {
  const ChargesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('Error al cargar cobros')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No hay cobros registrados todavía'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _ChargeCard(charge: list[index]),
          );
        },
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChargeDetailPage(chargeId: charge.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      charge.concept,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _StatusChip(status: charge.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Trabajador: ${charge.workerName}',
                style: const TextStyle(fontSize: 12, color: ManoYaColors.muted),
              ),
              Text(
                'Cliente: ${charge.clientName}',
                style: const TextStyle(fontSize: 12, color: ManoYaColors.muted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '\$ ${charge.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pagado: \$ ${charge.paidAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ManoYaColors.success,
                    ),
                  ),
                ],
              ),
              if (charge.hasInstallments)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Pago en cuotas',
                    style: TextStyle(fontSize: 11, color: ManoYaColors.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de estado del cobro.
class _StatusChip extends StatelessWidget {
  final ChargeStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _presentation(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, String) _presentation(ChargeStatus status) {
    switch (status) {
      case ChargeStatus.pending:
        return (ManoYaColors.warning, 'Pendiente');
      case ChargeStatus.clientNotified:
        return (ManoYaColors.primary, 'Por confirmar');
      case ChargeStatus.paid:
        return (ManoYaColors.success, 'Pagado');
    }
  }
}
