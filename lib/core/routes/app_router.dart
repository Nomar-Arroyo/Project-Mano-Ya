import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/two_factor_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/workers/presentation/pages/worker_detail_page.dart';

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
      GoRoute(
        path: '/worker/:id',
        builder: (_, state) =>
            WorkerDetailPage(workerId: state.pathParameters['id']!),
      ),
    ],
  );
}
