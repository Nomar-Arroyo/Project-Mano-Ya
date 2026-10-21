import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../workers/domain/worker.dart';
import '../../workers/presentation/workers_provider.dart';
import '../data/profile_repository.dart';
import '../domain/saved_address.dart';
import '../domain/worker_profile.dart';

/// Repositorio del perfil extendido (portafolio, cobro, direcciones, favoritos).
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository.instance,
);

/// Id del usuario conectado.
///
/// Cuando la app trabaja en modo mock se usa el identificador `mock_user`,
/// de modo que las distintas pantallas comparten la misma sesión de prueba.
final currentUserIdProvider = Provider<String>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.userId ?? 'mock_user';
});

/// Perfil extendido del trabajador (bio, categoría, datos de cobro, etc.).
final workerProfileProvider = FutureProvider.autoDispose<WorkerProfile>((
  ref,
) async {
  final auth = ref.watch(authStateProvider);
  return ref
      .read(profileRepositoryProvider)
      .loadWorkerProfile(
        userId: ref.watch(currentUserIdProvider),
        displayName: auth.displayName ?? '',
        phone: auth.phone,
        city: auth.city,
        avatarUrl: auth.avatarUrl,
      );
});

/// Portafolio express del trabajador (entre 3 y 5 fotos).
final portfolioProvider = FutureProvider.autoDispose<List<PortfolioItem>>((
  ref,
) async {
  return ref
      .read(profileRepositoryProvider)
      .loadPortfolio(ref.watch(currentUserIdProvider));
});

/// Direcciones/zonas guardadas por el cliente.
final savedAddressesProvider = FutureProvider.autoDispose<List<SavedAddress>>((
  ref,
) async {
  return ref
      .read(profileRepositoryProvider)
      .loadAddresses(ref.watch(currentUserIdProvider));
});

/// Ids de los contratistas favoritos del cliente.
final favoriteWorkerIdsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  return ref
      .read(profileRepositoryProvider)
      .loadFavoriteWorkerIds(ref.watch(currentUserIdProvider));
});

/// Detalle completo de los contratistas favoritos (resuelve los ids del
/// catálogo para poder mostrar la información en la pantalla de favoritos).
final favoriteWorkersProvider = FutureProvider.autoDispose<List<Worker>>((
  ref,
) async {
  final ids = await ref.watch(favoriteWorkerIdsProvider.future);
  if (ids.isEmpty) return const [];
  final workersRepository = ref.watch(workersRepositoryProvider);
  final workers = <Worker>[];
  for (final id in ids) {
    final worker = await workersRepository.getById(id);
    if (worker != null) workers.add(worker);
  }
  return workers;
});

/// Controlador con las acciones de escritura del perfil.
///
/// Centraliza las operaciones (guardar bio,(admin portafolio, guardar datos de
/// cobro, direcciones y favoritos) y refresca los providers de lectura para
/// que la interfaz se actualice sin recargar la pantalla completa.
final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, void>(ProfileController.new);

/// Controlador de acciones del perfil extendido.
class ProfileController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Guarda la bio del trabajador y refresca el perfil.
  Future<void> saveBio(String bio) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .saveBio(userId: ref.read(currentUserIdProvider), bio: bio);
      ref.invalidate(workerProfileProvider);
    });
  }

  /// Agrega una foto al portafolio del trabajador.
  Future<void> addPortfolioImage({
    required String imageUrl,
    String caption = '',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .addPortfolioItem(
            userId: ref.read(currentUserIdProvider),
            imageUrl: imageUrl,
            caption: caption,
          );
      ref.invalidate(portfolioProvider);
    });
  }

  /// Elimina una foto del portafolio del trabajador.
  Future<void> removePortfolioImage(String itemId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .removePortfolioItem(
            userId: ref.read(currentUserIdProvider),
            itemId: itemId,
          );
      ref.invalidate(portfolioProvider);
    });
  }

  /// Guarda los datos financieros de cobro del trabajador.
  Future<void> savePayout(PayoutInfo payout) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = ref.read(currentUserIdProvider);
      final repository = ref.read(profileRepositoryProvider);
      final profile = await repository.loadWorkerProfile(userId: userId);
      await repository.saveWorkerProfile(profile.copyWith(payout: payout));
      ref.invalidate(workerProfileProvider);
    });
  }

  /// Guarda una nueva dirección del cliente.
  Future<void> addAddress(SavedAddress address) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .addAddress(
            userId: ref.read(currentUserIdProvider),
            address: address,
          );
      ref.invalidate(savedAddressesProvider);
    });
  }

  /// Elimina una dirección del cliente.
  Future<void> removeAddress(String addressId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .removeAddress(
            userId: ref.read(currentUserIdProvider),
            addressId: addressId,
          );
      ref.invalidate(savedAddressesProvider);
    });
  }

  /// Marca una dirección como principal.
  Future<void> setPrimaryAddress(String addressId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .setPrimaryAddress(
            userId: ref.read(currentUserIdProvider),
            addressId: addressId,
          );
      ref.invalidate(savedAddressesProvider);
    });
  }

  /// Marca un trabajador como favorito del cliente.
  Future<void> addFavorite(String workerId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .addFavorite(
            userId: ref.read(currentUserIdProvider),
            workerId: workerId,
          );
      ref.invalidate(favoriteWorkerIdsProvider);
      ref.invalidate(favoriteWorkersProvider);
    });
  }

  /// Quita un trabajador de los favoritos del cliente.
  Future<void> removeFavorite(String workerId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .removeFavorite(
            userId: ref.read(currentUserIdProvider),
            workerId: workerId,
          );
      ref.invalidate(favoriteWorkerIdsProvider);
      ref.invalidate(favoriteWorkersProvider);
    });
  }
}
