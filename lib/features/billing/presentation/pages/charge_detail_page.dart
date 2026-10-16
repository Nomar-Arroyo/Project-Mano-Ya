import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/models/user_role.dart';
import '../../domain/charge.dart';
import '../billing_provider.dart';
import '../widgets/installment_table.dart';

/// Detalle de una solicitud de cobro: datos bancarios, tabla de cuotas/hitos
/// y acciones del flujo de pago (notificar / confirmar / descargar recibo).
class ChargeDetailPage extends ConsumerStatefulWidget {
  final String chargeId;

  const ChargeDetailPage({super.key, required this.chargeId});

  @override
  ConsumerState<ChargeDetailPage> createState() => _ChargeDetailPageState();
}

class _ChargeDetailPageState extends ConsumerState<ChargeDetailPage> {
  bool _busy = false;

  /// El cliente notifica que ya realizó el pago.
  Future<void> _notifyPayment() async {
    setState(() => _busy = true);
    await ref.read(billingRepositoryProvider).notifyPayment(widget.chargeId);
    ref.invalidate(chargeByIdProvider(widget.chargeId));
    ref.invalidate(chargesListProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage('Pago notificado. Esperando confirmación del trabajador.');
  }

  /// El trabajador confirma el pago y se genera el recibo en PDF.
  Future<void> _confirmPayment(Charge charge) async {
    setState(() => _busy = true);
    final file = await _generateReceipt(charge, sealed: true);
    await ref
        .read(billingRepositoryProvider)
        .confirmPayment(widget.chargeId, receiptPath: file.path);
    ref.invalidate(chargeByIdProvider(widget.chargeId));
    ref.invalidate(chargesListProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage('Pago confirmado. Recibo generado.');
    await _openReceipt(file.path);
  }

  /// Genera (o regenera) el recibo PDF del cobro.
  Future<File> _generateReceipt(Charge charge, {required bool sealed}) async {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final installments = charge.installments.map((item) {
      final paid = sealed || item.paid;
      return <String, String>{
        'label': item.label,
        'dueDate': dateFormat.format(item.dueDate),
        'amount': item.amount.toStringAsFixed(2),
        'status': paid ? 'Pagada' : 'Pendiente',
      };
    }).toList();

    return PdfService.generateReceipt(
      receiptId: charge.id,
      workerName: charge.workerName,
      clientName: charge.clientName,
      concept: charge.concept,
      total: charge.total,
      paidAmount: sealed ? charge.total : charge.paidAmount,
      date: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      installments: installments,
      sealed: sealed,
    );
  }

  /// Intenta abrir el recibo; si el dispositivo no lo permite, muestra la ruta.
  Future<void> _openReceipt(String path) async {
    final uri = Uri.file(path);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // Ignoramos y avisamos con la ruta del archivo.
    }
    _showMessage('Recibo generado en: $path');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final asyncCharge = ref.watch(chargeByIdProvider(widget.chargeId));
    final role = ref.watch(authStateProvider).role;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de cobro')),
      body: asyncCharge.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('No se pudo cargar el cobro')),
        data: (charge) {
          if (charge == null) {
            return const Center(child: Text('Cobro no encontrado'));
          }
          return _body(charge, role);
        },
      ),
    );
  }

  Widget _body(Charge charge, UserRole? role) {
    final isWorker = role == UserRole.worker;
    final isPaid = charge.status == ChargeStatus.paid;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Encabezado con estado.
        Row(
          children: [
            Expanded(
              child: Text(
                charge.concept,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _StatusChip(status: charge.status),
          ],
        ),
        const SizedBox(height: 12),
        _InfoRow(label: 'Trabajador', value: charge.workerName),
        _InfoRow(label: 'Cliente', value: charge.clientName),
        _InfoRow(
          label: 'Creado',
          value: DateFormat('dd/MM/yyyy').format(charge.createdAt),
        ),
        const Divider(height: 28),
        // Montos.
        _InfoRow(
          label: 'Total',
          value: '\$ ${charge.total.toStringAsFixed(2)}',
        ),
        _InfoRow(
          label: 'Pagado',
          value: '\$ ${charge.paidAmount.toStringAsFixed(2)}',
          color: ManoYaColors.success,
        ),
        _InfoRow(
          label: 'Pendiente',
          value: '\$ ${charge.pendingAmount.toStringAsFixed(2)}',
          color: ManoYaColors.warning,
        ),
        const Divider(height: 28),
        const Text(
          'Datos para el pago',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(charge.bankInfo),
        const SizedBox(height: 24),
        const Text(
          'Cuotas / hitos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        InstallmentTable(installments: charge.installments),
        const SizedBox(height: 24),

        // Sello cuando el trabajo está pagado.
        if (isPaid) ...[
          const _PaidSeal(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final file = await _generateReceipt(charge, sealed: true);
                    if (!mounted) return;
                    setState(() => _busy = false);
                    await _openReceipt(file.path);
                  },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Descargar recibo PDF'),
          ),
        ],

        // Acción del cliente: notificar pago.
        if (!isPaid && !isWorker && charge.status == ChargeStatus.pending) ...[
          ElevatedButton.icon(
            onPressed: _busy ? null : _notifyPayment,
            icon: const Icon(Icons.send),
            label: const Text('Notificar pago realizado'),
          ),
        ],

        // Acción del trabajador: confirmar pago recibido.
        if (!isPaid &&
            isWorker &&
            charge.status == ChargeStatus.clientNotified) ...[
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _confirmPayment(charge),
            style: ElevatedButton.styleFrom(
              backgroundColor: ManoYaColors.success,
            ),
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirmar pago recibido'),
          ),
        ],
      ],
    );
  }
}

/// Fila etiqueta/valor usada para los datos del cobro.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InfoRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: ManoYaColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de estado del cobro con su color y etiqueta correspondientes.
class _StatusChip extends StatelessWidget {
  final ChargeStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _presentation(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Color y texto legible para cada estado del cobro.
  (Color, String) _presentation(ChargeStatus status) {
    switch (status) {
      case ChargeStatus.pending:
        return (ManoYaColors.warning, 'Pendiente de pago');
      case ChargeStatus.clientNotified:
        return (ManoYaColors.primary, 'Pago notificado');
      case ChargeStatus.paid:
        return (ManoYaColors.success, 'Pagado / Completado');
    }
  }
}

/// Sello visual de trabajo pagado.
class _PaidSeal extends StatelessWidget {
  const _PaidSeal();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: ManoYaColors.success, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified, color: ManoYaColors.success),
          SizedBox(width: 8),
          Text(
            'TRABAJO PAGADO / GARANTIZADO',
            style: TextStyle(
              color: ManoYaColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
