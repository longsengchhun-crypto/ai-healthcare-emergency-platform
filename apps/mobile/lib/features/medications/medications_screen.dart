import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';
import '../../core/widgets/state_views.dart';
import 'reminder_scheduler.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler(),
);

final medicationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final res = await ref.read(apiClientProvider).get('/medications');
      return List<Map<String, dynamic>>.from(res as List);
    });

final remindersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final res = await ref
          .read(apiClientProvider)
          .get('/medication-reminders');
      return List<Map<String, dynamic>>.from(res as List);
    });

class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(medicationsProvider);
    final reminders = ref.watch(remindersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Medications')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addMedication(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add medication'),
      ),
      body: meds.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(medicationsProvider),
        ),
        data: (items) {
          final byId = {for (final m in items) m['id'] as String: m};
          final rems = reminders.value ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              const NoticeBanner(
                'This app records what you or your clinician entered. It never recommends or changes doses.',
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const EmptyView(
                  icon: Icons.medication_outlined,
                  title: 'No medications yet',
                  message: 'Add a medication to set daily reminders.',
                ),
              for (final m in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                m['name'] as String,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Chip(
                              label: Text(
                                m['source'] == 'PRESCRIPTION'
                                    ? 'Prescribed'
                                    : 'Entered by you',
                              ),
                            ),
                          ],
                        ),
                        if (m['dosage'] != null) Text(m['dosage'] as String),
                        if (m['instructions'] != null)
                          Text(m['instructions'] as String),
                        const SizedBox(height: 8),
                        for (final r in rems.where(
                          (r) => r['medicationId'] == m['id'],
                        ))
                          _ReminderTile(
                            reminder: r,
                            medication: byId[m['id']]!,
                          ),
                        TextButton.icon(
                          onPressed: () => _addReminder(context, ref, m),
                          icon: const Icon(Icons.alarm_add),
                          label: const Text('Add reminder'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addMedication(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final dosage = TextEditingController();
    final instructions = TextEditingController();
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
              decoration: const InputDecoration(labelText: 'Medication name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dosage,
              decoration: const InputDecoration(
                labelText: 'Dosage as prescribed (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: instructions,
              decoration: const InputDecoration(
                labelText: 'Instructions (optional)',
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
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/medications',
            body: {
              'name': name.text.trim(),
              if (dosage.text.trim().isNotEmpty) 'dosage': dosage.text.trim(),
              if (instructions.text.trim().isNotEmpty)
                'instructions': instructions.text.trim(),
            },
          );
      ref.invalidate(medicationsProvider);
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }

  Future<void> _addReminder(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> med,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    final scheduler = ref.read(reminderSchedulerProvider);
    final granted = await scheduler.requestPermission();
    // Timezone of the reminder is the clinic/user zone used for display; default to the app region.
    const zone = 'Asia/Phnom_Penh';
    try {
      final created =
          await ref
                  .read(apiClientProvider)
                  .post(
                    '/medication-reminders',
                    body: {
                      'medicationId': med['id'],
                      'timeOfDay':
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00',
                      'timezone': zone,
                      'startDate': DateFormat('yyyy-MM-dd')
                          .format(DateTime.now()),
                    },
                  )
              as Map;
      if (granted) {
        await scheduler.schedule(
          reminderId: created['id'] as String,
          hour: picked.hour,
          minute: picked.minute,
          timezoneName: zone,
        );
      }
      ref.invalidate(remindersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted ? 'Reminder set.' : 'Reminder saved, but notifications are blocked. Enable notification permission to be alerted.',
            ),
          ),
        );
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.reminder, required this.medication});
  final Map<String, dynamic> reminder;
  final Map<String, dynamic> medication;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = reminder['active'] as bool;
    final time = (reminder['timeOfDay'] as String).substring(0, 5);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('Daily at $time'),
      subtitle: Text(active ? 'On' : 'Paused'),
      value: active,
      onChanged: (v) async {
        final scheduler = ref.read(reminderSchedulerProvider);
        try {
          await ref
              .read(apiClientProvider)
              .patch(
                '/medication-reminders/${reminder['id']}',
                body: {'active': v},
              );
          if (v) {
            final parts = time.split(':');
            await scheduler.schedule(
              reminderId: reminder['id'] as String,
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
              timezoneName: reminder['timezone'] as String,
            );
          } else {
            await scheduler.cancel(reminder['id'] as String);
          }
          ref.invalidate(remindersProvider);
        } on AppException catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(describeError(e))));
          }
        }
      },
    );
  }
}
