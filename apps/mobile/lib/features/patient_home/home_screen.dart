import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/media.dart';
import '../appointments/appointments_screen.dart';
import '../authentication/auth_controller.dart';
import '../doctor_directory/discover_screens.dart';
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
    final doctors = ref.watch(doctorsProvider('')).value ?? const [];
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
    final greetingKm = hour < 12
        ? 'អរុណសួស្តី'
        : (hour < 18 ? 'សួស្តីសាយណ្ហ' : 'សុខសាន្តសាយណ្ហ');
    final greetingEn = hour < 12
        ? 'Good morning'
        : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final activeReminders = reminders
        .where((r) => r['active'] == true)
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(appointmentsProvider);
          ref.invalidate(remindersProvider);
          ref.invalidate(notificationsProvider);
          ref.invalidate(doctorsProvider(''));
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ---- header
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 16,
                20,
                22,
              ),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  PersonAvatar(name: user?.fullName ?? '?', size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greetingKm · $greetingEn',
                          style: const TextStyle(
                            color: Color(0xFFB9D3E3),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.fullName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => context.push('/notifications'),
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text('$unread'),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPatient) ...[
                    _EmergencyCard(state: emergency),
                    const SizedBox(height: 22),
                  ],
                  _SectionTitle(
                    isPatient
                        ? 'ការណាត់ជួបបន្ទាប់ · Next visit'
                        : 'កាលវិភាគ · Schedule',
                  ),
                  const SizedBox(height: 10),
                  _NextAppointment(
                    appointment: upcoming.isEmpty ? null : upcoming.first,
                    isPatient: isPatient,
                  ),
                  if (isPatient) ...[
                    const SizedBox(height: 22),
                    _SectionTitle('សេវាកម្ម · Services'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Action(
                          Icons.search,
                          'រកគ្រូពេទ្យ',
                          'Doctors',
                          () => context.go('/discover'),
                        ),
                        _Action(
                          Icons.folder_shared_outlined,
                          'កំណត់ត្រា',
                          'Records',
                          () => context.push('/records'),
                        ),
                        _Action(
                          Icons.medication_outlined,
                          'ថ្នាំ',
                          'Medicine',
                          () => context.push('/medications'),
                        ),
                        _Action(
                          Icons.auto_awesome_outlined,
                          'ជំនួយ',
                          'Assistant',
                          () => context.push('/assistant'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle('វេជ្ជបណ្ឌិតណែនាំ · Doctors'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 168,
                      child: doctors.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: doctors.length > 8
                                  ? 8
                                  : doctors.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, i) =>
                                  DoctorCard(doctor: doctors[i], compact: true),
                            ),
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle('ការរំលឹកថ្នាំ · Medicine reminders'),
                    const SizedBox(height: 10),
                    if (activeReminders.isEmpty)
                      const Text('មិនទាន់មានការរំលឹក · No active reminders.')
                    else
                      Card(
                        child: Column(
                          children: [
                            for (final r in activeReminders.take(3))
                              ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFE3F1F1),
                                  child: Icon(
                                    Icons.alarm,
                                    color: AppColors.teal,
                                  ),
                                ),
                                title: Text('${r['medicationName']}'),
                                subtitle: Text('ជារៀងរាល់ថ្ងៃ · Daily'),
                                trailing: Text(
                                  (r['timeOfDay'] as String).substring(0, 5),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.1),
  );
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.km, this.en, this.onTap);
  final IconData icon;
  final String km;
  final String en;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.teal),
            ),
            const SizedBox(height: 6),
            Text(
              km,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Text(
              en,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NextAppointment extends StatelessWidget {
  const _NextAppointment({required this.appointment, required this.isPatient});
  final Map<String, dynamic>? appointment;
  final bool isPatient;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    if (a == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: const Text('មិនមានការណាត់ជួប · Nothing scheduled'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(isPatient ? '/discover' : '/appointments'),
        ),
      );
    }
    final start = DateTime.parse(a['startsAt'] as String).toLocal();
    final name = isPatient
        ? a['doctorName'] as String
        : a['patientName'] as String;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/appointments'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('d').format(start),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(start),
                      style: const TextStyle(
                        color: Color(0xFFB9D3E3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('EEE, HH:mm').format(start)} · ${a['status'] == 'CONFIRMED' ? 'បានបញ្ជាក់ · Confirmed' : 'កំពុងរង់ចាំ · Pending'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPatient)
                PersonAvatar(
                  name: name,
                  photoUrl: a['doctorPhotoUrl'] as String?,
                  size: 46,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.state});
  final EmergencyState state;

  @override
  Widget build(BuildContext context) {
    final active = state.phase == EmergencyPhase.active && state.event != null;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => context.go('/emergency'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFFD92D20), Color(0xFFB42318)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency_share_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active
                        ? 'ស្ថានភាពសង្គ្រោះបន្ទាន់ · In progress'
                        : 'ត្រូវការជំនួយបន្ទាន់? · Need urgent help?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    active ? describeEmergencyStatus(state.event!.status) : 'ចុចដើម្បីបើកផ្ទាំងសង្គ្រោះបន្ទាន់ · Tap to open the emergency screen',
                    style: const TextStyle(
                      color: Color(0xFFFFE4E1),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
