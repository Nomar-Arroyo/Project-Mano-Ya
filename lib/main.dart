import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/routes/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/domain/auth_state.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/workers/presentation/availability_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase (si hay credenciales) y las notificaciones.
  await SupabaseService.init();
  await NotificationService.init();

  // Restaura el tema, la sesión y la disponibilidad guardadas.
  final initialMode = await ThemeModeNotifier.loadSaved();
  final initialAuth = SupabaseService.isConfigured
      ? await AuthRepository().restoreSession()
      : await StorageService.loadSessionMap().then(
          (sessionMap) => sessionMap != null
              ? AuthState.fromJson(sessionMap)
              : const AuthState.unauthenticated(),
        );
  final initialAvailability = await WorkerAvailabilityNotifier.loadSaved();

  runApp(
    ProviderScope(
      overrides: [
        initialThemeModeProvider.overrideWithValue(initialMode),
        initialAuthStateProvider.overrideWithValue(initialAuth),
        initialAvailabilityProvider.overrideWithValue(initialAvailability),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
