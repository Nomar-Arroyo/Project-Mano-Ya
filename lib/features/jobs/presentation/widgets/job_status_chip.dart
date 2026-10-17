import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../domain/job.dart';

/// Chip de estado de un trabajo con color e icono según su fase.
class JobStatusChip extends StatelessWidget {
  final JobStatus status;

  const JobStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      JobStatus.requested => (ManoYaColors.warning, Icons.hourglass_empty),
      JobStatus.accepted => (ManoYaColors.info, Icons.event_available),
      JobStatus.inProgress => (ManoYaColors.secondary, Icons.construction),
      JobStatus.completed => (ManoYaColors.success, Icons.check_circle),
      JobStatus.cancelled => (ManoYaColors.danger, Icons.cancel_outlined),
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
            status.label,
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
