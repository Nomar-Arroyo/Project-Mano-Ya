import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';

class RequestFormPage extends StatefulWidget {
  final String workerId;
  final String workerName;
  const RequestFormPage({
    super.key,
    required this.workerId,
    required this.workerName,
  });

  @override
  State<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends State<RequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  String _type = 'Servicio estándar';

  @override
  void dispose() {
    _descCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Solicitar a ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
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
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Solicitud enviada correctamente (MVP)'),
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ManoYaColors.secondary,
                ),
                child: const Text('Enviar solicitud'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
