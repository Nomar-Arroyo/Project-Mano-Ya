import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/colors.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/job.dart';
import 'jobs_provider.dart';

/// Abre el diálogo para que el cliente califique a un trabajador.
Future<void> showRateJobDialog(
  BuildContext context,
  WidgetRef ref,
  Job job,
) async {
  var rating = 5.0;
  final commentController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Calificar a ${job.workerName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => rating = i.toDouble()),
                    icon: Icon(
                      i <= rating ? Icons.star : Icons.star_border,
                      color: ManoYaColors.warning,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                hintText: '¿Cómo fue tu experiencia?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    ),
  );

  if (confirmed == true) {
    final comment = commentController.text.trim();
    await ref
        .read(jobsControllerProvider)
        .rate(job.id, rating: rating, review: comment.isEmpty ? null : comment);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Gracias por tu calificación!'),
          backgroundColor: ManoYaColors.success,
        ),
      );
    }
  }
  commentController.dispose();
}

/// Abre WhatsApp para contactar al trabajador de un trabajo dado.
Future<void> contactJobWorker(
  BuildContext context,
  WidgetRef ref,
  Job job,
) async {
  final clientName = ref.read(authStateProvider).displayName;
  final message = WhatsAppService.buildMessage(
    workerName: job.workerName,
    category: job.category,
    subcategory: job.title,
    city: job.address,
    clientName: clientName,
  );
  final ok = await WhatsAppService.openChat(
    phone: job.workerPhone ?? '',
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
