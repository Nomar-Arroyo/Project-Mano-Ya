import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../auth/presentation/auth_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _available = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, ',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            Text('Rol:  | Ciudad: '),
            const SizedBox(height: 24),
            if (state.role == null ? false : state.role!.name == 'worker') ...[
              const Text(
                'Disponibilidad (Trabajador)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _available,
                onChanged: (v) => setState(() => _available = v),
                title: Text(
                  _available
                      ? 'Disponible para trabajar'
                      : 'En descanso / Ocupado',
                ),
                subtitle: Text(
                  _available
                      ? 'Badge verde en catálogo'
                      : 'No aparecerá como disponible',
                ),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
          ],
        ),
      ),
    );
  }
}
