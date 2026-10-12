import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/kit.dart';
import '../../core/design/kit_extra.dart';
import '../../core/design/palette.dart';
import '../../core/errors/app_exception.dart';
import '../../core/i18n/language.dart';
import '../../core/network/providers.dart';
import '../authentication/auth_controller.dart';
import '../location/location_service.dart';
import 'emergency_controller.dart';
import 'hold_to_confirm_button.dart';

final systemSettingsProvider = FutureProvider.autoDispose<Map<String, String>>((
  ref,
) async {
  final res = await ref.read(apiClientProvider).get('/system/settings');
  return (res as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
});

(String, String) statusText(String status) => switch (status) {
  'CREATED' => ('បានរក្សាទុកសំណើ', 'Request saved'),
  'SUBMITTED' => (
    'បានផ្ញើទៅបញ្ជីរង់ចាំ កំពុងរង់ចាំបុគ្គលិកទទួលស្គាល់',
    'Sent to the response queue. Waiting for staff to acknowledge it.',
  ),
  'ACKNOWLEDGED' => (
    'បុគ្គលិកមន្ទីរពេទ្យបានទទួលស្គាល់សំណើ',
    'Hospital staff acknowledged your request.',
  ),
  'RESPONDER_ASSIGNED' => (
    'បានចាត់តាំងអ្នកឆ្លើយតប',
    'A responder was assigned.',
  ),
  'RESPONDER_EN_ROUTE' => (
    'អ្នកឆ្លើយតបកំពុងធ្វើដំណើរ (តាមការកត់ត្រារបស់បុគ្គលិក)',
    'A responder is on the way (as recorded by staff).',
  ),
  'ARRIVED' => (
    'អ្នកឆ្លើយតបបានមកដល់ (តាមការកត់ត្រារបស់បុគ្គលិក)',
    'A responder has arrived (as recorded by staff).',
  ),
  'RESOLVED' => ('បានបញ្ចប់', 'Resolved.'),
  'CANCELLED' => ('បានលុបចោល', 'Cancelled.'),
  'REJECTED' => (
    'ត្រូវបានបដិសេធ សូមទាក់ទងសេវាសង្គ្រោះបន្ទាន់ដោយផ្ទាល់',
    'Rejected by staff. Please contact emergency services directly.',
  ),
  'FAILED' => (
    'មិនអាចដំណើរការបាន សូមទាក់ទងសេវាសង្គ្រោះបន្ទាន់ដោយផ្ទាល់',
    'Could not be processed. Please contact emergency services directly.',
  ),
  _ => (status, status),
};

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  bool _demo = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(emergencyControllerProvider.notifier).restoreActive(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final user = ref.watch(authControllerProvider).user;
    if (user != null && !user.isPatient) return const _ResponderList();

    final state = ref.watch(emergencyControllerProvider);
    final settings = ref.watch(systemSettingsProvider).value;
    final number = settings?['emergency.local_number'];
    final controller = ref.read(emergencyControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.lg,
              Gap.page,
              Gap.xxl,
            ),
            children: [
              Text(
                context.t('សង្គ្រោះបន្ទាន់', 'Emergency'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                context.t(
                  'នេះជាប្រព័ន្ធបញ្ជីរង់ចាំសាកល្បងក្នុងកម្មវិធី មិនមែនជាបណ្តាញបញ្ជូនរថយន្តសង្គ្រោះពិតប្រាកដទេ។',
                  'This is an in-app demonstration queue, not a real ambulance dispatch network.',
                ),
                style: TextStyle(color: p.muted, height: 1.5),
              ),
              const SizedBox(height: Gap.xl),
              ..._body(context, state, number, controller),
              const SizedBox(height: Gap.xl),
              _CallCard(number: number),
              const SizedBox(height: Gap.xl),
              const _History(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    EmergencyState state,
    String? number,
    EmergencyController controller,
  ) {
    final p = Palette.of(context);
    switch (state.phase) {
      case EmergencyPhase.idle:
        return [
          Center(
            child: HoldToConfirmButton(
              onConfirmed: () => controller.activate(demo: _demo),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Text(
            context.t(
              'សង្កត់ប៊ូតុងរហូតរង្វង់ពេញ។ អ្នកនឹងឃើញស្ថានភាពពិតដែលបុគ្គលិកបានកត់ត្រា។',
              'Hold until the ring completes. You will see the real status recorded by staff.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkSoft, height: 1.5),
          ),
          const SizedBox(height: Gap.lg),
          Surface(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: 6,
            ),
            child: SwitchRow(
              value: _demo,
              onChanged: (v) => setState(() => _demo = v),
              title: Text(
                context.t('សំណើសាកល្បង', 'Practice request'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                context.t(
                  'សម្គាល់ថាជាសំណើសាកល្បងសម្រាប់បុគ្គលិក និងមិនផ្ញើសារទៅអ្នកទាក់ទង។',
                  'Marks it as practice for staff and sends no SMS to contacts.',
                ),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          const _LocationCard(),
        ];
      case EmergencyPhase.locating:
        return [
          _Progress(
            context.t('កំពុងរកទីតាំងរបស់អ្នក…', 'Finding your location…'),
          ),
        ];
      case EmergencyPhase.submitting:
        return [
          _Progress(context.t('កំពុងផ្ញើសំណើ…', 'Sending your request…')),
        ];
      case EmergencyPhase.failed:
        return [_FailedCard(state: state, number: number)];
      case EmergencyPhase.active:
        return [_ActiveCard(state: state)];
    }
  }
}

class _Progress extends StatelessWidget {
  const _Progress(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        const SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(strokeWidth: 4),
        ),
        const SizedBox(height: Gap.lg),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _LocationCard extends ConsumerStatefulWidget {
  const _LocationCard();

  @override
  ConsumerState<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends ConsumerState<_LocationCard> {
  LocationResult? _result;
  bool _busy = false;

  Future<void> _check() async {
    setState(() => _busy = true);
    final r = await ref.read(locationProviderProvider).current();
    if (mounted) {
      setState(() {
        _result = r;
        _busy = false;
      });
    }
  }

  String _message(BuildContext context, LocationResult r) => switch (r.status) {
    LocationStatus.ok => context.t(
      'រកឃើញទីតាំង (ភាពត្រឹមត្រូវប្រហែល ${r.accuracyMeters?.round() ?? '?'} ម៉ែត្រ)។',
      'Location found (accuracy about ${r.accuracyMeters?.round() ?? '?'} m).',
    ),
    LocationStatus.denied => context.t(
      'មិនទាន់អនុញ្ញាតទីតាំង។ អ្នកឆ្លើយតបនឹងមិនទទួលបានទីតាំងរបស់អ្នកទេ។',
      'Location permission not granted. Responders will not receive your position.',
    ),
    LocationStatus.deniedForever => context.t(
      'ទីតាំងត្រូវបានបិទ។ សូមបើកក្នុងការកំណត់ប្រព័ន្ធ។',
      'Location is blocked. Enable it in system settings.',
    ),
    LocationStatus.serviceDisabled => context.t(
      'សេវាទីតាំងត្រូវបានបិទលើឧបករណ៍នេះ។',
      'Location services are off on this device.',
    ),
    LocationStatus.timeout => context.t(
      'មិនអាចរកទីតាំងទាន់ពេល។',
      'Could not get a GPS fix in time.',
    ),
    LocationStatus.error => context.t(
      'ទីតាំងមិនអាចប្រើបានឥឡូវនេះ។',
      'Location is unavailable right now.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final r = _result;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r?.hasFix == true
                    ? Icons.my_location_rounded
                    : Icons.location_searching_rounded,
                color: r?.hasFix == true ? p.green : p.muted,
              ),
              const SizedBox(width: 10),
              Text(
                context.t('ទីតាំង', 'Location'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r == null
                ? context.t(
                    'ទីតាំងត្រូវបានស្នើសុំតែពេលអ្នកស្នើជំនួយ ឬពិនិត្យនៅទីនេះប៉ុណ្ណោះ។',
                    'Your location is requested only when you ask for help or check it here.',
                  )
                : _message(context, r),
            style: TextStyle(color: p.inkSoft, height: 1.5),
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: 8,
            children: [
              GhostButton(
                compact: true,
                label: _busy
                    ? context.t('កំពុងពិនិត្យ…', 'Checking…')
                    : context.t('ពិនិត្យទីតាំង', 'Check location'),
                onPressed: _busy ? null : _check,
              ),
              if (r?.status == LocationStatus.deniedForever)
                GhostButton(
                  compact: true,
                  label: context.t('បើកការកំណត់', 'Open settings'),
                  onPressed: () =>
                      ref.read(locationProviderProvider).openSettings(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FailedCard extends ConsumerWidget {
  const _FailedCard({required this.state, required this.number});
  final EmergencyState state;
  final String? number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final controller = ref.read(emergencyControllerProvider.notifier);
    return Surface(
      color: p.redSoft,
      borderColor: p.red.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel_rounded, color: p.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t('មិនទាន់បានបញ្ជាក់សំណើ', 'Request NOT confirmed'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: p.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.error == null ? '' : describeError(state.error!),
            style: TextStyle(color: p.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'មិនទាន់មាននរណាត្រូវបានជូនដំណឹងទេ។ ប្រសិនបើអ្នកមានគ្រោះថ្នាក់ សូមហៅលេខសង្គ្រោះបន្ទាន់ក្នុងតំបន់ភ្លាមៗ រួចសាកល្បងម្តងទៀត។',
              'No one has been notified. If you are in danger, call your local emergency number now, then try again.',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5),
          ),
          const SizedBox(height: Gap.lg),
          _CallButton(number: number),
          const SizedBox(height: Gap.sm),
          PrimaryButton(
            label: context.t('ផ្ញើម្តងទៀត', 'Try sending again'),
            icon: Icons.refresh_rounded,
            danger: true,
            onPressed: () => controller.activate(),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: controller.dismiss,
              child: Text(context.t('បិទ', 'Dismiss')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCard extends ConsumerWidget {
  const _ActiveCard({required this.state});
  final EmergencyState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final event = state.event!;
    final controller = ref.read(emergencyControllerProvider.notifier);
    final (km, en) = statusText(event.status);
    final terminal = event.isTerminal;
    final tone = event.status == 'RESOLVED'
        ? p.green
        : (terminal ? p.amber : p.red);
    final steps = [
      'SUBMITTED',
      'ACKNOWLEDGED',
      'RESPONDER_ASSIGNED',
      'RESPONDER_EN_ROUTE',
      'ARRIVED',
      'RESOLVED',
    ];
    final reached = event.history.map((h) => h.toStatus).toSet();
    final labels = {
      'SUBMITTED': context.t('បានផ្ញើ', 'Sent'),
      'ACKNOWLEDGED': context.t('បានទទួលស្គាល់', 'Acknowledged'),
      'RESPONDER_ASSIGNED': context.t('បានចាត់តាំង', 'Assigned'),
      'RESPONDER_EN_ROUTE': context.t('កំពុងធ្វើដំណើរ', 'On the way'),
      'ARRIVED': context.t('បានមកដល់', 'Arrived'),
      'RESOLVED': context.t('បានបញ្ចប់', 'Resolved'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Surface(
          color: p.surface,
          borderColor: tone.withValues(alpha: 0.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: tone,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    event.status.replaceAll('_', ' '),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: tone,
                    ),
                  ),
                  const Spacer(),
                  if (event.demo)
                    Pill(context.t('សាកល្បង', 'Practice'), tone: Tone.amber),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.t(km, en),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              if (event.responders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${context.t('អ្នកឆ្លើយតប', 'Responder')}: ${event.responders.join(', ')}',
                    style: TextStyle(color: p.inkSoft),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                state.stale
                    ? context.t(
                        'មិនអាចធ្វើបច្ចុប្បន្នភាពបាន ស្ថានភាពអាចហួសសម័យ។',
                        'Could not refresh. This status may be out of date.',
                      )
                    : '${context.t('បានបញ្ជាក់ដោយម៉ាស៊ីនមេ', 'Confirmed by the server')} ${state.lastSyncAt == null ? '' : context.fmt('HH:mm:ss', state.lastSyncAt!)}',
                style: TextStyle(
                  color: state.stale ? p.amber : p.muted,
                  fontWeight: state.stale ? FontWeight.w700 : null,
                  fontSize: 13,
                ),
              ),
              if (event.latitude == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    context.t(
                      'មិនបានចែករំលែកទីតាំងជាមួយសំណើនេះទេ។',
                      'No location was shared with this request.',
                    ),
                    style: TextStyle(color: p.muted, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        Surface(
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++)
                _Step(
                  label: labels[steps[i]]!,
                  done: reached.contains(steps[i]),
                  current: event.status == steps[i],
                  last: i == steps.length - 1,
                  time: event.history
                      .where((h) => h.toStatus == steps[i])
                      .map((h) => context.fmt('HH:mm', h.at))
                      .firstOrNull,
                ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        if (event.canCancel)
          GhostButton(
            icon: Icons.close_rounded,
            label: context.t(
              'ខ្ញុំសុវត្ថិភាព លុបចោលសំណើ',
              'I am safe, cancel the request',
            ),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(ctx.t('លុបចោលសំណើ?', 'Cancel this request?')),
                  content: Text(
                    ctx.t(
                      'ប្រើតែពេលអ្នកលែងត្រូវការជំនួយ (សំណើខុស)។',
                      'Use this only if you no longer need help (false alarm).',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(ctx.t('រក្សាសំណើ', 'Keep request')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(ctx.t('លុបចោល', 'Cancel request')),
                    ),
                  ],
                ),
              );
              if (ok == true) await controller.cancel(note: 'False alarm');
            },
          ),
        if (terminal)
          TextButton(
            onPressed: controller.dismiss,
            child: Text(context.t('រួចរាល់', 'Done')),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.done,
    required this.current,
    required this.last,
    this.time,
  });
  final String label;
  final bool done;
  final bool current;
  final bool last;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = done ? (current ? p.red : p.brand) : p.line;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: current ? 16 : 12,
                  height: current ? 16 : 12,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: done ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: done ? p.brand : p.line),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                        color: done ? p.ink : p.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (time != null)
                    Text(time!, style: TextStyle(color: p.muted, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({required this.number});
  final String? number;

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('ហៅសេវាសង្គ្រោះបន្ទាន់', 'Call emergency services'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _CallButton(number: number),
      ],
    ),
  );
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.number});
  final String? number;

  bool get _configured =>
      number != null && number!.isNotEmpty && number != 'UNCONFIGURED';

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    if (!_configured) {
      return Text(
        context.t(
          'អ្នកគ្រប់គ្រងមិនទាន់កំណត់លេខសង្គ្រោះបន្ទាន់ទេ។ សូមហៅលេខសង្គ្រោះបន្ទាន់ក្នុងតំបន់ដោយខ្លួនឯង។',
          'The administrator has not configured an emergency number. Dial your local emergency number manually.',
        ),
        style: TextStyle(color: p.inkSoft, height: 1.5),
      );
    }
    return GhostButton(
      icon: Icons.call_rounded,
      label: '${context.t('ហៅ', 'Call')} $number',
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${ctx.t('ហៅ', 'Call')} $number?'),
            content: Text(
              ctx.t(
                'ឧបករណ៍ហៅទូរស័ព្ទនឹងបើក។ គ្មានអ្វីត្រូវបានហៅដោយស្វ័យប្រវត្តិទេ។',
                'Your dialler will open. Nothing is dialled automatically.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.t('បោះបង់', 'Cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('បើកឧបករណ៍ហៅ', 'Open dialler')),
              ),
            ],
          ),
        );
        if (ok == true) await launchUrl(Uri(scheme: 'tel', path: number));
      },
    );
  }
}

class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final history = ref.watch(emergencyHistoryProvider);
    return history.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(emergencyHistoryProvider),
      ),
      data: (events) => events.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  context.t('ប្រវត្តិ', 'History'),
                  count: events.length,
                ),
                for (final e in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Surface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            e.isTerminal
                                ? Icons.history_rounded
                                : Icons.pending_actions_rounded,
                            color: p.muted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.status.replaceAll('_', ' '),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  context.fmt(
                                    'd MMM yyyy · HH:mm',
                                    e.createdAt,
                                  ),
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (e.demo)
                            Pill(
                              context.t('សាកល្បង', 'Practice'),
                              tone: Tone.amber,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Doctors (and other non-patient roles) see incidents they may act on rather than the patient SOS control.
class _ResponderList extends ConsumerWidget {
  const _ResponderList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(emergencyHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('ករណីដែលបានចាត់តាំង', 'Assigned incidents')),
      ),
      body: history.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(emergencyHistoryProvider),
        ),
        data: (events) => events.isEmpty
            ? EmptyState(
                art: Art.shield,
                title: context.t(
                  'មិនមានករណីចាត់តាំងទេ',
                  'Nothing assigned to you',
                ),
                message: context.t(
                  'ករណីនឹងបង្ហាញនៅទីនេះនៅពេលបុគ្គលិកចាត់តាំងអ្នក។',
                  'Incidents appear here when hospital staff assign you.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(Gap.page),
                children: [
                  for (final e in events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.status.replaceAll('_', ' '),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.t(
                                statusText(e.status).$1,
                                statusText(e.status).$2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
