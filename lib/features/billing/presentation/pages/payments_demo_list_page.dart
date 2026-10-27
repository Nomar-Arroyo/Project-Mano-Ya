import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../data/payments_demo_repository.dart';
import '../../domain/demo_payment.dart';
import 'payments_demo_page.dart';

class PaymentsDemoListPage extends ConsumerStatefulWidget {
  const PaymentsDemoListPage({super.key});

  @override
  ConsumerState<PaymentsDemoListPage> createState() =>
      _PaymentsDemoListPageState();
}

class _PaymentsDemoListPageState extends ConsumerState<PaymentsDemoListPage> {
  String _formatVes(int amountMinor) {
    final units = amountMinor ~/ 100;
    final groupedUnits = units.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]}.',
    );
    final cents = (amountMinor % 100).toString().padLeft(2, '0');
    return 'Bs. $groupedUnits,$cents';
  }

  Future<void> _openPayment(DemoPayment payment) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PaymentsDemoPage(paymentId: payment.id),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(paymentsDemoRepositoryProvider).payments;
    final pending = payments
        .where((payment) => payment.status == DemoPaymentStatus.pending)
        .toList();
    final paid = payments
        .where((payment) => payment.status == DemoPaymentStatus.paid)
        .toList();
    final pendingTotal = pending.fold<int>(
      0,
      (sum, payment) => sum + payment.split.totalMinor,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Cobros · Pagos pendientes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _demoNotice(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  label: 'Por pagar',
                  value: _formatVes(pendingTotal),
                  color: ManoYaColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  label: 'Solicitudes',
                  value: pending.length.toString(),
                  color: ManoYaColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Selecciona a quién pagar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            const _EmptyPayments(
              message: 'No hay pagos pendientes en esta demostración.',
            )
          else
            ...pending.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PaymentCard(
                  payment: payment,
                  amount: _formatVes(payment.split.totalMinor),
                  statusLabel: 'Pendiente',
                  onTap: () => _openPayment(payment),
                ),
              ),
            ),
          if (paid.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Pagos realizados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ...paid.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PaymentCard(
                  payment: payment,
                  amount: _formatVes(payment.split.totalMinor),
                  statusLabel: 'Pagado',
                  onTap: () => _openPayment(payment),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _demoNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ManoYaColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ManoYaColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'DEMO · Solicitudes y datos ficticios. No se mueve dinero.',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: ManoYaColors.muted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.amount,
    required this.statusLabel,
    required this.onTap,
  });

  final DemoPayment payment;
  final String amount;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPaid = payment.status == DemoPaymentStatus.paid;
    final color = isPaid ? ManoYaColors.success : ManoYaColors.warning;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: ManoYaColors.primary.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: ManoYaColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.concept,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Trabajador: ${payment.workerName}'),
                    Text('Cliente: ${payment.clientName}'),
                    const SizedBox(height: 4),
                    Text(
                      amount,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Icon(
                    isPaid ? Icons.check_circle_outline : Icons.schedule,
                    color: color,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ManoYaColors.muted),
        ),
      ),
    );
  }
}
