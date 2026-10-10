import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/ai_screen.dart';
import '../../features/appointments/appointments_screen.dart';
import '../../features/authentication/auth_controller.dart';
import '../../features/authentication/auth_screens.dart';
import '../../features/doctor_directory/discover_screens.dart';
import '../../features/emergency/emergency_screen.dart';
import '../../features/medical_records/records_screen.dart';
import '../../features/medications/medications_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/patient_home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/settings_screens.dart';
import '../../features/sensors/safety_check_screen.dart';
import '../design/nav_bar.dart';
import '../design/palette.dart';

final onboardedProvider = NotifierProvider<OnboardedNotifier, bool?>(
  OnboardedNotifier.new,
);

class OnboardedNotifier extends Notifier<bool?> {
  @override
  bool? build() {
    isOnboarded().then((v) => state = v);
    return null;
  }

  void done() => state = true;
}

/// Bridges Riverpod state changes to GoRouter redirects.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(onboardedProvider, (_, _) => notifyListeners());
  }
}

CustomTransitionPage<void> _fade(
  GoRouterState s,
  Widget child,
) => CustomTransitionPage<void>(
  key: s.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 220),
  transitionsBuilder: (context, animation, _, c) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: c,
    ),
  ),
);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final onboarded = ref.read(onboardedProvider);
      final loc = state.matchedLocation;
      if (auth.status == AuthStatus.unknown || onboarded == null) {
        return loc == '/splash' ? null : '/splash';
      }
      final publicRoute =
          loc == '/login' ||
          loc == '/register' ||
          loc == '/reset' ||
          loc == '/onboarding';
      if (auth.status == AuthStatus.unauthenticated) {
        if (!onboarded) return loc == '/onboarding' ? null : '/onboarding';
        return publicRoute && loc != '/onboarding' ? null : '/login';
      }
      if (publicRoute || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) =>
            OnboardingScreen(onDone: ref.read(onboardedProvider.notifier).done),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (c, s) => _fade(s, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (c, s) => _fade(s, const RegisterScreen()),
      ),
      GoRoute(
        path: '/reset',
        pageBuilder: (c, s) => _fade(s, const ResetPasswordScreen()),
      ),
      GoRoute(
        path: '/safety-check',
        builder: (_, _) => const SafetyCheckScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _Shell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (c, s) => NoTransitionPage(child: const HomeScreen()),
          ),
          GoRoute(
            path: '/discover',
            pageBuilder: (c, s) =>
                NoTransitionPage(child: const DiscoverScreen()),
          ),
          GoRoute(
            path: '/appointments',
            pageBuilder: (c, s) =>
                NoTransitionPage(child: const AppointmentsScreen()),
          ),
          GoRoute(
            path: '/emergency',
            pageBuilder: (c, s) =>
                NoTransitionPage(child: const EmergencyScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (c, s) =>
                NoTransitionPage(child: const ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/doctor/:id',
        pageBuilder: (c, s) =>
            _fade(s, DoctorDetailScreen(doctorId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/hospital/:id',
        pageBuilder: (c, s) =>
            _fade(s, HospitalDetailScreen(hospitalId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/records',
        pageBuilder: (c, s) => _fade(s, const RecordsScreen()),
      ),
      GoRoute(
        path: '/record/:id',
        pageBuilder: (c, s) =>
            _fade(s, RecordDetailScreen(recordId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/patient/:id/records',
        pageBuilder: (c, s) => _fade(
          s,
          RecordsScreen(
            patientId: s.pathParameters['id'],
            patientName: s.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: '/medications',
        pageBuilder: (c, s) => _fade(s, const MedicationsScreen()),
      ),
      GoRoute(
        path: '/assistant',
        pageBuilder: (c, s) => _fade(s, const AiAssistantScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (c, s) => _fade(s, const NotificationsScreen()),
      ),
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (c, s) => _fade(s, const EditProfileScreen()),
      ),
      GoRoute(
        path: '/profile/contacts',
        pageBuilder: (c, s) => _fade(s, const ContactsScreen()),
      ),
      GoRoute(
        path: '/profile/sensors',
        pageBuilder: (c, s) => _fade(s, const SensorSettingsScreen()),
      ),
      GoRoute(
        path: '/profile/privacy',
        pageBuilder: (c, s) => _fade(s, const PrivacyScreen()),
      ),
      GoRoute(
        path: '/profile/availability',
        pageBuilder: (c, s) => _fade(s, const AvailabilityScreen()),
      ),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: p.ink,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.favorite_rounded, color: p.paper, size: 32),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 90,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: p.teal,
                backgroundColor: p.line,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.location, required this.child});
  final String location;
  final Widget child;

  static const _tabs = [
    '/',
    '/discover',
    '/appointments',
    '/emergency',
    '/profile',
  ];
  static const _items = [
    NavItem(Icons.home_outlined, Icons.home_rounded, 'ទំព័រដើម', 'Home'),
    NavItem(Icons.search_rounded, Icons.search_rounded, 'ស្វែងរក', 'Discover'),
    NavItem(Icons.event_outlined, Icons.event_rounded, 'ណាត់ជួប', 'Visits'),
    NavItem(
      Icons.emergency_outlined,
      Icons.emergency_rounded,
      'បន្ទាន់',
      'Emergency',
    ),
    NavItem(
      Icons.person_outline_rounded,
      Icons.person_rounded,
      'ខ្ញុំ',
      'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    var index = _tabs.indexOf(location);
    if (index < 0) index = 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: AppNavBar(
        items: _items,
        index: index,
        emergencyIndex: 3,
        onSelect: (i) => context.go(_tabs[i]),
      ),
    );
  }
}
