import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/async_state_views.dart';
import '../../domain/job.dart';
import '../job_actions.dart';
import '../jobs_provider.dart';
import '../widgets/active_job_card.dart';
import '../widgets/job_list_tile.dart';
import 'job_detail_page.dart';

/// Panel principal ("home") que se adapta al rol del usuario: el trabajador
/// ve su trabajo activo y sus trabajos; el cliente ve a su trabajador
/// contratado y su historial de servicios.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(authStateProvider.select((s) => s.role)) ?? UserRole.client;
    return role == UserRole.worker
        ? const _WorkerDashboard()
        : const _ClientDashboard();
  }
}

// ---------------------------------------------------------------------------
// Panel del TRABAJADOR
// ---------------------------------------------------------------------------

class _WorkerDashboard extends ConsumerWidget {
  const _WorkerDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final userId = auth.userId ?? 'mock_user';
    final jobsAsync = ref.watch(workerJobsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Mi panel')),
      body: jobsAsync.when(
        loading: () => const LoadingView(message: 'Cargando tus trabajos...'),
        error: (error, stackTrace) => ErrorView(
          message: 'No se pudieron cargar tus trabajos',
          onRetry: () => ref.invalidate(workerJobsProvider(userId)),
        ),
        data: (jobs) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(workerJobsProvider(userId)),
          child: _body(context, ref, jobs),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, List<Job> jobs) {
    final name = ref.watch(authStateProvider).displayName ?? 'Profesional';
    final active = _firstActive(jobs);
    final requests = jobs.where((j) => j.isRequested).toList();
    final history = jobs.where((j) => j.isFinished).toList();
    final completed = history
        .where((j) => j.status == JobStatus.completed)
        .toList();
    final earnings = completed.fold<double>(0, (sum, j) => sum + j.price);
    final activeCount = jobs.where((j) => j.isActive).length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _DashboardHeader(
          name: name,
          subtitle: 'Panel de trabajador',
          icon: Icons.handyman_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        _StatsRow(
          items: [
            _Stat(
              label: 'Activos',
              value: '$activeCount',
              icon: Icons.play_circle_outline,
              color: ManoYaColors.primary,
            ),
            _Stat(
              label: 'Solicitudes',
              value: '${requests.length}',
              icon: Icons.hourglass_empty,
              color: ManoYaColors.warning,
            ),
            _Stat(
              label: 'Ganado',
              value: Formatters.currency(earnings),
              icon: Icons.savings_outlined,
              color: ManoYaColors.success,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle('Mi trabajo activo'),
        const SizedBox(height: AppSpacing.sm),
        if (active != null)
          ActiveJobCard(
            job: active,
            perspective: JobPerspective.worker,
            onAdvance: () => advanceJob(context, ref, active),
            onTap: () => _openJobDetail(context, active.id),
          )
        else
          const _EmptyActive(),
        if (requests.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('Solicitudes por aceptar (${requests.length})'),
          const SizedBox(height: AppSpacing.sm),
          for (final job in requests) ...[
            JobListTile(
              job: job,
              perspective: JobPerspective.worker,
              onTap: () => _openJobDetail(context, job.id),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle('Mis trabajos (${history.length})'),
        const SizedBox(height: AppSpacing.sm),
        if (history.isEmpty)
          const EmptyView(
            icon: Icons.work_history_outlined,
            title: 'Aún no tienes trabajos finalizados',
            message: 'Cuando completes un trabajo aparecerá en esta lista.',
          )
        else
          for (final job in history) ...[
            JobListTile(
              job: job,
              perspective: JobPerspective.worker,
              onTap: () => _openJobDetail(context, job.id),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

/// Dashboard del cliente: trabajador contratado, solicitudes e historial.
class _ClientDashboard extends ConsumerWidget {
  const _ClientDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final userId = auth.userId ?? 'mock_user';
    final jobsAsync = ref.watch(clientJobsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: jobsAsync.when(
        loading: () => const LoadingView(message: 'Cargando tu actividad...'),
        error: (error, stackTrace) => ErrorView(
          message: 'No se pudo cargar tu actividad',
          onRetry: () => ref.invalidate(clientJobsProvider(userId)),
        ),
        data: (jobs) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientJobsProvider(userId)),
          child: _body(context, ref, jobs),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, List<Job> jobs) {
    final name = ref.watch(authStateProvider).displayName ?? 'Cliente';
    final active = _firstActive(jobs);
    final requests = jobs.where((j) => j.isRequested).toList();
    final history = jobs.where((j) => j.isFinished).toList();
    final toRate = jobs.where((j) => j.canBeRated).toList();
    final spent = jobs
        .where((j) => j.status == JobStatus.completed)
        .fold<double>(0, (sum, j) => sum + j.price);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _DashboardHeader(
          name: name,
          subtitle: 'Panel de cliente',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: AppSpacing.lg),
        _StatsRow(
          items: [
            _Stat(
              label: 'Contratado',
              value: active != null ? '1' : '0',
              icon: Icons.verified_user_outlined,
              color: ManoYaColors.primary,
            ),
            _Stat(
              label: 'Por calificar',
              value: '${toRate.length}',
              icon: Icons.star_outline,
              color: ManoYaColors.warning,
            ),
            _Stat(
              label: 'Gastado',
              value: Formatters.currency(spent),
              icon: Icons.account_balance_wallet_outlined,
              color: ManoYaColors.success,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle('Trabajador contratado'),
        const SizedBox(height: AppSpacing.sm),
        if (active != null)
          ActiveJobCard(
            job: active,
            perspective: JobPerspective.client,
            onContact: () => contactJobWorker(context, ref, active),
            onRate: () => showRateJobDialog(context, ref, active),
            onTap: () => _openJobDetail(context, active.id),
          )
        else
          const _EmptyActive(
            message: 'No tienes un trabajador contratado en este momento.',
          ),
        if (requests.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('Solicitudes enviadas (${requests.length})'),
          const SizedBox(height: AppSpacing.sm),
          for (final job in requests) ...[
            JobListTile(
              job: job,
              perspective: JobPerspective.client,
              onTap: () => _openJobDetail(context, job.id),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle('Historial (${history.length})'),
        const SizedBox(height: AppSpacing.sm),
        if (history.isEmpty)
          const EmptyView(
            icon: Icons.history,
            title: 'Sin historial todavía',
            message: 'Aquí verás los servicios que hayas contratado.',
          )
        else
          for (final job in history) ...[
            JobListTile(
              job: job,
              perspective: JobPerspective.client,
              onTap: () => _openJobDetail(context, job.id),
              onRate: () => showRateJobDialog(context, ref, job),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

/// Devuelve el primer trabajo activo (aceptado o en progreso) de la lista.
Job? _firstActive(List<Job> jobs) {
  for (final job in jobs) {
    if (job.isActive) return job;
  }
  return null;
}

/// Abre el detalle de un trabajo.
void _openJobDetail(BuildContext context, String jobId) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => JobDetailPage(jobId: jobId)));
}

/// Encabezado con saludo, nombre y rol.
class _DashboardHeader extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData icon;

  const _DashboardHeader({
    required this.name,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.10,
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting(), style: theme.textTheme.bodySmall),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días,';
    if (hour < 19) return 'Buenas tardes,';
    return 'Buenas noches,';
  }
}

/// Fila de tres tarjetas de resumen.
class _StatsRow extends StatelessWidget {
  final List<_Stat> items;

  const _StatsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: _StatCard(item: items[i])),
        ],
      ],
    );
  }
}

/// Datos de una tarjeta de resumen.
class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _Stat item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: ManoYaColors.border.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: item.color,
              ),
            ),
          ),
          Text(
            item.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Título de sección del panel.
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

/// Aviso mostrado cuando no hay trabajo activo.
class _EmptyActive extends StatelessWidget {
  final String message;

  const _EmptyActive({
    this.message = 'No tienes trabajos activos en este momento.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ManoYaColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: ManoYaColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.self_improvement, color: ManoYaColors.muted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: ManoYaColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
