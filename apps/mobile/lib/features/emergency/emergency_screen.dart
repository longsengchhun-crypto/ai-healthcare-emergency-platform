import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';
import '../authentication/auth_controller.dart';
import '../location/location_service.dart';
import 'emergency_controller.dart';
import 'emergency_models.dart';
import 'hold_to_confirm_button.dart';

final systemSettingsProvider = FutureProvider.autoDispose<Map<String, String>>((
  ref,
) async {
  final res = await ref.read(apiClientProvider).get('/system/settings');
  return (res as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
});

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
    final user = ref.watch(authControllerProvider).user;
    if (user != null && !user.isPatient) return const _ResponderEmergencyList();

    final state = ref.watch(emergencyControllerProvider);
    final settings = ref.watch(systemSettingsProvider).value;
    final number = settings?['emergency.local_number'];
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          NoticeBanner(
            settings?['emergency.disclaimer'] ?? 'In-app demonstration response workflow. It is not a real emergency dispatch network.',
            warning: true,
          ),
          const SizedBox(height: 24),
          ..._body(context, state, number),
          const SizedBox(height: 24),
          _CallCard(number: number),
          const SizedBox(height: 16),
          const _History(),
        ],
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    EmergencyState state,
    String? number,
  ) {
    final controller = ref.read(emergencyControllerProvider.notifier);
    switch (state.phase) {
      case EmergencyPhase.idle:
        return [
          Center(
            child: HoldToConfirmButton(
              onConfirmed: () => controller.activate(demo: _demo),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Press and hold to send your location to the response queue. '
            'You will see the real status recorded by staff.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _demo,
            onChanged: (v) => setState(() => _demo = v),
            title: const Text('Demonstration event'),
            subtitle: const Text(
              'Marks the request as a practice event for staff.',
            ),
          ),
          const _LocationStatus(),
        ];
      case EmergencyPhase.locating:
        return [const LoadingView(label: 'Getting your location…')];
      case EmergencyPhase.submitting:
        return [const LoadingView(label: 'Sending request…')];
      case EmergencyPhase.failed:
        return [_FailedCard(state: state, number: number)];
      case EmergencyPhase.active:
        return [_ActiveCard(state: state)];
    }
  }
}

class _LocationStatus extends ConsumerStatefulWidget {
  const _LocationStatus();

  @override
  ConsumerState<_LocationStatus> createState() => _LocationStatusState();
}

class _LocationStatusState extends ConsumerState<_LocationStatus> {
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

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  r?.hasFix == true
                      ? Icons.my_location
                      : Icons.location_searching,
                  color: r?.hasFix == true ? AppColors.success : null,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              r?.message ?? 'Your location is only requested when you ask for help or check it here, and is only shared with the response team.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _check,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text(_busy ? 'Checking…' : 'Check location'),
                ),
                if (r?.status == LocationStatus.deniedForever)
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(locationProviderProvider).openSettings(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Open settings'),
                  ),
              ],
            ),
          ],
        ),
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
    final controller = ref.read(emergencyControllerProvider.notifier);
    final err = state.error;
    return Card(
      color: AppColors.emergency.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel_rounded, color: AppColors.emergency),
                const SizedBox(width: 8),
                Text(
                  'Request NOT confirmed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.emergency,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              err == null
                  ? 'The request could not be confirmed.'
                  : describeError(err),
            ),
            const SizedBox(height: 8),
            const Text(
              'No one has been notified. If you are in danger, call your local emergency '
              'number now, then try sending the request again.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _CallButton(number: number),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => controller.activate(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry sending request'),
            ),
            TextButton(
              onPressed: controller.dismiss,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveCard extends ConsumerWidget {
  const _ActiveCard({required this.state});
  final EmergencyState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = state.event!;
    final controller = ref.read(emergencyControllerProvider.notifier);
    final fmt = DateFormat('d MMM, HH:mm:ss');
    final color = switch (event.status) {
      'RESOLVED' => AppColors.success,
      'CANCELLED' || 'REJECTED' || 'FAILED' => AppColors.warning,
      _ => AppColors.emergency,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(event.status.replaceAll('_', ' ')),
                      backgroundColor: color.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide.none,
                    ),
                    if (event.demo) ...[
                      const SizedBox(width: 8),
                      const Chip(label: Text('DEMO')),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  describeEmergencyStatus(event.status),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (event.responders.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Responder: ${event.responders.join(', ')}'),
                ],
                const SizedBox(height: 8),
                Text(
                  state.stale
                      ? 'Could not refresh. This may be out of date (last confirmed ${state.lastSyncAt == null ? 'unknown' : fmt.format(state.lastSyncAt!)}).'
                      : 'Last confirmed by server ${state.lastSyncAt == null ? '' : fmt.format(state.lastSyncAt!)}',
                  style: TextStyle(
                    color: state.stale ? AppColors.warning : null,
                    fontWeight: state.stale ? FontWeight.w600 : null,
                  ),
                ),
                if (event.latitude == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No location was shared with this request.'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Timeline(entries: event.history),
        const SizedBox(height: 12),
        if (event.canCancel)
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cancel this request?'),
                  content: const Text(
                    'Use this only if you no longer need help (false alarm).',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Keep request'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(120, 48),
                      ),
                      child: const Text('Cancel request'),
                    ),
                  ],
                ),
              );
              if (ok == true) await controller.cancel(note: 'False alarm');
            },
            icon: const Icon(Icons.close),
            label: const Text('I am safe — cancel request'),
          ),
        if (event.isTerminal)
          TextButton(onPressed: controller.dismiss, child: const Text('Done')),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});
  final List<EmergencyHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm:ss');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final e in entries.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 64, child: Text(fmt.format(e.at))),
                    Expanded(
                      child: Text(
                        '${e.toStatus.replaceAll('_', ' ')}${e.note == null ? '' : ' — ${e.note}'}',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({required this.number});
  final String? number;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Call emergency services',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _CallButton(number: number),
        ],
      ),
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
    if (!_configured) {
      return const Text(
        'No emergency number has been configured by the administrator. '
        'Dial your local emergency number manually.',
      );
    }
    return OutlinedButton.icon(
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Call $number?'),
            content: const Text(
              'Your phone dialler will open. Nothing is dialled automatically.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(minimumSize: const Size(100, 48)),
                child: const Text('Open dialler'),
              ),
            ],
          ),
        );
        if (ok == true) await launchUrl(Uri(scheme: 'tel', path: number));
      },
      icon: const Icon(Icons.call),
      label: Text('Call $number'),
    );
  }
}

class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(emergencyHistoryProvider);
    final fmt = DateFormat('d MMM yyyy, HH:mm');
    return history.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(emergencyHistoryProvider),
      ),
      data: (events) => events.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('History', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final e in events)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        e.isTerminal ? Icons.history : Icons.pending_actions,
                      ),
                      title: Text(e.status.replaceAll('_', ' ')),
                      subtitle: Text(fmt.format(e.createdAt)),
                      trailing: e.demo ? const Chip(label: Text('DEMO')) : null,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Doctors (and other non-patient roles) see incidents they may act on rather than the patient SOS control.
class _ResponderEmergencyList extends ConsumerWidget {
  const _ResponderEmergencyList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(emergencyHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Assigned incidents')),
      body: history.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(emergencyHistoryProvider),
        ),
        data: (events) => events.isEmpty
            ? const EmptyView(
                icon: Icons.verified_user_outlined,
                title: 'No incidents assigned to you',
                message:
                    'Incidents appear here when hospital staff assign you.',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final e in events)
                    Card(
                      child: ListTile(
                        title: Text(e.status.replaceAll('_', ' ')),
                        subtitle: Text(describeEmergencyStatus(e.status)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
