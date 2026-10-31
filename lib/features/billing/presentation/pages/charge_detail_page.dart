import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/async_state_views.dart';
import '../../domain/charge.dart';
import '../billing_provider.dart';
import '../widgets/charge_status_chip.dart';
import '../widgets/installment_table.dart';

/// Detalle de una solicitud de cobro: datos bancarios, tabla de cuotas/hitos
/// y acciones del flujo de pago (notificar / confirmar / recibo PDF / email).
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
    try {
      await ref.read(billingRepositoryProvider).notifyPayment(widget.chargeId);
      ref.invalidate(chargeByIdProvider(widget.chargeId));
      ref.invalidate(chargesListProvider);
      if (mounted) {
        _showMessage('Pago notificado. Esperando confirmación del trabajador.');
      }
    } catch (error) {
      if (mounted) _showMessage('No se pudo notificar el pago: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// El trabajador confirma el pago: genera el recibo y lo envía por email.
  Future<void> _confirmPayment(Charge charge) async {
    setState(() => _busy = true);
    try {
      final repository = ref.read(billingRepositoryProvider);
      final updated = await repository.confirmPayment(widget.chargeId);
      ref.invalidate(chargeByIdProvider(widget.chargeId));
      ref.invalidate(chargesListProvider);

      late final File file;
      try {
        file = await _generateReceipt(
          updated,
          sealed: updated.status == ChargeStatus.paid,
        );
      } catch (error) {
        if (mounted) {
          _showMessage(
            'Pago confirmado, pero no se pudo generar el recibo: $error',
          );
        }
        return;
      }

      final sent = await _emailReceipt(updated, file.path);
      if (!mounted) return;
      _showMessage(
        updated.status == ChargeStatus.paid
            ? sent
                  ? 'Pago total confirmado. Recibo enviado a '
                        '${updated.clientEmail}'
                  : 'Pago total confirmado. ${_receiptEmailFailure(updated)}'
            : sent
            ? 'Abono confirmado. Restan '
                  '${Formatters.currency(updated.pendingAmount)}. Recibo enviado.'
            : 'Abono confirmado. Restan '
                  '${Formatters.currency(updated.pendingAmount)}. '
                  '${_receiptEmailFailure(updated)}',
      );
      await _openReceipt(file.path);
    } catch (error) {
      if (mounted) _showMessage('No se pudo confirmar el pago: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reenvía por email el recibo de un cobro ya pagado.
  Future<void> _sendReceiptEmail(Charge charge) async {
    setState(() => _busy = true);
    try {
      final file = await _generateReceipt(charge, sealed: true);
      final sent = await _emailReceipt(charge, file.path);
      if (!mounted) return;
      _showMessage(
        sent
            ? 'Recibo enviado a ${charge.clientEmail}'
            : _receiptEmailFailure(charge),
      );
    } catch (error) {
      if (mounted) _showMessage('No se pudo enviar el recibo: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Envía el recibo (PDF adjunto) al correo del cliente.
  Future<bool> _emailReceipt(Charge charge, String path) {
    final to = charge.clientEmail?.trim();
    if (to == null || to.isEmpty) return Future.value(false);
    return EmailService.sendReport(
      to: to,
      subject: 'Recibo de pago · ${charge.concept}',
      body:
          'Hola ${charge.clientName},\n\n'
          'Adjuntamos el recibo del trabajo "${charge.concept}" por '
          '${Formatters.currency(charge.paidAmount)} de '
          '${Formatters.currency(charge.total)}.\n\n'
          'Gracias por usar Mano Ya.\n'
          'Tus oficios a la mano.',
      attachmentPath: path,
    );
  }

  String _receiptEmailFailure(Charge charge) =>
      charge.clientEmail == null || charge.clientEmail!.trim().isEmpty
      ? 'El cliente no tiene un correo registrado.'
      : 'No se pudo enviar el recibo por correo.';

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
      // Ignoramos: el llamador decide cómo avisar al usuario.
    }
    if (mounted) _showMessage('Recibo guardado en: $path');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final chargeAsync = ref.watch(chargeByIdProvider(widget.chargeId));
    final isWorker = ref.watch(authStateProvider).role == UserRole.worker;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del cobro')),
      body: chargeAsync.when(
        loading: () => const LoadingView(message: 'Cargando cobro...'),
        error: (error, stackTrace) => ErrorView(
          message: 'No se pudo cargar el cobro',
          onRetry: () => ref.invalidate(chargeByIdProvider(widget.chargeId)),
        ),
        data: (charge) {
          if (charge == null) {
            return const EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'Cobro no encontrado',
              message: 'Es posible que ya no esté disponible.',
            );
          }
          return _body(charge, isWorker);
        },
      ),
    );
  }

  Widget _body(Charge charge, bool isWorker) {
    final isPaid = charge.status == ChargeStatus.paid;
    final paidRatio = charge.total == 0
        ? 0.0
        : (charge.paidAmount / charge.total).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      charge.concept,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ChargeStatusChip(status: charge.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(label: 'Trabajador', value: charge.workerName),
              _InfoRow(label: 'Cliente', value: charge.clientName),
              if (charge.clientEmail != null)
                _InfoRow(label: 'Correo', value: charge.clientEmail!),
              _InfoRow(
                label: 'Fecha',
                value: Formatters.dateTime(charge.createdAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AmountRow(
                label: 'Total',
                value: Formatters.currency(charge.total),
              ),
              _AmountRow(
                label: 'Pagado',
                value: Formatters.currency(charge.paidAmount),
                color: ManoYaColors.success,
              ),
              _AmountRow(
                label: 'Pendiente',
                value: Formatters.currency(charge.pendingAmount),
                color: ManoYaColors.warning,
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: paidRatio,
                  minHeight: 8,
                  backgroundColor: ManoYaColors.border,
                  valueColor: const AlwaysStoppedAnimation(
                    ManoYaColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Datos para el pago',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(charge.bankInfo),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cuotas / hitos (${charge.installments.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              InstallmentTable(installments: charge.installments),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Trabajo pagado: sello + acciones de recibo.
        if (isPaid) ...[
          const _PaidSeal(),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Descargar recibo PDF',
            icon: Icons.picture_as_pdf,
            variant: AppButtonVariant.outline,
            loading: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              try {
                final file = await _generateReceipt(charge, sealed: true);
                if (mounted) await _openReceipt(file.path);
              } catch (error) {
                if (mounted) {
                  _showMessage('No se pudo generar el recibo: $error');
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Enviar recibo por email',
            icon: Icons.mail_outline,
            variant: AppButtonVariant.secondary,
            loading: _busy,
            onPressed: () => _sendReceiptEmail(charge),
          ),
        ],

        // Acción del cliente: notificar pago.
        if (!isPaid && !isWorker && charge.status == ChargeStatus.pending) ...[
          AppButton(
            label: 'Notificar pago realizado',
            icon: Icons.send,
            loading: _busy,
            onPressed: _notifyPayment,
          ),
        ],

        // Acción del trabajador: confirmar pago recibido.
        if (!isPaid &&
            isWorker &&
            charge.status == ChargeStatus.clientNotified) ...[
          AppButton(
            label: 'Confirmar pago recibido',
            icon: Icons.check_circle,
            variant: AppButtonVariant.secondary,
            loading: _busy,
            onPressed: () => _confirmPayment(charge),
          ),
        ],
        if (!isPaid && isWorker && charge.status == ChargeStatus.pending) ...[
          AppButton(
            label: 'El cliente aún no ha reportado el pago',
            icon: Icons.hourglass_empty,
            variant: AppButtonVariant.outline,
            onPressed: null,
          ),
        ],
      ],
    );
  }
}

/// Tarjeta contenedora de una sección del detalle.
class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: ManoYaColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

/// Fila etiqueta/valor usada para los datos del cobro.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: ManoYaColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de monto etiqueta/valor.
class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _AmountRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: ManoYaColors.muted)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
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
        color: ManoYaColors.success.withValues(alpha: 0.08),
        border: Border.all(color: ManoYaColors.success, width: 2),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified, color: ManoYaColors.success),
          SizedBox(width: AppSpacing.sm),
          Text(
            'TRABAJO PAGADO / GARANTIZADO',
            style: TextStyle(
              color: ManoYaColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
