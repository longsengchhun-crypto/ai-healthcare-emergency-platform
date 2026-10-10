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
import '../../features/sensors/safety_check_screen.dart';
import '../theme/app_theme.dart';

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
      GoRoute(
        path: '/splash',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) =>
            OnboardingScreen(onDone: ref.read(onboardedProvider.notifier).done),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/reset', builder: (_, _) => const ResetPasswordScreen()),
      GoRoute(
        path: '/safety-check',
        builder: (_, _) => const SafetyCheckScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _Shell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen()),
          GoRoute(
            path: '/appointments',
            builder: (_, _) => const AppointmentsScreen(),
          ),
          GoRoute(
            path: '/emergency',
            builder: (_, _) => const EmergencyScreen(),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/doctor/:id',
        builder: (_, s) =>
            DoctorDetailScreen(doctorId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/hospital/:id',
        builder: (_, s) =>
            HospitalDetailScreen(hospitalId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/records', builder: (_, _) => const RecordsScreen()),
      GoRoute(
        path: '/medications',
        builder: (_, _) => const MedicationsScreen(),
      ),
      GoRoute(path: '/assistant', builder: (_, _) => const AiAssistantScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/contacts',
        builder: (_, _) => const ContactsScreen(),
      ),
      GoRoute(
        path: '/profile/sensors',
        builder: (_, _) => const SensorSettingsScreen(),
      ),
      GoRoute(
        path: '/profile/privacy',
        builder: (_, _) => const PrivacyScreen(),
      ),
    ],
  );
});

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

  @override
  Widget build(BuildContext context) {
    var index = _tabs.indexOf(location);
    if (index < 0) index = 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.emergency_outlined, color: AppColors.emergency),
            selectedIcon: Icon(Icons.emergency, color: AppColors.emergency),
            label: 'Emergency',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
