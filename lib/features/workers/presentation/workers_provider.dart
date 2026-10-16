import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workers_repository.dart';
import '../domain/worker.dart';

final workersRepositoryProvider = Provider<WorkersRepository>(
  (ref) => WorkersRepository(),
);

/// Filtros activos del catálogo. Guarda la zona seleccionada junto con sus
/// coordenadas para poder ordenar los resultados por cercanía.
class WorkersFilter {
  final String? category;
  final String? cityName;
  final double? originLat;
  final double? originLng;
  final bool onlyAvailable;

  const WorkersFilter({
    this.category,
    this.cityName,
    this.originLat,
    this.originLng,
    this.onlyAvailable = false,
  });
}

class WorkersFilterNotifier extends Notifier<WorkersFilter> {
  @override
  WorkersFilter build() => const WorkersFilter();

  // Reemplaza categoría (null = todas).
  void setCategory(String? category) {
    state = WorkersFilter(
      category: category,
      cityName: state.cityName,
      originLat: state.originLat,
      originLng: state.originLng,
      onlyAvailable: state.onlyAvailable,
    );
  }

  // Define la zona seleccionada (nombre + coordenadas) o la limpia.
  void setCity(String? cityName, double? lat, double? lng) {
    state = WorkersFilter(
      category: state.category,
      cityName: cityName,
      originLat: lat,
      originLng: lng,
      onlyAvailable: state.onlyAvailable,
    );
  }

  // Activa/desactiva el filtro de disponibilidad.
  void setOnlyAvailable(bool value) {
    state = WorkersFilter(
      category: state.category,
      cityName: state.cityName,
      originLat: state.originLat,
      originLng: state.originLng,
      onlyAvailable: value,
    );
  }
}

final workersFilterProvider =
    NotifierProvider<WorkersFilterNotifier, WorkersFilter>(
      WorkersFilterNotifier.new,
    );

/// Lista de trabajadores según los filtros activos.
final workersListProvider = FutureProvider.autoDispose<List<Worker>>((
  ref,
) async {
  final repo = ref.read(workersRepositoryProvider);
  final filter = ref.watch(workersFilterProvider);
  return repo.list(
    category: filter.category,
    city: filter.cityName,
    onlyAvailable: filter.onlyAvailable,
    originLat: filter.originLat,
    originLng: filter.originLng,
  );
});

/// Trabajador individual por id (pantalla de detalle).
final workerByIdProvider = FutureProvider.autoDispose.family<Worker?, String>((
  ref,
  id,
) async {
  return ref.read(workersRepositoryProvider).getById(id);
});
