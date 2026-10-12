import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/kit.dart';
import '../../core/design/kit_extra.dart';
import '../../core/design/palette.dart';
import '../../core/widgets/media.dart';
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

    // Specialties come from the doctors actually in the directory, so every shortcut leads somewhere.
    final specialties = <String, Map<String, dynamic>>{};
    for (final d in doctors) {
      specialties.putIfAbsent(d['specialty'] as String, () => d);
    }

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
                // ---- header
                Row(
                  children: [
                    PersonAvatar(name: user?.fullName ?? '?', size: 50),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: TextStyle(
                              color: p.muted,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                          Text(
                            user?.fullName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LanguageToggle(
                      isKhmer: context.isKhmer,
                      onChanged: (c) => languageController.set(c),
                    ),
                    const SizedBox(width: 8),
                    Tap(
                      onTap: () => context.push('/notifications'),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: p.surface,
                          shape: BoxShape.circle,
                          boxShadow: softShadow(context),
                        ),
                        child: Center(
                          child: Badge(
                            isLabelVisible: unread > 0,
                            smallSize: 9,
                            backgroundColor: p.red,
                            child: Icon(
                              Icons.notifications_none_rounded,
                              color: p.ink,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xl),

                // ---- search (leads to the directory)
                if (isPatient) ...[
                  Tap(
                    onTap: () => context.go('/discover'),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.only(left: 18, right: 6),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        boxShadow: softShadow(context),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: p.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.t(
                                'ស្វែងរកគ្រូពេទ្យ ឬឯកទេស',
                                'Search a doctor or specialty',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.muted, fontSize: 14.5),
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: p.brand,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.xl),
                ],

                // ---- next appointment
                _NextAppointment(
                  appointment: upcoming.isEmpty ? null : upcoming.first,
                  isPatient: isPatient,
                ),
                const SizedBox(height: Gap.xl),

                if (isPatient) ...[
                  // ---- specialties
                  SectionHeader(
                    context.t('ឯកទេស', 'Specialties'),
                    action: context.t('ទាំងអស់', 'See all'),
                    onAction: () => context.go('/discover'),
                  ),
                  SizedBox(
                    height: 96,
                    child: specialties.isEmpty
                        ? ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (var i = 0; i < 4; i++)
                                const Padding(
                                  padding: EdgeInsets.only(right: 14),
                                  child: Skeleton(
                                    width: 72,
                                    height: 90,
                                    radius: 20,
                                  ),
                                ),
                            ],
                          )
                        : ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final e in specialties.entries)
                                _SpecialtyChip(
                                  icon: specialtyIcon(e.key),
                                  label: specialtyOf(context, e.value),
                                  onTap: () => context.go(
                                    '/discover?specialty=${Uri.encodeQueryComponent(e.key)}',
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: Gap.xl),

                  // ---- quick access
                  Row(
                    children: [
                      _Shortcut(
                        Icons.folder_open_rounded,
                        context.t('កំណត់ត្រា', 'Records'),
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
                      _Shortcut(
                        Icons.badge_outlined,
                        context.t('អត្តសញ្ញាណ', 'Medical ID'),
                        () => context.push('/medical-id'),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.xl),

                  // ---- emergency (quiet by default; red only when something is in progress)
                  _EmergencyStrip(state: emergency),
                  const SizedBox(height: Gap.md),
                  const VitalsHomeCard(),
                  const SizedBox(height: Gap.xl),

                  // ---- doctors
                  SectionHeader(
                    context.t('គ្រូពេទ្យណែនាំ', 'Recommended doctors'),
                    action: context.t('ទាំងអស់', 'See all'),
                    onAction: () => context.go('/discover'),
                  ),
                  if (doctors.isEmpty)
                    for (var i = 0; i < 2; i++)
                      const Padding(
                        padding: EdgeInsets.only(bottom: Gap.md),
                        child: Skeleton(height: 112, radius: 24),
                      )
                  else
                    for (final d in doctors.take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.md),
                        child: DoctorRow(doctor: d),
                      ),
                  const SizedBox(height: Gap.lg),

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
                          Icon(Icons.add_alarm_rounded, color: p.brand),
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
                                  Container(
                                    width: 44,
                                    height: 44,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: p.brandSoft,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.medication_liquid_rounded,
                                      color: p.brand,
                                      size: 22,
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
                                  Text(
                                    (todaysReminders[i]['timeOfDay'] as String)
                                        .substring(0, 5),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: p.brand,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Tap(
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: p.surface,
                  shape: BoxShape.circle,
                  boxShadow: softShadow(context),
                ),
                child: Icon(icon, color: p.brand, size: 27),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: p.inkSoft,
                  height: 1.35,
                ),
              ),
            ],
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
                color: p.brandSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: p.brand, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
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

/// Blue hero card: the next visit at a glance, or an invitation to book one.
class _NextAppointment extends StatelessWidget {
  const _NextAppointment({required this.appointment, required this.isPatient});
  final Map<String, dynamic>? appointment;
  final bool isPatient;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final a = appointment;
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [p.brand, Color.lerp(p.brand, p.brandDeep, 0.85)!],
      ),
      borderRadius: BorderRadius.circular(Radii.lg + 4),
      boxShadow: [
        BoxShadow(
          color: p.brand.withValues(alpha: 0.30),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ],
    );
    Widget chip(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );

    if (a == null) {
      return Tap(
        onTap: () => context.go(isPatient ? '/discover' : '/appointments'),
        child: Container(
          padding: const EdgeInsets.all(Gap.xl),
          decoration: decoration,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('មិនទាន់មានការណាត់ជួប', 'No visits booked'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isPatient
                          ? context.t(
                              'ស្វែងរកគ្រូពេទ្យ ហើយណាត់ជួបបានភ្លាម។',
                              'Find a doctor and book in a minute.',
                            )
                          : context.t('មិនមានសំណើថ្មី។', 'No new requests.'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                    if (isPatient) ...[
                      const SizedBox(height: Gap.lg),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Text(
                          context.t('ណាត់ជួបឥឡូវ', 'Book a visit'),
                          style: TextStyle(
                            color: p.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              Icon(
                Icons.event_available_rounded,
                size: 64,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      );
    }

    final start = DateTime.parse(a['startsAt'] as String).toLocal();
    final name = isPatient
        ? a['doctorName'] as String
        : a['patientName'] as String;
    final specialty = a['doctorSpecialty'] as String?;
    final confirmed = a['status'] == 'CONFIRMED';
    return Tap(
      onTap: () => context.go('/appointments'),
      child: Container(
        padding: const EdgeInsets.all(Gap.lg + 2),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.t('ការណាត់ជួបបន្ទាប់', 'Next appointment'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: confirmed
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    confirmed
                        ? context.t('បានបញ្ជាក់', 'Confirmed')
                        : context.t('កំពុងរង់ចាំ', 'Pending'),
                    style: TextStyle(
                      color: confirmed ? p.brand : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      if (specialty != null && isPatient)
                        Text(
                          specialty,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isPatient) ...[
                  const SizedBox(width: Gap.md),
                  Portrait(
                    name: name,
                    photoUrl: a['doctorPhotoUrl'] as String?,
                    width: 64,
                    height: 72,
                    radius: 20,
                  ),
                ],
              ],
            ),
            const SizedBox(height: Gap.lg),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip(
                  Icons.calendar_today_rounded,
                  context.fmt('EEE d MMM', start),
                ),
                chip(Icons.schedule_rounded, context.fmt('HH:mm', start)),
              ],
            ),
          ],
        ),
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
      borderColor: active ? p.red.withValues(alpha: 0.4) : null,
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
