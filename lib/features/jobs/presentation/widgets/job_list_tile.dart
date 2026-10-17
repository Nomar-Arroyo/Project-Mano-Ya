import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/job.dart';
import 'active_job_card.dart';
import 'job_status_chip.dart';

/// Fila compacta de un trabajo para listas (historial, solicitudes).
class JobListTile extends StatelessWidget {
  final Job job;
  final JobPerspective perspective;
  final VoidCallback? onTap;
  final VoidCallback? onRate;

  const JobListTile({
    super.key,
    required this.job,
    required this.perspective,
    this.onTap,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final isWorker = perspective == JobPerspective.worker;
    final counterpart = isWorker ? job.clientName : job.workerName;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: ManoYaColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: ManoYaColors.primary.withValues(alpha: 0.12),
                child: Icon(
                  isWorker ? Icons.person_outline : Icons.handyman_outlined,
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
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$counterpart · ${Formatters.date(job.scheduledAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ManoYaColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        JobStatusChip(status: job.status),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          Formatters.currency(job.price),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ManoYaColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (job.canBeRated)
                IconButton(
                  tooltip: 'Calificar',
                  onPressed: onRate,
                  icon: const Icon(
                    Icons.star_outline,
                    color: ManoYaColors.warning,
                  ),
                )
              else if (job.rating != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      size: 16,
                      color: ManoYaColors.warning,
                    ),
                    Text(
                      job.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        color: ManoYaColors.muted,
                      ),
                    ),
                  ],
                )
              else
                const Icon(Icons.chevron_right, color: ManoYaColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
