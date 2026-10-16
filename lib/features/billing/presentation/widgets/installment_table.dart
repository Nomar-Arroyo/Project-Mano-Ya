import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../domain/charge.dart';

/// Tabla de cuotas/hitos de un cobro con su estado (Pagada / Pendiente).
class InstallmentTable extends StatelessWidget {
  final List<Installment> installments;

  const InstallmentTable({super.key, required this.installments});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final borderColor = Theme.of(context).dividerColor;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Encabezado de la tabla.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _Header('Cuota')),
                Expanded(flex: 3, child: _Header('Vence')),
                Expanded(flex: 3, child: _Header('Monto')),
                Expanded(flex: 3, child: _Header('Estado')),
              ],
            ),
          ),
          // Filas de cada cuota.
          for (var i = 0; i < installments.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(installments[i].label)),
                  Expanded(
                    flex: 3,
                    child: Text(
                      dateFormat.format(installments[i].dueDate),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '\$ ${installments[i].amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _StatusChip(paid: installments[i].paid),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Encabezado de columna de la tabla.
class _Header extends StatelessWidget {
  final String label;

  const _Header(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
    );
  }
}

/// Chip de estado (Pagada / Pendiente) de una cuota.
class _StatusChip extends StatelessWidget {
  final bool paid;

  const _StatusChip({required this.paid});

  @override
  Widget build(BuildContext context) {
    final color = paid ? ManoYaColors.success : ManoYaColors.warning;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          paid ? 'Pagada' : 'Pendiente',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
