import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workers_repository.dart';
import '../domain/worker.dart';

final workersRepositoryProvider = Provider<WorkersRepository>(
  (ref) => WorkersRepository(),
);

class WorkersFilter {
  final String? category;
  final String? city;
  final bool onlyAvailable;

  const WorkersFilter({this.category, this.city, this.onlyAvailable = false});

  WorkersFilter copyWith({
    String? category,
    String? city,
    bool? onlyAvailable,
  }) {
    return WorkersFilter(
      category: category ?? this.category,
      city: city ?? this.city,
      onlyAvailable: onlyAvailable ?? this.onlyAvailable,
    );
  }
}

class WorkersFilterNotifier extends Notifier<WorkersFilter> {
  @override
  WorkersFilter build() => const WorkersFilter();

  void update(WorkersFilter filter) {
    state = filter;
  }
}

final workersFilterProvider =
    NotifierProvider<WorkersFilterNotifier, WorkersFilter>(
      WorkersFilterNotifier.new,
    );

final workersListProvider = FutureProvider.autoDispose<List<Worker>>((
  ref,
) async {
  final repo = ref.read(workersRepositoryProvider);
  final filter = ref.watch(workersFilterProvider);
  return repo.list(
    category: filter.category,
    city: filter.city,
    onlyAvailable: filter.onlyAvailable,
  );
});
