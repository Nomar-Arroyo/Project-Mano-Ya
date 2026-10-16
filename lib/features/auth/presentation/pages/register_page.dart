import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../auth_provider.dart';
import '../../domain/auth_state.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/city_autocomplete_field.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _cityName;
  UserRole _role = UserRole.client;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    ref.listen<AuthState>(authStateProvider, (_, s) {
      if (s.isAuthenticated) context.go('/home');
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Crear cuenta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ManoYaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.client,
                      label: Text('Cliente'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment(
                      value: UserRole.worker,
                      label: Text('Trabajador'),
                      icon: Icon(Icons.handyman),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                  ),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                // Zona/ciudad con autocompletado geolocalizado (Nominatim).
                CityAutocompleteField(
                  label: 'Ciudad/Zona',
                  initialText: _cityName,
                  onSelected: (place) => _cityName = place.displayName,
                  onCleared: () => _cityName = null,
                ),
                if (_role == UserRole.worker) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Perfil de Trabajador (MVP)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Categoría principal: Construcción / Belleza / Costura / Mantenimiento / Automotriz / Eventos (sección Catálogo a completar)',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toggle de disponibilidad se gestiona desde el perfil',
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: state.loading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            ref
                                .read(authStateProvider.notifier)
                                .register(
                                  name: _nameCtrl.text,
                                  email: _emailCtrl.text,
                                  password: _passCtrl.text,
                                  role: _role,
                                  phone: _phoneCtrl.text,
                                  city: _cityName,
                                );
                          }
                        },
                  child: state.loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Registrarse'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: state.loading
                      ? null
                      : () => ref
                            .read(authStateProvider.notifier)
                            .signInWithGoogle(_role),
                  child: const Text('Registrarse con Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
