import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/kit.dart';
import '../../core/design/palette.dart';
import '../../core/errors/app_exception.dart';
import '../../core/i18n/language.dart';
import '../../core/network/providers.dart';
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
    final p = Palette.of(context);
    final meds = ref.watch(medicationsProvider);
    final reminders = ref.watch(remindersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('ថ្នាំរបស់ខ្ញុំ', 'My medicines'))),
      floatingActionButton: Tap(
        onTap: () => _addMedication(context, ref),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: p.ink,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: p.paper),
              const SizedBox(width: 8),
              Text(
                context.t('បន្ថែមថ្នាំ', 'Add medicine'),
                style: TextStyle(color: p.paper, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
      body: PageWidth(
        child: meds.when(
          loading: () => const SkeletonList(),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(medicationsProvider),
          ),
          data: (items) {
            final rems = reminders.value ?? const <Map<String, dynamic>>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.sm,
                Gap.page,
                110,
              ),
              children: [
                Notice(
                  context.t(
                    'កម្មវិធីនេះកត់ត្រាតែអ្វីដែលអ្នក ឬគ្រូពេទ្យបានបញ្ចូល ហើយមិនដែលណែនាំ ឬកែកម្រិតថ្នាំឡើយ។',
                    'This app only records what you or your clinician entered. It never recommends or changes doses.',
                  ),
                  tone: Tone.teal,
                ),
                const SizedBox(height: Gap.lg),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EmptyState(
                      art: Art.pill,
                      title: context.t('មិនទាន់មានថ្នាំ', 'No medicines yet'),
                      message: context.t(
                        'បន្ថែមថ្នាំ ហើយកំណត់ការរំលឹករាល់ថ្ងៃ។',
                        'Add a medicine and set a daily reminder.',
                      ),
                    ),
                  ),
                for (final m in items) ...[
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: p.tealSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.medication_rounded,
                                color: p.tealDeep,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m['name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16.5,
                                    ),
                                  ),
                                  if (m['dosage'] != null)
                                    Text(
                                      m['dosage'] as String,
                                      style: TextStyle(color: p.inkSoft),
                                    ),
                                ],
                              ),
                            ),
                            Pill(
                              m['source'] == 'PRESCRIPTION'
                                  ? context.t('តាមវេជ្ជបញ្ជា', 'Prescribed')
                                  : context.t('អ្នកបញ្ចូល', 'Entered by you'),
                              tone: m['source'] == 'PRESCRIPTION'
                                  ? Tone.teal
                                  : Tone.neutral,
                            ),
                          ],
                        ),
                        if (m['instructions'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              m['instructions'] as String,
                              style: TextStyle(color: p.muted, height: 1.45),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Divider(color: p.line),
                        for (final r in rems.where(
                          (r) => r['medicationId'] == m['id'],
                        ))
                          _ReminderRow(reminder: r),
                        Tap(
                          onTap: () => _addReminder(context, ref, m),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_alarm_rounded,
                                  color: p.teal,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.t('បន្ថែមការរំលឹក', 'Add a reminder'),
                                  style: TextStyle(
                                    color: p.teal,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
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
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.page,
          4,
          Gap.page,
          MediaQuery.of(ctx).viewInsets.bottom + Gap.page,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ctx.t('ថ្នាំថ្មី', 'New medicine'),
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: ctx.t('ឈ្មោះថ្នាំ', 'Medicine name'),
              ),
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: dosage,
              decoration: InputDecoration(
                labelText: ctx.t(
                  'កម្រិតតាមវេជ្ជបញ្ជា (មិនចាំបាច់)',
                  'Dose as prescribed (optional)',
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: instructions,
              decoration: InputDecoration(
                labelText: ctx.t(
                  'សេចក្តីណែនាំ (មិនចាំបាច់)',
                  'Instructions (optional)',
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),
            PrimaryButton(
              label: ctx.t('រក្សាទុក', 'Save'),
              onPressed: () => Navigator.pop(ctx, true),
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
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
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
    const zone = 'Asia/Phnom_Penh';
    final now = DateTime.now();
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
                      'startDate':
                          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
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
              granted
                  ? context.t('បានកំណត់ការរំលឹក។', 'Reminder set.')
                  : context.t(
                      'បានរក្សាទុកការរំលឹក ប៉ុន្តែការជូនដំណឹងត្រូវបានបិទ។ សូមអនុញ្ញាតដើម្បីទទួលការរំលឹក។',
                      'Reminder saved, but notifications are blocked. Allow them to be alerted.',
                    ),
            ),
          ),
        );
      }
    } on AppException catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }
}

class _ReminderRow extends ConsumerWidget {
  const _ReminderRow({required this.reminder});
  final Map<String, dynamic> reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final active = reminder['active'] as bool;
    final time = (reminder['timeOfDay'] as String).substring(0, 5);
    return Row(
      children: [
        Icon(Icons.alarm_rounded, size: 20, color: active ? p.teal : p.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$time · ${context.t('រាល់ថ្ងៃ', 'every day')}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: active ? p.ink : p.muted,
            ),
          ),
        ),
        Switch(
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
              if (context.mounted)
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(describeError(e))));
            }
          },
        ),
      ],
    );
  }
}
