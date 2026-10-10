import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';
import '../../core/widgets/state_views.dart';
import '../authentication/auth_controller.dart';
import '../sensors/sensor_controller.dart';

final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  return Map<String, dynamic>.from(
    await ref.read(apiClientProvider).get('/patients/me') as Map,
  );
});

final contactsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    final res = await ref
        .read(apiClientProvider)
        .get('/patients/me/emergency-contacts');
    return List<Map<String, dynamic>>.from(res as List);
  },
);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final isPatient = user?.isPatient ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user?.fullName ?? ''),
              subtitle: Text(
                '${user?.email ?? ''}\n${user?.roles.join(', ') ?? ''}',
              ),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 12),
          if (isPatient) ...[
            _tile(
              context,
              Icons.badge_outlined,
              'Health profile',
              '/profile/edit',
            ),
            _tile(
              context,
              Icons.contacts_outlined,
              'Emergency contacts',
              '/profile/contacts',
            ),
            _tile(
              context,
              Icons.folder_shared_outlined,
              'Medical records',
              '/records',
            ),
            _tile(
              context,
              Icons.medication_outlined,
              'Medications & reminders',
              '/medications',
            ),
            _tile(
              context,
              Icons.auto_awesome_outlined,
              'Health assistant',
              '/assistant',
            ),
          ],
          _tile(
            context,
            Icons.notifications_outlined,
            'Notifications',
            '/notifications',
          ),
          if (isPatient) ...[
            _tile(context, Icons.sensors, 'Safety sensors', '/profile/sensors'),
            _tile(
              context,
              Icons.privacy_tip_outlined,
              'Privacy & data',
              '/profile/privacy',
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    ),
  );
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _dob = TextEditingController();
  final _blood = TextEditingController();
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _dob.dispose();
    _blood.dispose();
    _allergies.dispose();
    _conditions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .patch(
            '/patients/me',
            body: {
              if (_dob.text.trim().isNotEmpty) 'dateOfBirth': _dob.text.trim(),
              if (_blood.text.trim().isNotEmpty)
                'bloodGroup': _blood.text.trim().toUpperCase(),
              if (_allergies.text.trim().isNotEmpty)
                'allergies': _allergies.text.trim(),
              if (_conditions.text.trim().isNotEmpty)
                'conditions': _conditions.text.trim(),
            },
          );
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved.')));
        context.pop();
      }
    } on AppException catch (e) {
      final detail = e.fields?.entries
          .map((f) => '${f.key}: ${f.value}')
          .join('\n');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(detail ?? describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Health profile')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(profileProvider)),
        data: (p) {
          if (!_loaded) {
            _loaded = true;
            _dob.text = (p['dateOfBirth'] as String?) ?? '';
            _blood.text = (p['bloodGroup'] as String?) ?? '';
            _allergies.text = (p['allergies'] as String?) ?? '';
            _conditions.text = (p['conditions'] as String?) ?? '';
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const NoticeBanner(
                'All health fields are optional. They help responders and clinicians, and are only shared as described in Privacy & data.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dob,
                decoration: const InputDecoration(
                  labelText: 'Date of birth',
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _blood,
                decoration: const InputDecoration(
                  labelText: 'Blood group (optional)',
                  hintText: 'e.g. O+',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _allergies,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Allergies (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _conditions,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Existing conditions (optional)',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency contacts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add contact'),
      ),
      body: contacts.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(contactsProvider),
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const NoticeBanner(
              'If you turn on SMS alerts below, your contacts receive a text with your name and shared location '
              'when you send a real (non-demo) emergency request. It needs an SMS provider configured on the server.',
              warning: true,
            ),
            const _SmsConsentTile(),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const EmptyView(
                icon: Icons.contacts_outlined,
                title: 'No contacts yet',
              ),
            for (final c in items)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(c['name'] as String),
                  subtitle: Text('${c['relationship'] ?? ''} ${c['phone']}'),
                  trailing: IconButton(
                    tooltip: 'Remove contact',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref
                          .read(apiClientProvider)
                          .delete('/patients/me/emergency-contacts/${c['id']}');
                      ref.invalidate(contactsProvider);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final relation = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: relation,
              decoration: const InputDecoration(
                labelText: 'Relationship (optional)',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/patients/me/emergency-contacts',
            body: {
              'name': name.text.trim(),
              'phone': phone.text.trim(),
              if (relation.text.trim().isNotEmpty)
                'relationship': relation.text.trim(),
            },
          );
      ref.invalidate(contactsProvider);
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }
}

class SensorSettingsScreen extends ConsumerWidget {
  const SensorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sensorControllerProvider);
    final c = ref.read(sensorControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Safety sensors')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const NoticeBanner(
            'Experimental. A phone-only detector can miss accidents and can trigger by mistake. '
            'It only flags a POSSIBLE incident and asks if you are OK first. It never replaces calling for help.',
            warning: true,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Monitor motion sensors'),
            subtitle: Text(switch (s.availability) {
              SensorAvailability.unavailable => 'Sensors are unavailable on this device. Use demonstration mode below.',
              _ =>
                s.settings.monitoringEnabled
                    ? 'Monitoring while the app is open.'
                    : 'Off. No sensor data is read.',
            }),
            value: s.settings.monitoringEnabled,
            onChanged: c.setMonitoring,
          ),
          SwitchListTile(
            title: const Text('Send an emergency request if I do not respond'),
            subtitle: const Text(
              'Off by default. When off, an expired countdown sends nothing.',
            ),
            value: s.settings.autoDispatchEnabled,
            onChanged: s.settings.monitoringEnabled ? c.setAutoDispatch : null,
          ),
          ListTile(
            title: const Text('Countdown length'),
            subtitle: Slider(
              min: 10,
              max: 60,
              divisions: 10,
              label: '${s.settings.countdownSeconds}s',
              value: s.settings.countdownSeconds.toDouble(),
              onChanged: (v) => c.setCountdown(v.round()),
            ),
            trailing: Text('${s.settings.countdownSeconds}s'),
          ),
          const Divider(height: 32),
          Text(
            'Demonstration mode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Simulates a sensor sequence so you can try the "Are you OK?" flow. It is clearly marked as simulated.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              c.simulateIncident();
              context.push('/safety-check');
            },
            icon: const Icon(Icons.science_outlined),
            label: const Text('Simulate a possible incident'),
          ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'What this app stores',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '• Your account and optional health profile\n'
            '• Appointments, medical records and medications you or your clinicians add\n'
            '• Emergency events, including the location you chose to share at that moment\n'
            '• An audit trail of who accessed sensitive data\n\n'
            'Location is requested only when you ask for help or check it. Motion sensors are read only if you '
            'turn monitoring on. Hospital operators cannot browse your medical records.',
          ),
          const SizedBox(height: 16),
          const NoticeBanner(
            'This is a demonstration build. It is not a certified medical device and has not been '
            'assessed against health-privacy regulations.',
            warning: true,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Deactivate account?'),
                  content: const Text(
                    'You will be signed out everywhere and your account will be deactivated.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(120, 48),
                      ),
                      child: const Text('Deactivate'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              try {
                await ref.read(apiClientProvider).delete('/users/me');
                await ref.read(authControllerProvider.notifier).logout();
              } on AppException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(describeError(e))));
                }
              }
            },
            icon: const Icon(Icons.person_off_outlined),
            label: const Text('Deactivate my account'),
          ),
        ],
      ),
    );
  }
}

/// Opt-in for SMS alerts to emergency contacts. Stored server-side as a consent record.
class _SmsConsentTile extends ConsumerStatefulWidget {
  const _SmsConsentTile();

  @override
  ConsumerState<_SmsConsentTile> createState() => _SmsConsentTileState();
}

class _SmsConsentTileState extends ConsumerState<_SmsConsentTile> {
  bool? _value;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/consents') as Map;
      if (mounted) {
        setState(() => _value = res['EMERGENCY_CONTACT_SMS'] == true);
      }
    } on AppException {
      if (mounted) setState(() => _value = false);
    }
  }

  Future<void> _set(bool v) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/consents',
            body: {'purpose': 'EMERGENCY_CONTACT_SMS', 'granted': v},
          );
      if (mounted) setState(() => _value = v);
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('Text my contacts when I send an emergency request'),
    subtitle: const Text(
      'Off by default. Never used for demonstration events.',
    ),
    value: _value ?? false,
    onChanged: (_value == null || _busy) ? null : _set,
  );
}
