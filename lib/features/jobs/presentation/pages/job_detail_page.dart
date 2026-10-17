import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/async_state_views.dart';
import '../job_actions.dart';
import '../jobs_provider.dart';
import '../widgets/active_job_card.dart';

/// Detalle completo de un trabajo con sus acciones según el rol.
class JobDetailPage extends ConsumerWidget {
  final String jobId;

  const JobDetailPage({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(authStateProvider.select((s) => s.role)) ?? UserRole.client;
    final perspective = role == UserRole.worker
        ? JobPerspective.worker
        : JobPerspective.client;
    final jobAsync = ref.watch(jobByIdProvider(jobId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del trabajo')),
      body: jobAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'No se pudo cargar el trabajo',
          onRetry: () => ref.invalidate(jobByIdProvider(jobId)),
        ),
        data: (job) {
          if (job == null) {
            return const EmptyView(
              icon: Icons.search_off,
              title: 'Trabajo no encontrado',
              message: 'Es posible que ya no esté disponible.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ActiveJobCard(
                job: job,
                perspective: perspective,
                onAdvance: () => ref.read(jobsControllerProvider).advance(job),
                onContact: () => contactJobWorker(context, ref, job),
                onRate: () => showRateJobDialog(context, ref, job),
              ),
              if (job.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Descripción',
                  child: Text(job.description),
                ),
              ],
              if (job.review != null) ...[
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Reseña del cliente',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.format_quote, color: ManoYaColors.muted),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(job.review!),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                for (var i = 1; i <= 5; i++)
                                  Icon(
                                    (job.rating ?? 0) >= i
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 16,
                                    color: ManoYaColors.warning,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Tarjeta con un título y contenido.
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: ManoYaColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}
