import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/kit.dart';
import '../../core/design/kit_extra.dart';
import '../../core/design/palette.dart';
import '../../core/errors/app_exception.dart';
import '../../core/i18n/language.dart';
import '../../core/network/providers.dart';
import '../authentication/auth_controller.dart';
import '../doctor_directory/discover_screens.dart';
import '../sensors/sensor_controller.dart';

// ------------------------------------------------------------------ sensors

class SensorSettingsScreen extends ConsumerWidget {
  const SensorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final s = ref.watch(sensorControllerProvider);
    final c = ref.read(sensorControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('ឧបករណ៍ចាប់សញ្ញាសុវត្ថិភាព', 'Safety sensors')),
      ),
      body: PageWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xxl),
          children: [
            Notice(
              context.t(
                'មុខងារពិសោធន៍។ ទូរស័ព្ទតែឧបករណ៍តែមួយអាចខកខាន ឬរោទិ៍ខុសបាន។ វាគ្រាន់តែដាក់ទង់ថា "អាចមានឧប្បត្តិហេតុ" ហើយសួរអ្នកជាមុនសិន។ វាមិនជំនួសការហៅជំនួយទេ។',
                'Experimental. A phone-only detector can miss accidents or fire by mistake. It only flags a possible incident and asks you first. It never replaces calling for help.',
              ),
              tone: Tone.amber,
            ),
            const SizedBox(height: Gap.lg),
            Surface(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: 4,
              ),
              child: Column(
                children: [
                  SwitchRow(
                    title: Text(
                      context.t('ត្រួតពិនិត្យចលនា', 'Monitor motion'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      s.availability == SensorAvailability.unavailable
                          ? context.t(
                              'ឧបករណ៍នេះមិនមានឧបករណ៍ចាប់សញ្ញាទេ។ សូមប្រើរបៀបបង្ហាញខាងក្រោម។',
                              'No sensors on this device. Use demonstration mode below.',
                            )
                          : s.settings.monitoringEnabled
                          ? context.t(
                              'កំពុងត្រួតពិនិត្យពេលកម្មវិធីបើក។',
                              'Monitoring while the app is open.',
                            )
                          : context.t(
                              'បិទ មិនអានទិន្នន័យចលនាទេ។',
                              'Off. No sensor data is read.',
                            ),
                    ),
                    value: s.settings.monitoringEnabled,
                    onChanged: c.setMonitoring,
                  ),
                  Divider(color: p.line),
                  SwitchRow(
                    title: Text(
                      context.t(
                        'ផ្ញើសំណើបើខ្ញុំមិនឆ្លើយតប',
                        'Send a request if I do not respond',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      context.t(
                        'បិទតាមលំនាំដើម។ ពេលបិទ ការរាប់ថយក្រោយផុតកំណត់នឹងមិនផ្ញើអ្វីទេ។',
                        'Off by default. When off, an expired countdown sends nothing.',
                      ),
                    ),
                    value: s.settings.autoDispatchEnabled,
                    onChanged: s.settings.monitoringEnabled
                        ? c.setAutoDispatch
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        context.t('រយៈពេលរាប់ថយក្រោយ', 'Countdown length'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        '${s.settings.countdownSeconds}s',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: p.teal,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 10,
                    max: 60,
                    divisions: 10,
                    value: s.settings.countdownSeconds.toDouble(),
                    onChanged: (v) => c.setCountdown(v.round()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xl),
            SectionHeader(context.t('របៀបបង្ហាញ', 'Demonstration mode')),
            Text(
              context.t(
                'ចាក់បញ្ចាំងលំដាប់ចលនាសាកល្បងតាមក្បួនដោះស្រាយពិតប្រាកដ។ វាត្រូវបានសម្គាល់ថា "ក្លែង" ជានិច្ច។',
                'Plays a synthetic motion sequence through the real detector. It is always marked as simulated.',
              ),
              style: TextStyle(color: p.inkSoft, height: 1.5),
            ),
            const SizedBox(height: Gap.md),
            GhostButton(
              icon: Icons.science_outlined,
              label: context.t(
                'សាកល្បងស្ថានភាពអាចមានឧប្បត្តិហេតុ',
                'Simulate a possible incident',
              ),
              onPressed: () {
                c.simulateIncident();
                context.push('/safety-check');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ privacy

final _privacyProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  return Map<String, dynamic>.from(
    await ref.read(apiClientProvider).get('/patients/me/privacy') as Map,
  );
});

final _activityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      return List<Map<String, dynamic>>.from(
        await ref.read(apiClientProvider).get('/patients/me/activity') as List,
      );
    });

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  String _actionLabel(BuildContext context, String a) {
    if (a.startsWith('RECORD_LIST'))
      return context.t('បានមើលបញ្ជីកំណត់ត្រា', 'Viewed your record list');
    if (a.startsWith('RECORD_VIEW'))
      return context.t('បានបើកកំណត់ត្រា', 'Opened a record');
    if (a.startsWith('RECORD_CREATE'))
      return context.t('បានបន្ថែមកំណត់ត្រា', 'Added a record');
    if (a.startsWith('RECORD_AMEND'))
      return context.t('បានកែតម្រូវកំណត់ត្រា', 'Amended a record');
    if (a.startsWith('RECORD_ACCESS'))
      return context.t(
        'ព្យាយាមចូលដោយគ្មានសិទ្ធិ',
        'Tried to access without permission',
      );
    if (a.startsWith('DOCUMENT'))
      return context.t('បានចូលមើលឯកសារ', 'Accessed a document');
    if (a.startsWith('ACCESS_GRANT'))
      return context.t('បានផ្តល់សិទ្ធិចូល', 'Access granted');
    if (a.startsWith('ACCESS_REVOKE'))
      return context.t('បានដកសិទ្ធិចូល', 'Access revoked');
    if (a.startsWith('EMERGENCY_VIEW'))
      return context.t(
        'បានមើលសំណើសង្គ្រោះបន្ទាន់',
        'Viewed an emergency request',
      );
    return a;
  }

  Future<void> _grant(BuildContext context, WidgetRef ref) async {
    final doctors = await ref.read(doctorsProvider('').future);
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scroll) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
              child: Text(
                ctx.t(
                  'ជ្រើសរើសគ្រូពេទ្យដើម្បីផ្តល់សិទ្ធិមើលកំណត់ត្រា',
                  'Choose a doctor to share your records with',
                ),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  0,
                  Gap.page,
                  Gap.xl,
                ),
                children: [
                  for (final d in doctors.data)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Surface(
                        padding: const EdgeInsets.all(12),
                        onTap: () => Navigator.pop(ctx, d),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doctorTitle(ctx, d),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    specialtyOf(ctx, d),
                                    style: TextStyle(
                                      color: Palette.of(ctx).muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .post('/patients/me/access-grants', body: {'doctorId': picked['id']});
      ref.invalidate(_privacyProvider);
      ref.invalidate(_activityProvider);
    } on AppException catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final privacy = ref.watch(_privacyProvider);
    final activity = ref.watch(_activityProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('ឯកជនភាព និងទិន្នន័យ', 'Privacy & data')),
      ),
      body: PageWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xxl),
          children: [
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('អ្វីដែលយើងរក្សាទុក', 'What we store'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      'គណនី ព័ត៌មានសុខភាពស្រេចចិត្ត ការណាត់ជួប កំណត់ត្រា ថ្នាំ និងសំណើសង្គ្រោះបន្ទាន់ (រួមទាំងទីតាំងដែលអ្នកបានចែករំលែក)។ ទីតាំងត្រូវបានស្នើសុំតែពេលអ្នកស្នើជំនួយប៉ុណ្ណោះ។ បុគ្គលិកមន្ទីរពេទ្យមិនអាចរកមើលកំណត់ត្រាវេជ្ជសាស្ត្ររបស់អ្នកបានទេ។',
                      'Your account, optional health details, appointments, records, medicines and emergency requests (including the location you chose to share). Location is requested only when you ask for help. Hospital staff cannot browse your medical records.',
                    ),
                    style: TextStyle(color: p.inkSoft, height: 1.55),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xl),
            SectionHeader(
              context.t(
                'គ្រូពេទ្យដែលអាចមើលកំណត់ត្រា',
                'Doctors who can see your records',
              ),
            ),
            privacy.when(
              loading: () => const Skeleton(height: 70, radius: Radii.lg),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(_privacyProvider),
              ),
              data: (d) {
                final grants = List<Map<String, dynamic>>.from(
                  d['recordAccessGrants'] as List,
                );
                return Column(
                  children: [
                    if (grants.isEmpty)
                      Surface(
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, color: p.muted),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.t(
                                  'មិនទាន់មានគ្រូពេទ្យណាត្រូវបានផ្តល់សិទ្ធិទេ។ គ្រូពេទ្យដែលមានការណាត់ជួបបានបញ្ជាក់អាចមើលបានផងដែរ។',
                                  'No doctor has been given access. Doctors with a confirmed visit with you can also view them.',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final g in grants)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Surface(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.lg,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified_user_outlined, color: p.teal),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${g['doctorName']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(apiClientProvider)
                                      .delete(
                                        '/patients/me/access-grants/${g['grantId']}',
                                      );
                                  ref.invalidate(_privacyProvider);
                                },
                                child: Text(
                                  context.t('ដកសិទ្ធិ', 'Revoke'),
                                  style: TextStyle(
                                    color: p.red,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: Gap.sm),
                    GhostButton(
                      icon: Icons.person_add_alt_1_rounded,
                      label: context.t(
                        'ផ្តល់សិទ្ធិដល់គ្រូពេទ្យ',
                        'Give a doctor access',
                      ),
                      onPressed: () => _grant(context, ref),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: Gap.xl),
            SectionHeader(
              context.t(
                'អ្នកណាបានចូលមើលទិន្នន័យរបស់ខ្ញុំ',
                'Who has looked at my data',
              ),
            ),
            activity.when(
              loading: () => const Skeleton(height: 70, radius: Radii.lg),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(_activityProvider),
              ),
              data: (rows) => rows.isEmpty
                  ? Text(
                      context.t(
                        'មិនទាន់មាននរណាផ្សេងចូលមើលទេ។',
                        'Nobody else has accessed your data yet.',
                      ),
                      style: TextStyle(color: p.muted),
                    )
                  : Surface(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                      child: Column(
                        children: [
                          for (var i = 0; i < rows.length && i < 12; i++) ...[
                            if (i > 0) Divider(color: p.line),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    rows[i]['outcome'] == 'DENIED'
                                        ? Icons.block_rounded
                                        : Icons.visibility_outlined,
                                    size: 19,
                                    color: rows[i]['outcome'] == 'DENIED'
                                        ? p.red
                                        : p.muted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _actionLabel(
                                            context,
                                            rows[i]['action'] as String,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          '${rows[i]['actorName'] ?? rows[i]['actorRole'] ?? ''} · ${context.fmt('d MMM, HH:mm', DateTime.parse(rows[i]['at'] as String).toLocal())}',
                                          style: TextStyle(
                                            color: p.muted,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: Gap.xl),
            Notice(
              context.t(
                'នេះជាកំណែសាកល្បង មិនមែនជាឧបករណ៍វេជ្ជសាស្ត្រដែលមានវិញ្ញាបនបត្រ ហើយមិនទាន់បានវាយតម្លៃតាមបទប្បញ្ញត្តិឯកជនភាពសុខភាពទេ។',
                'This is a demonstration build. It is not a certified medical device and has not been assessed against health-privacy regulations.',
              ),
              tone: Tone.amber,
            ),
            const SizedBox(height: Gap.lg),
            GhostButton(
              icon: Icons.person_off_outlined,
              label: context.t('បិទគណនីរបស់ខ្ញុំ', 'Deactivate my account'),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(ctx.t('បិទគណនី?', 'Deactivate account?')),
                    content: Text(
                      ctx.t(
                        'អ្នកនឹងត្រូវចាកចេញពីគ្រប់ឧបករណ៍ ហើយគណនីនឹងត្រូវបិទ។',
                        'You will be signed out everywhere and the account will be deactivated.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(ctx.t('បោះបង់', 'Cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          ctx.t('បិទគណនី', 'Deactivate'),
                          style: TextStyle(
                            color: Palette.of(ctx).red,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await ref.read(apiClientProvider).delete('/users/me');
                  await ref.read(authControllerProvider.notifier).logout();
                } on AppException catch (e) {
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(describeError(e))));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ doctor availability

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  // day (1=Mon..7=Sun) -> [start, end]
  final Map<int, List<TimeOfDay>> _days = {};
  int _slot = 30;
  bool _loaded = false;
  bool _busy = false;

  Future<void> _load() async {
    try {
      final res =
          await ref.read(apiClientProvider).get('/doctors/me/availability')
              as List;
      for (final w in res) {
        final m = w as Map;
        TimeOfDay parse(String s) => TimeOfDay(
          hour: int.parse(s.split(':')[0]),
          minute: int.parse(s.split(':')[1]),
        );
        _days[m['dayOfWeek'] as int] = [
          parse(m['startTime'] as String),
          parse(m['endTime'] as String),
        ];
        _slot = m['slotMinutes'] as int;
      }
    } on AppException {
      // start empty; saving will surface any real error
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .put(
            '/doctors/me/availability',
            body: {
              'windows': [
                for (final e in _days.entries)
                  {
                    'dayOfWeek': e.key,
                    'startTime': '${_fmt(e.value[0])}:00',
                    'endTime': '${_fmt(e.value[1])}:00',
                    'slotMinutes': _slot,
                  },
              ],
            },
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t('បានរក្សាទុកម៉ោងធ្វើការ។', 'Working hours saved.'),
            ),
          ),
        );
        context.pop();
      }
    } on AppException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final names = [
      context.t('ច័ន្ទ', 'Monday'),
      context.t('អង្គារ', 'Tuesday'),
      context.t('ពុធ', 'Wednesday'),
      context.t('ព្រហស្បតិ៍', 'Thursday'),
      context.t('សុក្រ', 'Friday'),
      context.t('សៅរ៍', 'Saturday'),
      context.t('អាទិត្យ', 'Sunday'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('ម៉ោងទទួលអ្នកជំងឺ', 'Working hours')),
      ),
      body: !_loaded
          ? const SkeletonList(count: 5, itemHeight: 64)
          : PageWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  0,
                  Gap.page,
                  Gap.xxl,
                ),
                children: [
                  Text(
                    context.t(
                      'អ្នកជំងឺអាចណាត់ជួបតែក្នុងម៉ោងដែលអ្នកបើកប៉ុណ្ណោះ។ ការណាត់ជួបដែលមានស្រាប់មិនត្រូវបានប៉ះពាល់ទេ។',
                      'Patients can only book inside the hours you open. Existing appointments are not affected.',
                    ),
                    style: TextStyle(color: p.inkSoft, height: 1.5),
                  ),
                  const SizedBox(height: Gap.lg),
                  for (var d = 1; d <= 7; d++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Surface(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.lg,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                names[d - 1],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_days.containsKey(d)) ...[
                              _TimeButton(
                                label: _fmt(_days[d]![0]),
                                onTap: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: _days[d]![0],
                                  );
                                  if (t != null)
                                    setState(() => _days[d]![0] = t);
                                },
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('–'),
                              ),
                              _TimeButton(
                                label: _fmt(_days[d]![1]),
                                onTap: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: _days[d]![1],
                                  );
                                  if (t != null)
                                    setState(() => _days[d]![1] = t);
                                },
                              ),
                            ],
                            Switch(
                              value: _days.containsKey(d),
                              onChanged: (v) => setState(() {
                                if (v) {
                                  _days[d] = [
                                    const TimeOfDay(hour: 9, minute: 0),
                                    const TimeOfDay(hour: 12, minute: 0),
                                  ];
                                } else {
                                  _days.remove(d);
                                }
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: Gap.md),
                  Text(
                    context.t(
                      'រយៈពេលនៃការណាត់ជួបនីមួយៗ',
                      'Length of each appointment',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in const [15, 20, 30, 45, 60])
                        ChoiceChip(
                          label: Text('$m ${context.t('នាទី', 'min')}'),
                          selected: _slot == m,
                          onSelected: (_) => setState(() => _slot = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: Gap.xl),
                  PrimaryButton(
                    label: context.t('រក្សាទុក', 'Save'),
                    busy: _busy,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: p.sand,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
