import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../domain/worker.dart';

/// Tarjeta resumen de un trabajador dentro del catálogo.
class WorkerCard extends StatelessWidget {
  final Worker worker;
  final VoidCallback onRequest;
  final VoidCallback? onTap;
  final VoidCallback? onWhatsApp;

  const WorkerCard({
    super.key,
    required this.worker,
    required this.onRequest,
    this.onTap,
    this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = worker.isAvailable
        ? ManoYaColors.success
        : ManoYaColors.muted;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * 12),
          child: child,
        ),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(
                      imageUrl: worker.avatarUrl,
                      name: worker.name,
                      radius: 27,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worker.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (worker.subcategory.isNotEmpty)
                            Text(
                              '${worker.subcategory} · ${worker.category}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: ManoYaColors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  worker.city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Badge(
                      label: worker.isAvailable
                          ? 'Disponible ahora'
                          : 'En descanso',
                      color: statusColor,
                      background: statusColor.withValues(alpha: 0.10),
                      icon: Icons.circle,
                      iconSize: 8,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: ManoYaColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          worker.rating.toStringAsFixed(1),
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '(${worker.reviewsCount})',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                if (worker.identityVerified ||
                    worker.workGuaranteed ||
                    worker.availableToday) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (worker.identityVerified)
                        const _Badge(
                          label: 'Identidad verificada',
                          icon: Icons.verified_outlined,
                          color: ManoYaColors.primary,
                          background: ManoYaColors.verifiedSurface,
                        ),
                      if (worker.workGuaranteed)
                        const _Badge(
                          label: 'Trabajo garantizado',
                          icon: Icons.shield_outlined,
                          color: ManoYaColors.whatsappGreen,
                          background: ManoYaColors.whatsappSurface,
                        ),
                      if (worker.availableToday)
                        const _Badge(
                          label: 'Disponible hoy',
                          icon: Icons.today_outlined,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    if (onWhatsApp != null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onWhatsApp,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ManoYaColors.whatsappGreen,
                            backgroundColor: ManoYaColors.whatsappSurface,
                            side: const BorderSide(
                              color: ManoYaColors.success,
                              width: 1.2,
                            ),
                          ),
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ManoYaColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text('Presupuesto'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;
  final double iconSize;

  const _Badge({
    required this.label,
    this.color = ManoYaColors.muted,
    this.background,
    this.icon,
    this.iconSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
