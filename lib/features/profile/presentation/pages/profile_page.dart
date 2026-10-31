import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/venezuelan_phone_input_formatter.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../workers/presentation/availability_provider.dart';
import '../profile_provider.dart';

/// Pantalla principal del perfil de usuario.
///
/// Muestra los datos del usuario y las opciones que dependen del rol:
/// - Trabajador: portafolio express, datos de cobro y disponibilidad.
/// - Cliente: direcciones guardadas, favoritos e historial de servicios.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  /// Etiqueta legible del rol del usuario.
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

  /// Activa o desactiva la verificación en dos pasos.
  ///
  /// Al activar se genera el QR y el secreto: el usuario debe escanearlo y
  /// confirmar con el primer código para que el factor quede verificado.
  Future<void> _toggleTwoFactor(BuildContext context, bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authStateProvider.notifier).setTwoFactor(enabled);
      if (!context.mounted) return;
      if (enabled) {
        context.push('/two-factor');
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Verificación en 2 pasos desactivada'),
            backgroundColor: ManoYaColors.success,
          ),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar la verificación: $error'),
          backgroundColor: ManoYaColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isWorker = state.role == UserRole.worker;
    final available = ref.watch(workerAvailabilityProvider);
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final tileShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
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
            // --- Encabezado con los datos del usuario ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.22,
                              ),
                              width: 2,
                            ),
                          ),
                          child: UserAvatar(
                            imageUrl: state.avatarUrl,
                            name: state.displayName,
                            radius: 32,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MI PERFIL',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.displayName?.trim().isNotEmpty == true
                                    ? state.displayName!
                                    : 'Bienvenido',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              _ProfileBadge(label: _roleLabel(state.role)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (state.email?.isNotEmpty == true ||
                        state.city?.isNotEmpty == true ||
                        state.phone?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      if (state.email?.isNotEmpty == true)
                        _ProfileDetail(
                          icon: Icons.mail_outline,
                          value: state.email!,
                        ),
                      if (state.city?.isNotEmpty == true)
                        _ProfileDetail(
                          icon: Icons.location_on_outlined,
                          value: state.city!,
                        ),
                      if (state.phone?.isNotEmpty == true)
                        _ProfileDetail(
                          icon: Icons.phone_outlined,
                          value:
                              VenezuelanPhoneInputFormatter.formatInternational(
                                state.phone!,
                              ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Opciones del rol trabajador ---
            if (isWorker) ...[
              const Text(
                'Mi perfil de trabajador',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const _BioCard(),
              const SizedBox(height: 10),
              const _PortfolioTile(),
              const SizedBox(height: 10),
              const _PayoutTile(),
              const SizedBox(height: 10),
              SwitchListTile(
                value: available,
                onChanged: (v) =>
                    ref.read(workerAvailabilityProvider.notifier).set(v),
                title: const Text('Disponible para trabajar'),
                subtitle: Text(
                  available
                      ? 'Badge verde en catálogo'
                      : 'No aparecerá como disponible',
                ),
                tileColor: surface,
                shape: tileShape,
              ),
              const SizedBox(height: 24),
            ] else ...[
              // --- Opciones del rol cliente ---
              const Text(
                'Mi perfil de cliente',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const _AddressesTile(),
              const SizedBox(height: 10),
              const _FavoritesTile(),
              const SizedBox(height: 10),
              const _HistoryTile(),
              const SizedBox(height: 10),
              const _ReportsTile(),
              const SizedBox(height: 24),
            ],

            // --- Opciones comunes ---
            const Text(
              'Seguridad',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: state.twoFactorEnabled,
              onChanged: (v) => _toggleTwoFactor(context, v),
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
              'Información legal',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Card(
              color: surface,
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.cookie_outlined),
                title: const Text('Política de cookies'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/cookies'),
              ),
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
}

class _ProfileBadge extends StatelessWidget {
  final String label;

  const _ProfileBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ProfileDetail({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta que muestra la bio del trabajador.
class _BioCard extends ConsumerWidget {
  const _BioCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(workerProfileProvider);
    final surface = Theme.of(context).colorScheme.surface;

    return Card(
      color: surface,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: const Text('Mi presentación'),
        subtitle: Text(
          profile.maybeWhen(
            data: (data) => data.bio.isEmpty
                ? 'Cuenta tu experiencia para generar confianza.'
                : data.bio,
            orElse: () => 'Cargando...',
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/profile/edit'),
      ),
    );
  }
}

/// Acceso al portafolio express del trabajador.
class _PortfolioTile extends ConsumerWidget {
  const _PortfolioTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(portfolioProvider);
    final surface = Theme.of(context).colorScheme.surface;

    return Card(
      color: surface,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.photo_library_outlined),
        title: const Text('Portafolio de trabajos'),
        subtitle: Text(
          portfolio.maybeWhen(
            data: (items) => items.isEmpty
                ? 'Agrega entre 3 y 5 fotos de tus trabajos'
                : '${items.length} de 5 fotos cargadas',
            orElse: () => 'Cargando...',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/profile/portfolio'),
      ),
    );
  }
}

/// Acceso a los datos financieros de cobro del trabajador.
class _PayoutTile extends ConsumerWidget {
  const _PayoutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(workerProfileProvider);
    final surface = Theme.of(context).colorScheme.surface;

    return Card(
      color: surface,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.payments_outlined),
        title: const Text('Mis datos de cobro'),
        subtitle: Text(
          profile.maybeWhen(
            data: (data) => data.payout.isConfigured
                ? '${data.payout.method} configurado'
                : 'Configura tu método de pago',
            orElse: () => 'Cargando...',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/profile/payout'),
      ),
    );
  }
}

/// Acceso a las direcciones guardadas del cliente.
class _AddressesTile extends ConsumerWidget {
  const _AddressesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(savedAddressesProvider);
    final surface = Theme.of(context).colorScheme.surface;

    return Card(
      color: surface,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.home_work_outlined),
        title: const Text('Mis direcciones guardadas'),
        subtitle: Text(
          addresses.maybeWhen(
            data: (items) => items.isEmpty
                ? 'Guarda Casa, Oficina u otras zonas'
                : '${items.length} direcciones guardadas',
            orElse: () => 'Cargando...',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/profile/addresses'),
      ),
    );
  }
}

/// Acceso a los contratistas favoritos del cliente.
class _FavoritesTile extends ConsumerWidget {
  const _FavoritesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteWorkerIdsProvider);
    final surface = Theme.of(context).colorScheme.surface;

    return Card(
      color: surface,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.favorite_border),
        title: const Text('Mis favoritos'),
        subtitle: Text(
          favorites.maybeWhen(
            data: (items) => items.isEmpty
                ? 'Guarda a los trabajadores que prefieras'
                : '${items.length} trabajadores guardados',
            orElse: () => 'Cargando...',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/profile/favorites'),
      ),
    );
  }
}

/// Acceso al historial de servicios del cliente.
class _HistoryTile extends ConsumerWidget {
  const _HistoryTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = Theme.of(context).colorScheme.surface;

    return Card(
      color: surface,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.history),
        title: const Text('Historial de servicios'),
        subtitle: const Text('Consulta tus servicios y comprobantes de pago'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/profile/history'),
      ),
    );
  }
}

/// Acceso a los reportes enviados por el usuario.
class _ReportsTile extends ConsumerWidget {
  const _ReportsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = Theme.of(context).colorScheme.surface;

    return Card(
      color: surface,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.support_agent),
        title: const Text('Mis reportes'),
        subtitle: const Text('Consulta el estado de los reportes enviados'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/reports'),
      ),
    );
  }
}
