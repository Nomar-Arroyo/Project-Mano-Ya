import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../requests/presentation/pages/request_form_page.dart';
import '../../domain/worker.dart';
import '../workers_provider.dart';

/// Pantalla de detalle de un trabajador: perfil completo, insignias de
/// confianza y acciones de contacto (WhatsApp) y solicitud de presupuesto.
class WorkerDetailPage extends ConsumerWidget {
  final String workerId;

  const WorkerDetailPage({super.key, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncWorker = ref.watch(workerByIdProvider(workerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil del trabajador')),
      body: asyncWorker.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('No se pudo cargar el perfil')),
        data: (worker) {
          if (worker == null) {
            return const Center(child: Text('Trabajador no encontrado'));
          }
          return _WorkerDetailBody(worker: worker);
        },
      ),
    );
  }
}

class _WorkerDetailBody extends ConsumerWidget {
  final Worker worker;

  const _WorkerDetailBody({required this.worker});

  // Abre WhatsApp con un mensaje estructurado para contactar al trabajador.
  Future<void> _openWhatsApp(BuildContext context, WidgetRef ref) async {
    final clientName = ref.read(authStateProvider).displayName;
    final message = WhatsAppService.buildMessage(
      workerName: worker.name,
      category: worker.category,
      subcategory: worker.subcategory,
      city: worker.city,
      clientName: clientName,
    );
    final ok = await WhatsAppService.openChat(
      phone: worker.phone ?? '',
      message: message,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp en este dispositivo'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _Avatar(worker: worker),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.name,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${worker.category} · ${worker.subcategory}',
                    style: const TextStyle(color: ManoYaColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: ManoYaColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          worker.city,
                          style: const TextStyle(
                            color: ManoYaColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.star, color: ManoYaColors.warning, size: 20),
            const SizedBox(width: 4),
            Text(
              worker.rating.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              '(${worker.reviewsCount} reseñas)',
              style: const TextStyle(color: ManoYaColors.muted, fontSize: 12),
            ),
            const Spacer(),
            _AvailabilityChip(available: worker.isAvailable),
          ],
        ),
        const SizedBox(height: 12),
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
            if (worker.availableToday) const _Badge(label: 'Disponible Hoy'),
          ],
        ),
        const SizedBox(height: 20),
        if (worker.bio != null && worker.bio!.isNotEmpty) ...[
          const Text(
            'Sobre el trabajador',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(worker.bio!),
          const SizedBox(height: 20),
        ],
        if (worker.phone != null && worker.phone!.isNotEmpty) ...[
          const Text('Contacto', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone, size: 18, color: ManoYaColors.muted),
              const SizedBox(width: 8),
              Text(worker.phone!),
            ],
          ),
          const SizedBox(height: 20),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openWhatsApp(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: ManoYaColors.success,
            ),
            icon: const Icon(Icons.chat),
            label: const Text('Contactar por WhatsApp'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RequestFormPage(
                    workerId: worker.id,
                    workerName: worker.name,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ManoYaColors.secondary,
            ),
            icon: const Icon(Icons.request_quote),
            label: const Text('Solicitar Presupuesto'),
          ),
        ),
      ],
    );
  }
}

/// Avatar del trabajador: usa la imagen si existe o las iniciales.
class _Avatar extends StatelessWidget {
  final Worker worker;

  const _Avatar({required this.worker});

  @override
  Widget build(BuildContext context) {
    final name = worker.name;
    return CircleAvatar(
      radius: 36,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: const TextStyle(fontSize: 28),
      ),
    );
  }
}

/// Chip de estado de disponibilidad del trabajador.
class _AvailabilityChip extends StatelessWidget {
  final bool available;

  const _AvailabilityChip({required this.available});

  @override
  Widget build(BuildContext context) {
    final color = available ? ManoYaColors.success : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        available ? 'Disponible' : 'En descanso',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
