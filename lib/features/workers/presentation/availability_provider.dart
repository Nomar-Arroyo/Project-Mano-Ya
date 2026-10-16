import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';

// Valor inicial de disponibilidad cargado antes de levantar la app.
final initialAvailabilityProvider = Provider<bool>((ref) => true);

// Disponibilidad del trabajador, persistida en preferencias.
final workerAvailabilityProvider =
    NotifierProvider<WorkerAvailabilityNotifier, bool>(
      WorkerAvailabilityNotifier.new,
    );

class WorkerAvailabilityNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(initialAvailabilityProvider);

  Future<void> set(bool value) async {
    state = value;
    await StorageService.setAvailability(value);
  }

  Future<void> toggle() => set(!state);

  static Future<bool> loadSaved() => StorageService.getAvailability();
}
