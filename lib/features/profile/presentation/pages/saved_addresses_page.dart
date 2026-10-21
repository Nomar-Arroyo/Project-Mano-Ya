import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../shared/widgets/city_autocomplete_field.dart';
import '../../domain/saved_address.dart';
import '../profile_provider.dart';

/// Pantalla de direcciones/zonas guardadas del cliente.
///
/// El mega-prompt pide que el perfil del cliente incluya sus zonas guardadas
/// para agilizar la solicitud de servicios. Las direcciones se guardan en la
/// tabla `saved_addresses` de Supabase o en memoria mientras tanto.
class SavedAddressesPage extends ConsumerWidget {
  const SavedAddressesPage({super.key});

  /// Abre el formulario para guardar una nueva dirección.
  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    final address = await showModalBottomSheet<SavedAddress>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddAddressSheet(),
    );
    if (address == null) return;

    await ref.read(profileControllerProvider.notifier).addAddress(address);
    ref.invalidate(savedAddressesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(savedAddressesProvider);
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(title: const Text('Direcciones guardadas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Agregar dirección'),
      ),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('No se pudieron cargar las direcciones: $error'),
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: surface,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Guarda las zonas donde más solicitas servicios para '
                  'encontrar trabajadores cercanos más rápido.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Card(
                color: surface,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Todavía no tienes direcciones guardadas',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Agrega "Casa" u "Oficina" para usarlas '
                        'directamente al cotizar.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map(
                (address) => Card(
                  color: surface,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(
                      address.isPrimary
                          ? Icons.home_work_outlined
                          : Icons.place_outlined,
                      color: address.isPrimary
                          ? ManoYaColors.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    title: Row(
                      children: [
                        Text(
                          address.label.isEmpty ? 'Dirección' : address.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (address.isPrimary) ...[
                          const SizedBox(width: 8),
                          const Chip(
                            label: Text('Principal'),
                            labelStyle: TextStyle(fontSize: 11),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(address.address),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        final controller = ref.read(
                          profileControllerProvider.notifier,
                        );
                        if (value == 'primary') {
                          await controller.setPrimaryAddress(address.id);
                        } else if (value == 'delete') {
                          await controller.removeAddress(address.id);
                        }
                        ref.invalidate(savedAddressesProvider);
                      },
                      itemBuilder: (context) => [
                        if (!address.isPrimary)
                          const PopupMenuItem(
                            value: 'primary',
                            child: Text('Marcar como principal'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

/// Formulario para guardar una dirección con etiqueta y coordenadas.
class _AddAddressSheet extends ConsumerStatefulWidget {
  const _AddAddressSheet();

  @override
  ConsumerState<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<_AddAddressSheet> {
  final _labelCtrl = TextEditingController();
  String? _addressText;
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  /// Guarda la dirección elegida en el backend.
  Future<void> _save() async {
    final text = _addressText;
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Busca y selecciona una dirección')),
      );
      return;
    }

    setState(() => _saving = true);
    final address = SavedAddress(
      id: '',
      label: _labelCtrl.text.trim().isEmpty
          ? 'Dirección'
          : _labelCtrl.text.trim(),
      address: text,
      latitude: _latitude ?? 0,
      longitude: _longitude ?? 0,
    );
    await ref.read(profileControllerProvider.notifier).addAddress(address);
    if (!mounted) return;
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nueva dirección',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Etiqueta (Casa, Oficina, Bodega...)',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          CityAutocompleteField(
            label: 'Dirección o zona',
            onSelected: (place) => setState(() {
              _addressText = place.displayName;
              _latitude = place.latitude;
              _longitude = place.longitude;
            }),
            onCleared: () => setState(() {
              _addressText = null;
              _latitude = null;
              _longitude = null;
            }),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar dirección'),
          ),
        ],
      ),
    );
  }
}
