import 'package:flutter/material.dart';

import '../../../../../core/constants/colors.dart';
import '../../domain/worker.dart';

/// Tarjeta resumen de un trabajador dentro del catálogo. Permite abrir el
/// detalle, contactar por WhatsApp o solicitar un presupuesto.
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      worker.name.isNotEmpty
                          ? worker.name.substring(0, 1).toUpperCase()
                          : '?',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${worker.category} • ${worker.subcategory} • '
                          '${worker.city}',
                          style: const TextStyle(
                            color: ManoYaColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: ManoYaColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${worker.rating.toStringAsFixed(1)} '
                              '(${worker.reviewsCount})',
                              style: const TextStyle(
                                color: ManoYaColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (worker.isAvailable
                                  ? ManoYaColors.success
                                  : Colors.grey)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      worker.isAvailable ? 'Disponible' : 'En descanso',
                      style: TextStyle(
                        fontSize: 12,
                        color: worker.isAvailable
                            ? ManoYaColors.success
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (worker.identityVerified)
                    const _Badge(label: 'Identidad Verificada'),
                  if (worker.workGuaranteed)
                    const _Badge(
                      label: 'Trabajo Garantizado',
                      color: ManoYaColors.success,
                    ),
                  if (worker.availableToday)
                    const _Badge(label: 'Disponible Hoy'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onWhatsApp != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onWhatsApp,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ManoYaColors.success,
                        ),
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  if (onWhatsApp != null) const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ManoYaColors.secondary,
                      ),
                      child: const Text('Presupuesto'),
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

/// Insignia de confianza reutilizable.
class _Badge extends StatelessWidget {
  final String label;
  final Color? color;

  const _Badge({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? ManoYaColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontWeight: FontWeight.w500, fontSize: 12),
      ),
    );
  }
}
