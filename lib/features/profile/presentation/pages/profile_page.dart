import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/models/user_role.dart';
import '../../../workers/presentation/availability_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String _roleLabel(UserRole? role) {
    switch (role) {
      case UserRole.worker:
        return 'Trabajador';
      case UserRole.client:
        return 'Cliente';
      case null:
        return 'No definido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isWorker = state.role == UserRole.worker;
    final available = ref.watch(workerAvailabilityProvider);
    final surface = Theme.of(context).colorScheme.surface;
    final tileShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar perfil',
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _avatar(state),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${state.displayName ?? 'Invitado'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Rol: ${_roleLabel(state.role)} | '
                        'Ciudad: ${state.city?.isNotEmpty == true ? state.city : 'No definida'}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isWorker) ...[
              const Text(
                'Disponibilidad (Trabajador)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: available,
                onChanged: (v) =>
                    ref.read(workerAvailabilityProvider.notifier).set(v),
                title: Text(
                  available
                      ? 'Disponible para trabajar'
                      : 'En descanso / Ocupado',
                ),
                subtitle: Text(
                  available
                      ? 'Badge verde en catálogo'
                      : 'No aparecerá como disponible',
                ),
                tileColor: surface,
                shape: tileShape,
              ),
            ] else ...[
              const Text(
                'Perfil de Cliente',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Puedes buscar y solicitar presupuestos desde el catálogo.',
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Seguridad',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: state.twoFactorEnabled,
              onChanged: (v) =>
                  ref.read(authStateProvider.notifier).setTwoFactor(v),
              title: const Text('Verificación en 2 pasos (2FA)'),
              subtitle: Text(
                state.twoFactorEnabled
                    ? 'Se pedirá un código al iniciar sesión'
                    : 'Desactivado',
              ),
              secondary: const Icon(Icons.lock_outline),
              tileColor: surface,
              shape: tileShape,
            ),
            const SizedBox(height: 24),
            const Text(
              'Apariencia',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: themeMode == ThemeMode.dark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              title: const Text('Tema oscuro'),
              subtitle: Text(
                themeMode == ThemeMode.dark
                    ? 'Activado'
                    : 'Desactivado (usa el tema claro)',
              ),
              secondary: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              tileColor: surface,
              shape: tileShape,
            ),
            const SizedBox(height: 24),
            const Text(
              'Insignias de Confianza',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: const [
                Chip(label: Text('Identidad Verificada')),
                Chip(
                  label: Text(
                    'Trabajo Garantizado',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: ManoYaColors.success,
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(AuthState state) {
    final path = state.avatarUrl;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return CircleAvatar(radius: 32, backgroundImage: FileImage(File(path)));
    }
    final name = state.displayName;
    return CircleAvatar(
      radius: 32,
      child: Text(
        name != null && name.isNotEmpty
            ? name.substring(0, 1).toUpperCase()
            : '?',
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}
