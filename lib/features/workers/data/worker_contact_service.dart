import 'package:flutter/foundation.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/worker.dart';

class WorkerContactService {
  const WorkerContactService._();

  static Future<bool> sendContactCard(Worker worker) async {
    if (!kIsWeb) return false;
    final client = SupabaseService.client;
    if (client == null || client.auth.currentSession == null) {
      throw StateError('Inicia sesión para recibir la ficha por correo.');
    }

    final response = await client.functions.invoke(
      'send-worker-contact-card',
      body: {'worker_id': worker.id},
    );
    final data = response.data;
    if (response.status < 200 ||
        response.status >= 300 ||
        data is! Map ||
        data['ok'] != true) {
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'No se pudo enviar la ficha del trabajador.';
      throw StateError(message);
    }
    return true;
  }
}
