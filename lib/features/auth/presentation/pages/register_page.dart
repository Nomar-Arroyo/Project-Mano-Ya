import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../auth_provider.dart';
import '../../domain/auth_state.dart';
import '../../../shared/models/user_role.dart';
import '../../../../core/services/maps_service.dart';

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
  final _cityCtrl = TextEditingController();
  UserRole _role = UserRole.client;
  List<String> _cities = [];
  bool _loadingCities = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchCities(String q) async {
    setState(() => _loadingCities = true);
    _cities = await MapsService.autocompleteCity(q);
    setState(() => _loadingCities = false);
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
                TextFormField(
                  controller: _cityCtrl,
                  decoration: InputDecoration(
                    labelText: 'Ciudad/Zona',
                    suffixIcon: _loadingCities
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  onChanged: _searchCities,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                if (_cities.isNotEmpty)
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      itemCount: _cities.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(_cities[i]),
                        onTap: () => setState(() {
                          _cityCtrl.text = _cities[i];
                          _cities.clear();
                        }),
                      ),
                    ),
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
                                  city: _cityCtrl.text,
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
