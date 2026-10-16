import 'package:flutter/material.dart';

import '../../../billing/presentation/pages/charges_list_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../workers/presentation/pages/workers_catalog_page.dart';

/// Contenedor principal con la navegación inferior de la app.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  // Pestañas: catálogo de oficios, cobros/pagos y perfil.
  static const List<Widget> _pages = [
    WorkersCatalogPage(),
    ChargesListPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Catálogo'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'Cobros'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
