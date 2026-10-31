import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/whatsapp_service.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../requests/presentation/pages/request_form_page.dart';
import '../../domain/worker_categories.dart';
import '../../../shared/widgets/city_autocomplete_field.dart';
import '../../../shared/widgets/async_state_views.dart';
import '../../data/worker_contact_service.dart';
import '../../domain/worker.dart';
import '../workers_provider.dart';
import '../widgets/worker_card.dart';

/// Catálogo de oficios: filtros por oficio, zona geolocalizada y
/// disponibilidad, con acciones de contacto por WhatsApp y solicitud.
class WorkersCatalogPage extends ConsumerWidget {
  const WorkersCatalogPage({super.key});

  /// Categorías principales de oficios de Mano Ya.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(workersFilterProvider);
    final workersAsync = ref.watch(workersListProvider);
    final notifier = ref.read(workersFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Oficios'),
        actions: [
          IconButton(
            tooltip: 'Asistente para encontrar un trabajador',
            onPressed: () => context.push('/assistant'),
            icon: const Icon(Icons.auto_awesome),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Filtro por zona/ciudad con autocompletado geolocalizado.
            CityAutocompleteField(
              label: 'Buscar por ciudad/zona',
              initialText: filter.cityName,
              onSelected: (place) => notifier.setCity(
                place.displayName,
                place.latitude,
                place.longitude,
              ),
              onCleared: () => notifier.setCity(null, null, null),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilterChip(
                  label: const Text('Solo disponibles'),
                  selected: filter.onlyAvailable,
                  onSelected: notifier.setOnlyAvailable,
                ),
                const Spacer(),
                if (filter.originLat != null)
                  const Text(
                    'Ordenado por cercanía',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Categorías principales de oficios.
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: WorkerCategories.categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = WorkerCategories.categories[index];
                  final selected = filter.category == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (value) =>
                        notifier.setCategory(value ? cat : null),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: workersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => ErrorView(
                  message:
                      'No se pudo cargar el catálogo. Revisa tu conexión '
                      'e inténtalo de nuevo.',
                  onRetry: () => ref.invalidate(workersListProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('No se encontraron trabajadores'),
                    );
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final worker = list[index];
                      return WorkerCard(
                        worker: worker,
                        onTap: () => context.push('/worker/${worker.id}'),
                        onWhatsApp: () => _openWhatsApp(context, ref, worker),
                        onRequest: () => _openRequest(context, worker),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Abre el formulario de solicitud de presupuesto.
  void _openRequest(BuildContext context, Worker worker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestFormPage(
          workerId: worker.id,
          workerName: worker.name,
          workerCategory: worker.category,
        ),
      ),
    );
  }

  // Abre WhatsApp con un mensaje estructurado para contactar al trabajador.
  Future<void> _openWhatsApp(
    BuildContext context,
    WidgetRef ref,
    Worker worker,
  ) async {
    String? emailError;
    var emailSent = false;
    try {
      emailSent = await WorkerContactService.sendContactCard(worker);
    } catch (error) {
      emailError = error.toString().replaceFirst('Bad state: ', '');
    }

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
    if (context.mounted && (!ok || emailError != null || emailSent)) {
      final messages = <String>[
        if (emailSent) 'Enviamos la ficha a tu correo.',
        if (emailError != null)
          '$emailError ${ok ? '' : 'No se pudo abrir WhatsApp.'}',
        if (!ok && emailError == null)
          'No se pudo abrir WhatsApp en este dispositivo.',
      ];
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(messages.join(' '))));
    }
  }
}
