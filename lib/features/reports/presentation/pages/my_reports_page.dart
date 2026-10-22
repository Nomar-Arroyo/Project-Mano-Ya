import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/widgets/async_state_views.dart';
import '../../domain/report.dart';
import '../report_provider.dart';

/// Historial de reportes enviados por el usuario.
class MyReportsPage extends ConsumerWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final reports = ref.watch(myReportsProvider(auth.userId ?? ''));

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reportes')),
      body: reports.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: '$error'),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'Todavía no has enviado reportes',
              message: 'Si tuviste un problema con un servicio, cuéntanos.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myReportsProvider(auth.userId ?? ''));
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _ReportCard(report: items[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/reports/new'),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nuevo reporte'),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final color = switch (report.status) {
      ReportStatus.abierto => ManoYaColors.warning,
      ReportStatus.enRevision => ManoYaColors.info,
      ReportStatus.resuelto => ManoYaColors.success,
      ReportStatus.cerrado => ManoYaColors.muted,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.category.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    report.status.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(report.reason),
            if (report.targetName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Sobre: ${report.targetName}',
                style: const TextStyle(color: ManoYaColors.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _formatDate(report.createdAt),
              style: const TextStyle(color: ManoYaColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }
}
