import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../domain/charge.dart';

/// Chip de estado de una solicitud de cobro con color e icono.
class ChargeStatusChip extends StatelessWidget {
  final ChargeStatus status;

  const ChargeStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      ChargeStatus.pending => (
        ManoYaColors.warning,
        Icons.hourglass_empty,
        'Pendiente',
      ),
      ChargeStatus.clientNotified => (
        ManoYaColors.primary,
        Icons.verified_outlined,
        'Pago notificado',
      ),
      ChargeStatus.paid => (ManoYaColors.success, Icons.check_circle, 'Pagado'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
