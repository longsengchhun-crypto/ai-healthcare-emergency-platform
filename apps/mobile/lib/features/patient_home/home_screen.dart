import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../appointments/appointments_screen.dart';
import '../authentication/auth_controller.dart';
import '../emergency/emergency_controller.dart';
import '../emergency/emergency_models.dart';
import '../medications/medications_screen.dart';
import '../notifications/notifications_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final emergency = ref.watch(emergencyControllerProvider);
    final appts = ref.watch(appointmentsProvider).value ?? const [];
    final reminders = ref.watch(remindersProvider).value ?? const [];
    final unread =
        (ref.watch(notificationsProvider).value?['unread'] as int?) ?? 0;
    final isPatient = user?.isPatient ?? false;

    final upcoming =
        appts
            .where(
              (a) =>
                  (a['status'] == 'REQUESTED' || a['status'] == 'CONFIRMED') &&
                  DateTime.parse(a['startsAt'] as String)
                      .isAfter(DateTime.now()),
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['startsAt'] as String).compareTo(b['startsAt'] as String),
          );

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 18 ? 'Good afternoon' : 'Good evening');

    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthResponse'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(appointmentsProvider);
          ref.invalidate(remindersProvider);
          ref.invalidate(notificationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '$greeting, ${user?.firstName ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (isPatient) _EmergencyCard(state: emergency),
            if (isPatient) const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPatient ? 'Next appointment' : 'Your next appointments',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (upcoming.isEmpty)
                      const Text('Nothing scheduled.')
                    else
                      Text(
                        '${isPatient ? upcoming.first['doctorName'] : upcoming.first['patientName']} · '
                        '${DateFormat('EEE d MMM, HH:mm').format(DateTime.parse(upcoming.first['startsAt'] as String).toLocal())}'
                        ' (${upcoming.first['status']})',
                      ),
                    TextButton(
                      onPressed: () => context.go('/appointments'),
                      child: Text(
                        isPatient ? 'View appointments' : 'Open schedule',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isPatient) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medication reminders',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (reminders.where((r) => r['active'] == true).isEmpty)
                        const Text('No active reminders.')
                      else
                        for (final r
                            in reminders
                                .where((r) => r['active'] == true)
                                .take(3))
                          Text(
                            '${(r['timeOfDay'] as String).substring(0, 5)} — ${r['medicationName']}',
                          ),
                      TextButton(
                        onPressed: () => context.push('/medications'),
                        child: const Text('Manage medications'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _Tile(
                    Icons.folder_shared_outlined,
                    'Records',
                    () => context.push('/records'),
                  ),
                  _Tile(
                    Icons.auto_awesome_outlined,
                    'Health assistant',
                    () => context.push('/assistant'),
                  ),
                  _Tile(
                    Icons.search,
                    'Find a doctor',
                    () => context.go('/discover'),
                  ),
                  _Tile(
                    Icons.sensors,
                    'Safety sensors',
                    () => context.push('/profile/sensors'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.state});
  final EmergencyState state;

  @override
  Widget build(BuildContext context) {
    final active = state.phase == EmergencyPhase.active && state.event != null;
    return Card(
      color: AppColors.emergency.withValues(alpha: 0.07),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/emergency'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.emergency,
                child: Icon(Icons.emergency_share_rounded, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'Emergency in progress' : 'Need urgent help?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.emergency,
                      ),
                    ),
                    Text(
                      active ? describeEmergencyStatus(state.event!.status) : 'Open the Emergency tab to request help with your location.',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
