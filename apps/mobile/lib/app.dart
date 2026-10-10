import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/design/palette.dart';
import 'core/i18n/language.dart';
import 'core/routing/router.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/auth_controller.dart';
import 'features/notifications/push_service.dart';
import 'features/sensors/sensor_controller.dart';

class HealthResponseApp extends ConsumerStatefulWidget {
  const HealthResponseApp({super.key});

  @override
  ConsumerState<HealthResponseApp> createState() => _HealthResponseAppState();
}

class _HealthResponseAppState extends ConsumerState<HealthResponseApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await languageController.load();
      await ref.read(authControllerProvider.notifier).bootstrap();
      await ref.read(sensorControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isReleaseConfigurationValid) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This build is not configured with a valid HTTPS API address.\n'
                'Rebuild with --dart-define=API_BASE_URL=https://your-api-host.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final router = ref.watch(routerProvider);

    // Register for push once signed in (no-op when Firebase is not configured at build time).
    ref.listen(authControllerProvider.select((s) => s.status), (prev, next) {
      if (next == AuthStatus.authenticated && prev != next) {
        ref.read(pushRegistrarProvider).register();
      }
    });

    // Possible-incident prompt takes over the screen as soon as the detector raises a candidate.
    ref.listen(sensorControllerProvider.select((s) => s.candidate), (
      prev,
      next,
    ) {
      if (prev == null && next != null) router.push('/safety-check');
    });

    return LanguageScope(
      controller: languageController,
      child: ListenableBuilder(
        listenable: languageController,
        builder: (context, _) => MaterialApp.router(
          title: AppConfig.appName,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final p = Palette.of(context);
            return ColoredBox(color: p.paper, child: child);
          },
        ),
      ),
    );
  }
}
