import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../jobs/presentation/jobs_provider.dart';

/// Formulario de solicitud de presupuesto a un trabajador.
///
/// Al enviar se crea la solicitud real en la tabla `jobs` de Supabase (a
/// través de `JobsRepository.createRequest`) y solo se cierra la pantalla
/// cuando la operación termina bien.
class RequestFormPage extends ConsumerStatefulWidget {
  final String workerId;
  final String workerName;

  /// Oficio del trabajador (nombre de la categoría en la base de datos).
  final String workerCategory;

  const RequestFormPage({
    super.key,
    required this.workerId,
    required this.workerName,
    this.workerCategory = '',
  });

  @override
  ConsumerState<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends ConsumerState<RequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _type = 'Servicio estándar';
  bool _sending = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _dateCtrl.dispose();
    _addressCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Solicitar a ${widget.workerName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción del trabajo',
                ),
                minLines: 3,
                maxLines: 5,
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fecha requerida (dd/mm/aaaa)',
                ),
                validator: (v) => _parseDate(v ?? '') == null
                    ? 'Usa el formato dd/mm/aaaa'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección o zona del servicio (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Presupuesto estimado en COP (opcional)',
                  hintText: '150000',
                ),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return null;
                  final price = _parsePrice(text);
                  if (price == null || price <= 0) {
                    return 'Escribe un valor válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: const [
                  DropdownMenuItem(
                    value: 'Servicio estándar',
                    child: Text('Servicio estándar'),
                  ),
                  DropdownMenuItem(
                    value: 'Proyecto grande/Obra',
                    child: Text('Proyecto grande/Obra'),
                  ),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
                decoration: const InputDecoration(
                  labelText: 'Tipo de servicio',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Fotos de referencia (opcional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.photo_library),
                label: const Text('Adjuntar fotos'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _sending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ManoYaColors.secondary,
                ),
                child: Text(_sending ? 'Enviando...' : 'Enviar solicitud'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Crea la solicitud en el repositorio y cierra la pantalla.
  ///
  /// Si la inserción falla se muestra el error y la pantalla permanece
  /// abierta para que el usuario pueda reintentar.
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final scheduledAt = _parseDate(_dateCtrl.text) ?? DateTime.now();
    final price = _parsePrice(_priceCtrl.text.trim()) ?? 0;
    final auth = ref.read(authStateProvider);

    setState(() => _sending = true);
    try {
      await ref
          .read(jobsControllerProvider)
          .createRequest(
            title: _buildTitle(),
            category: widget.workerCategory.isNotEmpty
                ? widget.workerCategory
                : _type,
            description: _descCtrl.text.trim(),
            price: price,
            scheduledAt: scheduledAt,
            address: _addressCtrl.text.trim(),
            workerId: widget.workerId,
            workerName: widget.workerName,
            clientId: auth.userId,
            clientName: auth.displayName,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada correctamente')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar la solicitud: $error'),
          backgroundColor: ManoYaColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Usa la descripción como título de la solicitud (recortada).
  String _buildTitle() {
    final description = _descCtrl.text.trim().replaceAll('\n', ' ');
    if (description.isEmpty) return _type;
    if (description.length <= 60) return description;
    return '${description.substring(0, 57)}...';
  }

  /// Convierte la fecha escrita (dd/mm/aaaa) en una fecha válida.
  DateTime? _parseDate(String value) {
    final parts = value.trim().split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0].trim());
    final month = int.tryParse(parts[1].trim());
    final year = int.tryParse(parts[2].trim());
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  /// Convierte el presupuesto escrito en un número.
  ///
  /// Acepta el formato venezolano (150.000 o 150,00) con punto o coma como
  /// separador de miles, y el decimal con coma (1500,50).
  double? _parsePrice(String value) {
    final text = value.trim();
    if (text.isEmpty) return 0;
    // Se unifica el separador de miles para poder quitarlo sin ambigüedad.
    final normalized = text.contains(',') && !text.contains('.')
        ? text.replaceAll('.', '').replaceAll(',', '.')
        : text.contains(',')
        ? text.replaceAll('.', '').replaceAll(',', '.')
        : text.replaceAll('.', '');
    return double.tryParse(normalized);
  }
}
