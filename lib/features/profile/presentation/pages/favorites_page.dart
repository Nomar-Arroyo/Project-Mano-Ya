import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../profile_provider.dart';

/// Pantalla de contratistas favoritos del cliente.
///
/// El mega-prompt incluye los "contratistas favoritos" dentro del perfil del
/// cliente. Los favoritos se guardan en la tabla `favorites` de Supabase o en
/// memoria durante la sesión.
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(favoriteWorkersProvider);
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis favoritos')),
      body: workers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('No se pudieron cargar los favoritos: $error')),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: surface,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Guarda a los trabajadores que más te gusten para volver a '
                  'contactarlos rápido y sin buscar de nuevo.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Card(
                color: surface,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 40,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Todavía no tienes favoritos',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Toca el corazón en la ficha de un trabajador para '
                        'guardarlo aquí.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map(
                (worker) => Card(
                  color: surface,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    leading: UserAvatar(
                      imageUrl: worker.avatarUrl,
                      name: worker.name,
                      radius: 26,
                    ),
                    title: Text(
                      worker.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${worker.subcategory.isEmpty ? worker.category : worker.subcategory}'
                      ' · ${worker.city}\n'
                      '★ ${worker.rating.toStringAsFixed(1)} '
                      '(${worker.reviewsCount} reseñas)',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.favorite,
                        color: ManoYaColors.danger,
                      ),
                      tooltip: 'Quitar de favoritos',
                      onPressed: () async {
                        await ref
                            .read(profileControllerProvider.notifier)
                            .removeFavorite(worker.id);
                        ref.invalidate(favoriteWorkerIdsProvider);
                        ref.invalidate(favoriteWorkersProvider);
                      },
                    ),
                    onTap: () => context.push('/worker/${worker.id}'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
