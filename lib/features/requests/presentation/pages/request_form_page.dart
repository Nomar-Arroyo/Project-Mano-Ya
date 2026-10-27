import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/widgets/city_autocomplete_field.dart';
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
  final _locationDetailsCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  DateTime? _selectedDate;
  String _serviceLocation = '';
  String _type = 'Servicio estándar';
  bool _sending = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _locationDetailsCtrl.dispose();
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
              FormField<DateTime>(
                validator: (value) =>
                    value == null ? 'Selecciona la fecha de la cita' : null,
                builder: (field) => InkWell(
                  onTap: () => _selectDate(field),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha de la cita',
                      suffixIcon: IconButton(
                        tooltip: 'Abrir calendario',
                        onPressed: () => _selectDate(field),
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                      errorText: field.errorText,
                    ),
                    child: Text(
                      field.value == null
                          ? 'Seleccionar fecha'
                          : Formatters.date(field.value!),
                    ),
                  ),
                ),
                initialValue: _selectedDate,
              ),
              const SizedBox(height: 12),
              CityAutocompleteField(
                label: 'Localidad, parroquia o sector',
                hintText: 'Busca una zona específica',
                helperText: 'Ej.: parroquia, urbanización o sector',
                onSelected: (place) =>
                    setState(() => _serviceLocation = place.displayName),
                onChanged: (value) => _serviceLocation = value,
                onCleared: () => _serviceLocation = '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationDetailsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección o punto de referencia (opcional)',
                  hintText: 'Calle, avenida, edificio o referencia',
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

    final scheduledAt = _selectedDate!;
    final price = _parsePrice(_priceCtrl.text.trim()) ?? 0;
    final auth = ref.read(authStateProvider);
    final locationDetails = _locationDetailsCtrl.text.trim();
    final address = [
      _serviceLocation.trim(),
      if (locationDetails.isNotEmpty) locationDetails,
    ].where((part) => part.isNotEmpty).join(', ');

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
            address: address,
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

  Future<void> _selectDate(FormFieldState<DateTime> field) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 5),
      helpText: 'Selecciona la fecha de la cita',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (selectedDate == null || !mounted) return;
    setState(() {
      _selectedDate = DateUtils.dateOnly(selectedDate);
    });
    field.didChange(_selectedDate);
  }

  /// Usa la descripción como título de la solicitud (recortada).
  String _buildTitle() {
    final description = _descCtrl.text.trim().replaceAll('\n', ' ');
    if (description.isEmpty) return _type;
    if (description.length <= 60) return description;
    return '${description.substring(0, 57)}...';
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
