import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/routing/router.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/auth_controller.dart';
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

    // Possible-incident prompt takes over the screen as soon as the detector raises a candidate.
    ref.listen(sensorControllerProvider.select((s) => s.candidate), (
      prev,
      next,
    ) {
      if (prev == null && next != null) router.push('/safety-check');
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
