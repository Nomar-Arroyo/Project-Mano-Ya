import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/colors.dart';
import '../../domain/worker.dart';

class WorkerCard extends ConsumerWidget {
  final Worker worker;
  final VoidCallback onRequest;
  const WorkerCard({super.key, required this.worker, required this.onRequest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    worker.name.isNotEmpty ? worker.name.substring(0, 1) : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(' • '),
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
                      color: worker.isAvailable
                          ? ManoYaColors.success
                          : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ManoYaColors.secondary,
                ),
                child: const Text('Solicitar Presupuesto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
