import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/kit.dart';
import '../../core/design/kit_extra.dart';
import '../../core/design/palette.dart';
import '../../core/i18n/language.dart';
import '../appointments/appointments_screen.dart';
import '../authentication/auth_controller.dart';
import '../doctor_directory/discover_screens.dart';
import '../emergency/emergency_controller.dart';
import '../emergency/emergency_models.dart';
import '../medications/medications_screen.dart';
import '../vitals/vitals_screen.dart';
import '../notifications/notifications_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final user = ref.watch(authControllerProvider).user;
    final emergency = ref.watch(emergencyControllerProvider);
    final appts = ref.watch(appointmentsProvider).value ?? const [];
    final reminders = ref.watch(remindersProvider).value ?? const [];
    final doctors = ref.watch(doctorsProvider('')).value?.data ?? const [];
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
    final todaysReminders = reminders.where((r) => r['active'] == true).toList()
      ..sort(
        (a, b) =>
            (a['timeOfDay'] as String).compareTo(b['timeOfDay'] as String),
      );

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? context.t('អរុណសួស្តី', 'Good morning')
        : hour < 18
        ? context.t('សួស្តីពេលរសៀល', 'Good afternoon')
        : context.t('សួស្តីពេលល្ងាច', 'Good evening');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(appointmentsProvider);
          ref.invalidate(remindersProvider);
          ref.invalidate(notificationsProvider);
          ref.invalidate(doctorsProvider(''));
        },
        child: SafeArea(
          bottom: false,
          child: PageWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.md,
                Gap.page,
                Gap.xxl,
              ),
              children: [
                // ---- masthead
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.fmt('EEEE d MMMM', DateTime.now()),
                        style: TextStyle(
                          color: p.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    LanguageToggle(
                      isKhmer: context.isKhmer,
                      onChanged: (c) => languageController.set(c),
                    ),
                    const SizedBox(width: 6),
                    Tap(
                      onTap: () => context.push('/notifications'),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Badge(
                          isLabelVisible: unread > 0,
                          smallSize: 9,
                          backgroundColor: p.red,
                          child: Icon(
                            Icons.notifications_none_rounded,
                            color: p.ink,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  '$greeting,',
                  style: TextStyle(color: p.inkSoft, fontSize: 17, height: 1.4),
                ),
                Text(
                  user?.fullName ?? '',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: Gap.xl),

                // ---- next appointment
                SectionHeader(
                  isPatient
                      ? context.t('ការណាត់ជួបបន្ទាប់', 'Next appointment')
                      : context.t('កាលវិភាគបន្ទាប់', 'Next on your schedule'),
                  action: context.t('មើលទាំងអស់', 'See all'),
                  onAction: () => context.go('/appointments'),
                ),
                _NextAppointment(
                  appointment: upcoming.isEmpty ? null : upcoming.first,
                  isPatient: isPatient,
                ),
                const SizedBox(height: Gap.xl),

                if (isPatient) ...[
                  // ---- shortcuts
                  Row(
                    children: [
                      _Shortcut(
                        Icons.search_rounded,
                        context.t('រកគ្រូពេទ្យ', 'Find a doctor'),
                        () => context.go('/discover'),
                      ),
                      _Shortcut(
                        Icons.folder_open_rounded,
                        context.t('កំណត់ត្រា', 'My records'),
                        () => context.push('/records'),
                      ),
                      _Shortcut(
                        Icons.medication_rounded,
                        context.t('ថ្នាំ', 'Medicines'),
                        () => context.push('/medications'),
                      ),
                      _Shortcut(
                        Icons.auto_awesome_rounded,
                        context.t('ជំនួយ', 'Assistant'),
                        () => context.push('/assistant'),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.xl),

                  // ---- emergency (quiet by default; red only when something is in progress)
                  _EmergencyStrip(state: emergency),
                  const SizedBox(height: Gap.md),
                  const VitalsHomeCard(),
                  const SizedBox(height: Gap.sm),
                  Surface(
                    onTap: () => context.push('/medical-id'),
                    padding: const EdgeInsets.all(Gap.md),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: p.redSoft,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(Icons.badge_outlined, color: p.red),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t('អត្តសញ្ញាណសុខភាព', 'Medical ID'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                context.t(
                                  'ក្រុមឈាម ជំងឺអាលែហ្ស៊ី ថ្នាំ និងអ្នកត្រូវទាក់ទង',
                                  'Blood group, allergies, medicines and who to call',
                                ),
                                style: TextStyle(
                                  color: p.muted,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: p.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.xl),

                  // ---- doctors
                  SectionHeader(
                    context.t('គ្រូពេទ្យណែនាំ', 'Doctors'),
                    action: context.t('ទាំងអស់', 'All'),
                    onAction: () => context.go('/discover'),
                  ),
                  SizedBox(
                    height: 220,
                    child: doctors.isEmpty
                        ? ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (var i = 0; i < 3; i++)
                                const Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: Skeleton(
                                    width: 132,
                                    height: 200,
                                    radius: 22,
                                  ),
                                ),
                            ],
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: doctors.length > 8 ? 8 : doctors.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) =>
                                DoctorTile(doctor: doctors[i]),
                          ),
                  ),
                  const SizedBox(height: Gap.xl),

                  // ---- medicine timeline
                  SectionHeader(
                    context.t('ថ្នាំថ្ងៃនេះ', 'Medicines today'),
                    count: todaysReminders.length,
                  ),
                  if (todaysReminders.isEmpty)
                    Surface(
                      onTap: () => context.push('/medications'),
                      child: Row(
                        children: [
                          Icon(Icons.add_alarm_rounded, color: p.teal),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.t(
                                'មិនទាន់មានការរំលឹក។ ចុចដើម្បីបន្ថែម។',
                                'No reminders yet. Tap to add one.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Surface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < todaysReminders.length; i++) ...[
                            if (i > 0) Divider(color: p.line),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 56,
                                    child: Text(
                                      (todaysReminders[i]['timeOfDay']
                                              as String)
                                          .substring(0, 5),
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: p.ink,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${todaysReminders[i]['medicationName']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.alarm_rounded,
                                    size: 18,
                                    color: p.muted,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: Tap(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: p.tealSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: p.tealDeep, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: p.inkSoft,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextAppointment extends StatelessWidget {
  const _NextAppointment({required this.appointment, required this.isPatient});
  final Map<String, dynamic>? appointment;
  final bool isPatient;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final a = appointment;
    if (a == null) {
      return Surface(
        onTap: () => context.go(isPatient ? '/discover' : '/appointments'),
        child: Row(
          children: [
            Icon(Icons.event_available_rounded, color: p.teal, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('មិនទាន់មានការណាត់ជួប', 'Nothing booked'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    isPatient
                        ? context.t(
                            'ស្វែងរកគ្រូពេទ្យ ហើយណាត់ជួបបានភ្លាម។',
                            'Find a doctor and book in a minute.',
                          )
                        : context.t('មិនមានសំណើថ្មី។', 'No new requests.'),
                    style: TextStyle(color: p.muted, height: 1.45),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.muted),
          ],
        ),
      );
    }
    final start = DateTime.parse(a['startsAt'] as String).toLocal();
    final name = isPatient
        ? a['doctorName'] as String
        : a['patientName'] as String;
    final confirmed = a['status'] == 'CONFIRMED';
    return Surface(
      onTap: () => context.go('/appointments'),
      child: Row(
        children: [
          DateBlock(
            day: '${start.day}',
            month: context.fmt('MMM', start),
            highlight: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.fmt('HH:mm', start),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                    height: 1.2,
                  ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Pill(
                  confirmed
                      ? context.t('បានបញ្ជាក់', 'Confirmed')
                      : context.t('កំពុងរង់ចាំ', 'Waiting for confirmation'),
                  tone: confirmed ? Tone.green : Tone.blue,
                ),
              ],
            ),
          ),
          if (isPatient)
            Portrait(
              name: name,
              photoUrl: a['doctorPhotoUrl'] as String?,
              width: 62,
              height: 74,
              radius: 16,
            ),
        ],
      ),
    );
  }
}

class _EmergencyStrip extends StatelessWidget {
  const _EmergencyStrip({required this.state});
  final EmergencyState state;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final active =
        state.phase == EmergencyPhase.active &&
        state.event != null &&
        !(state.event!.isTerminal);
    return Surface(
      color: active ? p.redSoft : p.surface,
      borderColor: active ? p.red.withValues(alpha: 0.4) : p.line,
      onTap: () => context.go('/emergency'),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: p.redSoft, shape: BoxShape.circle),
            child: Icon(Icons.emergency_rounded, color: p.red, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? context.t(
                          'សំណើសង្គ្រោះបន្ទាន់កំពុងដំណើរការ',
                          'Emergency request in progress',
                        )
                      : context.t('ជំនួយបន្ទាន់', 'Emergency help'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: active ? p.red : p.ink,
                  ),
                ),
                Text(
                  active
                      ? describeEmergencyStatus(state.event!.status)
                      : context.t(
                          'ចុចសង្គ្រោះបន្ទាន់ ហើយសង្កត់ដើម្បីស្នើសុំជំនួយ។',
                          'Open Emergency and hold the button to ask for help.',
                        ),
                  style: TextStyle(
                    color: p.muted,
                    height: 1.45,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.muted),
        ],
      ),
    );
  }
}
