import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workers_provider.dart';
import '../widgets/worker_card.dart';
import '../../../requests/presentation/pages/request_form_page.dart';

class WorkersCatalogPage extends ConsumerWidget {
  const WorkersCatalogPage({super.key});

  static const List<String> categories = [
    'Todas',
    'Construcción',
    'Belleza',
    'Costura',
    'Mantenimiento',
    'Automotriz',
    'Eventos',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(workersFilterProvider);
    final workersAsync = ref.watch(workersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar por ciudad/zona',
                    ),
                    onChanged: (v) => ref
                        .read(workersFilterProvider.notifier)
                        .update(filter.copyWith(city: v)),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('Solo disponibles'),
                  selected: filter.onlyAvailable,
                  onSelected: (v) => ref
                      .read(workersFilterProvider.notifier)
                      .update(filter.copyWith(onlyAvailable: v)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (context, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = categories[i];
                  final selected =
                      (cat == 'Todas' && filter.category == null) ||
                      filter.category == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (selected) {
                      ref
                          .read(workersFilterProvider.notifier)
                          .update(
                            filter.copyWith(
                              category: cat == 'Todas' ? null : cat,
                            ),
                          );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: workersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    const Center(child: Text('Error al cargar trabajadores')),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('No se encontraron trabajadores'),
                    );
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) => WorkerCard(
                      worker: list[i],
                      onRequest: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RequestFormPage(
                              workerId: list[i].id,
                              workerName: list[i].name,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
