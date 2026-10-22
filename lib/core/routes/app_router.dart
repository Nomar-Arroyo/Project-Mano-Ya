import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/two_factor_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/profile/presentation/pages/favorites_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/profile/presentation/pages/saved_addresses_page.dart';
import '../../features/profile/presentation/pages/service_history_page.dart';
import '../../features/profile/presentation/pages/worker_payout_page.dart';
import '../../features/profile/presentation/pages/worker_portfolio_page.dart';
import '../../features/reports/presentation/pages/my_reports_page.dart';
import '../../features/reports/presentation/pages/report_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/workers/presentation/pages/worker_detail_page.dart';

/// Rutas de la aplicación.
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/two-factor', builder: (_, _) => const TwoFactorPage()),
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const ProfileEditPage(),
      ),

      // Perfil del trabajador.
      GoRoute(
        path: '/profile/portfolio',
        builder: (_, _) => const WorkerPortfolioPage(),
      ),
      GoRoute(
        path: '/profile/payout',
        builder: (_, _) => const WorkerPayoutPage(),
      ),

      // Perfil del cliente.
      GoRoute(
        path: '/profile/addresses',
        builder: (_, _) => const SavedAddressesPage(),
      ),
      GoRoute(
        path: '/profile/favorites',
        builder: (_, _) => const FavoritesPage(),
      ),
      GoRoute(
        path: '/profile/history',
        builder: (_, _) => const ServiceHistoryPage(),
      ),

      GoRoute(
        path: '/worker/:id',
        builder: (_, state) =>
            WorkerDetailPage(workerId: state.pathParameters['id']!),
      ),

      // Reportes y denuncias.
      GoRoute(path: '/reports', builder: (_, _) => const MyReportsPage()),
      GoRoute(
        path: '/reports/new',
        builder: (_, state) {
          final params = state.extra as Map<String, dynamic>?;
          return ReportPage(
            targetUserId: params?['targetUserId'] as String?,
            targetName: params?['targetName'] as String?,
            jobId: params?['jobId'] as String?,
          );
        },
      ),
    ],
  );
}
