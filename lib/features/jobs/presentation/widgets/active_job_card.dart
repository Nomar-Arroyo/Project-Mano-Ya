import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/job.dart';
import 'job_status_chip.dart';

/// Punto de vista desde el que se muestra la tarjeta de trabajo activo.
enum JobPerspective { worker, client }

/// Tarjeta destacada del "trabajo activo" del panel principal.
///
/// Muestra la otra parte (cliente o trabajador), los datos del servicio,
/// el progreso del trabajo y las acciones disponibles según el rol.
class ActiveJobCard extends StatelessWidget {
  final Job job;
  final JobPerspective perspective;
  final VoidCallback? onAdvance;
  final VoidCallback? onContact;
  final VoidCallback? onRate;
  final VoidCallback? onTap;

  const ActiveJobCard({
    super.key,
    required this.job,
    required this.perspective,
    this.onAdvance,
    this.onContact,
    this.onRate,
    this.onTap,
  });

  static const List<String> _steps = [
    'Solicitado',
    'Aceptado',
    'En progreso',
    'Completado',
  ];

  @override
  Widget build(BuildContext context) {
    final isWorker = perspective == JobPerspective.worker;
    final counterpart = isWorker ? job.clientName : job.workerName;
    final counterpartRole = isWorker ? 'Cliente' : 'Trabajador';

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: ManoYaColors.primary.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                gradient: ManoYaColors.brandGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          job.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      JobStatusChip(status: job.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.work_outline,
                        size: 15,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        job.category,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: counterpartRole,
                    value: counterpart,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    icon: Icons.place_outlined,
                    label: 'Ubicación',
                    value: job.address,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    icon: Icons.event_outlined,
                    label: 'Fecha',
                    value: Formatters.dateTime(job.scheduledAt),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Valor',
                    value: Formatters.currency(job.price),
                    valueColor: ManoYaColors.success,
                    valueBold: true,
                  ),
                  if (job.status != JobStatus.cancelled) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _ProgressSteps(current: job.progressIndex, steps: _steps),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _buildActions(context, isWorker),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool isWorker) {
    if (isWorker) {
      final String? label = switch (job.status) {
        JobStatus.requested => 'Aceptar solicitud',
        JobStatus.accepted => 'Iniciar trabajo',
        JobStatus.inProgress => 'Marcar como completado',
        _ => null,
      };
      if (label == null) return const SizedBox.shrink();
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onAdvance,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(label),
        ),
      );
    }

    // Cliente: contactar mientras está activo y/o calificar al finalizar.
    final canContact = job.isActive || job.status == JobStatus.accepted;
    if (job.canBeRated) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onRate,
          style: FilledButton.styleFrom(backgroundColor: ManoYaColors.warning),
          icon: const Icon(Icons.star_outline),
          label: const Text('Calificar trabajador'),
        ),
      );
    }
    if (canContact) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onContact,
          style: OutlinedButton.styleFrom(
            foregroundColor: ManoYaColors.success,
          ),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Contactar por WhatsApp'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Fila de dato con icono, etiqueta y valor.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: ManoYaColors.muted),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(color: ManoYaColors.muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra de progreso horizontal con los pasos del trabajo.
class _ProgressSteps extends StatelessWidget {
  final int current;
  final List<String> steps;

  const _ProgressSteps({required this.current, required this.steps});

  @override
  Widget build(BuildContext context) {
    final label = current < 0 ? 'Cancelado' : steps[current];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              _StepDot(
                done: i <= current,
                active: i == current,
                icon: const [
                  Icons.receipt_long_outlined,
                  Icons.event_available,
                  Icons.construction,
                  Icons.check_circle_outline,
                ][i],
              ),
              if (i != steps.length - 1)
                Expanded(child: _StepLine(done: i < current)),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Paso ${current + 1} de ${steps.length} · $label',
          style: const TextStyle(fontSize: 12, color: ManoYaColors.muted),
        ),
      ],
    );
  }
}

/// Punto de un paso del progreso.
class _StepDot extends StatelessWidget {
  final bool done;
  final bool active;
  final IconData icon;

  const _StepDot({
    required this.done,
    required this.active,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? ManoYaColors.primary : ManoYaColors.border;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: active
            ? ManoYaColors.primary
            : done
            ? ManoYaColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(
        icon,
        size: 16,
        color: active ? Colors.white : (done ? ManoYaColors.primary : color),
      ),
    );
  }
}

/// Línea conectora entre dos pasos.
class _StepLine extends StatelessWidget {
  final bool done;

  const _StepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: done
          ? ManoYaColors.primary.withValues(alpha: 0.5)
          : ManoYaColors.border,
    );
  }
}
