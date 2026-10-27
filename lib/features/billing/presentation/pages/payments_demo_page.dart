import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/email_service.dart';
import '../../data/payments_demo_repository.dart';
import '../../domain/demo_payment.dart';

class PaymentsDemoPage extends ConsumerStatefulWidget {
  const PaymentsDemoPage({super.key, required this.paymentId});

  final String paymentId;

  @override
  ConsumerState<PaymentsDemoPage> createState() => _PaymentsDemoPageState();
}

class _MobilePaymentDemoDialog extends StatefulWidget {
  const _MobilePaymentDemoDialog({
    required this.payment,
    required this.formatAmount,
  });

  final DemoPayment payment;
  final String Function(int) formatAmount;

  @override
  State<_MobilePaymentDemoDialog> createState() =>
      _MobilePaymentDemoDialogState();
}

class _MobilePaymentDemoDialogState extends State<_MobilePaymentDemoDialog> {
  static const _banks = [
    'Banco de Venezuela',
    'Banesco',
    'Banco Mercantil',
    'BBVA Provincial',
    'Bancaribe',
  ];

  final _formKey = GlobalKey<FormState>();
  String? _selectedBank;

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;

    return AlertDialog(
      title: const Text('Pago móvil · DEMO'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Simula los pasos de un pago móvil. Los datos son ficticios '
                'y esta operación no contacta a ningún banco.',
              ),
              const SizedBox(height: 16),
              _recipientDetail('Banco receptor', payment.workerBank),
              _recipientDetail('Teléfono del trabajador', payment.workerPhone),
              _recipientDetail(
                'Documento del trabajador',
                payment.workerDocument,
              ),
              _recipientDetail(
                'Monto',
                widget.formatAmount(payment.split.totalMinor),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                decoration: const InputDecoration(
                  labelText: 'Banco desde el que pagarías',
                  border: OutlineInputBorder(),
                ),
                items: _banks
                    .map(
                      (bank) =>
                          DropdownMenuItem(value: bank, child: Text(bank)),
                    )
                    .toList(),
                onChanged: (bank) => setState(() => _selectedBank = bank),
                validator: (bank) =>
                    bank == null ? 'Selecciona un banco de origen' : null,
              ),
              const SizedBox(height: 12),
              const Text(
                'La confirmación generará una referencia DEMO para continuar '
                'al paso de marcar el pago realizado.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, _selectedBank);
          },
          icon: const Icon(Icons.check),
          label: const Text('Simular pago móvil'),
        ),
      ],
    );
  }

  Widget _recipientDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: ManoYaColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsDemoPageState extends ConsumerState<PaymentsDemoPage> {
  bool _busy = false;
  String? _emailNotice;
  late DemoPayment _payment;

  @override
  void initState() {
    super.initState();
    final payment = ref
        .read(paymentsDemoRepositoryProvider)
        .getById(widget.paymentId);
    if (payment == null) {
      throw StateError('No existe la solicitud DEMO ${widget.paymentId}.');
    }
    _payment = payment;
  }

  String _formatVes(int amountMinor) {
    final units = amountMinor ~/ 100;
    final groupedUnits = units.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]}.',
    );
    final cents = (amountMinor % 100).toString().padLeft(2, '0');
    return 'Bs. $groupedUnits,$cents';
  }

  Future<void> _startPaymentSimulation(DemoPayment payment) async {
    final bank = await showDialog<String>(
      context: context,
      builder: (context) =>
          _MobilePaymentDemoDialog(payment: payment, formatAmount: _formatVes),
    );
    if (bank == null || !mounted) return;

    final completedPayment = ref
        .read(paymentsDemoRepositoryProvider)
        .completePaymentSimulation(payment.id, bank: bank);
    setState(() => _payment = completedPayment);
  }

  Future<void> _markAsPaid(DemoPayment payment) async {
    setState(() {
      _busy = true;
      _emailNotice = null;
    });

    final repository = ref.read(paymentsDemoRepositoryProvider);
    final paidPayment = repository.markAsPaid(payment.id);
    setState(() {
      _payment = paidPayment;
      _emailNotice = 'Preparando los reportes de correo simulados...';
    });
    final emailResults = await Future.wait([
      EmailService.sendReport(
        to: paidPayment.clientEmail,
        subject: 'Reporte de pago · ${paidPayment.concept}',
        body: _reportBody(paidPayment, recipient: paidPayment.clientName),
      ),
      EmailService.sendReport(
        to: paidPayment.workerEmail,
        subject: 'Reporte de pago recibido · ${paidPayment.concept}',
        body: _reportBody(paidPayment, recipient: paidPayment.workerName),
      ),
    ]);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _emailNotice = emailResults.every((sent) => sent)
          ? 'Reportes registrados en la bandeja simulada de ambos participantes.'
          : 'El pago se marcó en la demo, pero uno o más reportes no pudieron '
                'registrarse en la bandeja simulada.';
    });
  }

  String _reportBody(DemoPayment payment, {required String recipient}) {
    return 'Hola $recipient,\n\n'
        'Este es el reporte de prueba del pago "${payment.concept}".\n'
        'Cliente: ${payment.clientName}\n'
        'Trabajador: ${payment.workerName}\n'
        'Total: ${_formatVes(payment.split.totalMinor)}\n'
        'Comisión Mano Ya (15%): '
        '${_formatVes(payment.split.platformFeeMinor)}\n'
        'Neto del trabajador (85%): '
        '${_formatVes(payment.split.workerNetMinor)}\n'
        'Referencia: ${payment.paymentReference}\n\n'
        'Este mensaje fue generado en una simulación local. No hubo '
        'transferencia ni envío de correo real.';
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    final isPaid = payment.status == DemoPaymentStatus.paid;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pago')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _demoNotice(),
          const SizedBox(height: 16),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Solicitud de pago',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _statusBadge(isPaid),
                  ],
                ),
                const SizedBox(height: 14),
                _infoRow('Servicio', payment.concept),
                _infoRow('Trabajador', payment.workerName),
                _infoRow('Cliente', payment.clientName),
                _infoRow(
                  'Solicitado',
                  DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Datos para pagar',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Banco', payment.workerBank),
                _infoRow('Teléfono', payment.workerPhone),
                _infoRow('Documento', payment.workerDocument),
                const SizedBox(height: 8),
                const Text(
                  'Datos inventados para la demostración. No realices '
                  'transferencias reales.',
                  style: TextStyle(color: ManoYaColors.muted),
                ),
                if (payment.simulationCompletedAt != null) ...[
                  const Divider(height: 24),
                  _infoRow('Banco de origen', payment.simulationBank),
                  _infoRow('Referencia DEMO', payment.simulationReference),
                  _infoRow(
                    'Pago móvil simulado',
                    DateFormat('dd/MM/yyyy HH:mm')
                        .format(payment.simulationCompletedAt!),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Paso de pago de prueba completado. Ahora puedes marcar '
                    'la solicitud como pagada.',
                    style: TextStyle(
                      color: ManoYaColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Resumen y reparto del pago',
            child: Column(
              children: [
                _amountRow('Total a pagar', payment.split.totalMinor),
                _amountRow(
                  'Comisión de Mano Ya (15%)',
                  payment.split.platformFeeMinor,
                ),
                _amountRow(
                  'Neto para el trabajador (85%)',
                  payment.split.workerNetMinor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Reporte para ambas partes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Al marcar el pago como realizado se prepara el mismo '
                  'resumen con la referencia y el estado para cliente y '
                  'trabajador.',
                ),
                const SizedBox(height: 10),
                _infoRow('Correo del cliente', payment.clientEmail),
                _infoRow('Correo del trabajador', payment.workerEmail),
                if (isPaid) ...[
                  const Divider(height: 24),
                  _infoRow('Referencia', payment.paymentReference!),
                  _infoRow(
                    'Fecha de pago',
                    DateFormat('dd/MM/yyyy HH:mm').format(payment.paidAt!),
                  ),
                  Text(
                    _emailNotice ??
                        'Los reportes de ambas partes están en la bandeja '
                            'simulada. No se enviaron correos reales.',
                    style: const TextStyle(color: ManoYaColors.success),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (isPaid)
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.verified),
              label: const Text('Pago realizado en la demo'),
            )
          else if (payment.simulationCompletedAt == null)
            FilledButton.icon(
              onPressed: _busy ? null : () => _startPaymentSimulation(payment),
              icon: const Icon(Icons.account_balance),
              label: const Text('Realizar pago móvil (demo)'),
            )
          else
            FilledButton.icon(
              onPressed: _busy ? null : () => _markAsPaid(payment),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_busy ? 'Procesando...' : 'Marcar pago realizado'),
            ),
        ],
      ),
    );
  }

  Widget _demoNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ManoYaColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ManoYaColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEMO · Pago completamente simulado',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'No se usa Stripe, no se mueve dinero y los reportes solo se '
            'registran en una bandeja de prueba en memoria.',
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({String? title, required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: ManoYaColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, int amountMinor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text(
            _formatVes(amountMinor),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool isPaid) {
    final color = isPaid ? ManoYaColors.success : ManoYaColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPaid ? 'Pagado' : 'Pendiente',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
