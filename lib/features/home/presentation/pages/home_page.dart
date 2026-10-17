import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_provider.dart';
import '../../../billing/presentation/pages/charges_list_page.dart';
import '../../../jobs/presentation/pages/dashboard_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../shared/models/user_role.dart';
import '../../../workers/presentation/pages/workers_catalog_page.dart';

/// Contenedor principal con la navegación inferior de la app.
///
/// Las pestañas se adaptan al rol: el cliente cuenta con el catálogo de
/// oficios para contratar, mientras que el trabajador se centra en su panel
/// de trabajos, sus cobros y su perfil.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final role =
        ref.watch(authStateProvider.select((state) => state.role)) ??
        UserRole.client;
    final isWorker = role == UserRole.worker;

    final pages = <Widget>[
      const DashboardPage(),
      if (!isWorker) const WorkersCatalogPage(),
      const ChargesListPage(),
      const ProfilePage(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Inicio',
      ),
      if (!isWorker)
        const NavigationDestination(
          icon: Icon(Icons.search),
          selectedIcon: Icon(Icons.search),
          label: 'Catálogo',
        ),
      const NavigationDestination(
        icon: Icon(Icons.payments_outlined),
        selectedIcon: Icon(Icons.payments),
        label: 'Cobros',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Perfil',
      ),
    ];

    // Si el rol cambia y la pestaña actual ya no existe, ajustamos el índice.
    final safeIndex = _index < pages.length ? _index : pages.length - 1;

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }
}
