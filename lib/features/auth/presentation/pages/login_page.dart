import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../auth_provider.dart';
import '../../domain/auth_state.dart';
import '../../../shared/models/user_role.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.client;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    ref.listen<AuthState>(authStateProvider, (_, s) {
      if (!s.isAuthenticated) return;
      // Si el usuario tiene 2FA activo pasa primero por la verificación.
      context.go(s.twoFactorEnabled ? '/two-factor' : '/home');
    });
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Mano Ya',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: ManoYaColors.primary,
                    ),
                  ),
                  const Text(
                    'Tus Oficios a la Mano',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ManoYaColors.muted),
                  ),
                  const SizedBox(height: 30),
                  _roleSelector(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: state.loading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              ref
                                  .read(authStateProvider.notifier)
                                  .loginEmail(
                                    _emailCtrl.text,
                                    _passCtrl.text,
                                    role: _selectedRole,
                                  );
                            }
                          },
                    child: state.loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Iniciar Sesión'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: state.loading
                        ? null
                        : () => ref
                              .read(authStateProvider.notifier)
                              .signInWithGoogle(_selectedRole),
                    child: const Text('Continuar con Google'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleSelector() {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<UserRole>(
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
            selected: {_selectedRole},
            onSelectionChanged: (s) => setState(() => _selectedRole = s.first),
          ),
        ),
      ],
    );
  }
}
