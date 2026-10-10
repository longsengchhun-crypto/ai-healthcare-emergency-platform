import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/state_views.dart';
import '../authentication/auth_controller.dart';

final appointmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final res = await ref
          .read(apiClientProvider)
          .get('/appointments', query: {'size': 50});
      return List<Map<String, dynamic>>.from((res as Map)['items'] as List);
    });

Color _statusColor(String s) => switch (s) {
  'CONFIRMED' => AppColors.success,
  'REQUESTED' => AppColors.blue,
  'COMPLETED' => Colors.grey,
  _ => AppColors.warning,
};

String _statusLabel(String s) => switch (s) {
  'CONFIRMED' => 'បានបញ្ជាក់ · Confirmed',
  'REQUESTED' => 'កំពុងរង់ចាំ · Pending',
  'COMPLETED' => 'បានបញ្ចប់ · Completed',
  'CANCELLED' => 'បានលុបចោល · Cancelled',
  'REJECTED' => 'បានបដិសេធ · Declined',
  _ => s,
};

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    String id,
    String action,
  ) async {
    try {
      await ref.read(apiClientProvider).post('/appointments/$id/$action');
      ref.invalidate(appointmentsProvider);
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }

  Future<void> _reschedule(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> a,
  ) async {
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (day == null || !context.mounted) return;
    try {
      final key = DateFormat('yyyy-MM-dd').format(day);
      final res = await ref
          .read(apiClientProvider)
          .get('/doctors/${a['doctorId']}/slots', query: {'date': key});
      final slots = [
        for (final s in res as List)
          DateTime.parse((s as Map)['startsAt'] as String).toLocal(),
      ];
      if (!context.mounted) return;
      if (slots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No free times on that day.')),
        );
        return;
      }
      final picked = await showDialog<DateTime>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('Pick a time on $key'),
          children: [
            for (final t in slots)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, t),
                child: Text(DateFormat('HH:mm').format(t)),
              ),
          ],
        ),
      );
      if (picked == null) return;
      await ref
          .read(apiClientProvider)
          .patch(
            '/appointments/${a['id']}',
            body: {'startsAt': picked.toUtc().toIso8601String()},
          );
      ref.invalidate(appointmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rescheduled. The doctor needs to confirm again.'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final isDoctor = user?.isDoctor ?? false;
    final appts = ref.watch(appointmentsProvider);
    final fmt = DateFormat('EEE d MMM · HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isDoctor ? 'កាលវិភាគ · Schedule' : 'ការណាត់ជួប · Appointments',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(appointmentsProvider.future),
        child: appts.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(appointmentsProvider),
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyView(
                      icon: Icons.event_available_outlined,
                      title: 'មិនទាន់មានការណាត់ជួប · No appointments yet',
                      message: 'Find a doctor in Discover to request one.',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final a = items[i];
                    final status = a['status'] as String;
                    final active =
                        status == 'REQUESTED' || status == 'CONFIRMED';
                    final start = DateTime.parse(a['startsAt'] as String)
                        .toLocal();
                    final who = isDoctor
                        ? a['patientName'] as String
                        : a['doctorName'] as String;
                    final color = _statusColor(status);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                PersonAvatar(
                                  name: who,
                                  photoUrl: isDoctor
                                      ? null
                                      : a['doctorPhotoUrl'] as String?,
                                  size: 52,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        who,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (!isDoctor &&
                                          a['doctorSpecialty'] != null)
                                        Text(
                                          a['doctorSpecialty'] as String,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(fmt.format(start)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TagChip(_statusLabel(status), color: color),
                                if (a['reason'] != null)
                                  Text(
                                    a['reason'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                    ),
                                  ),
                              ],
                            ),
                            if (active) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (isDoctor && status == 'REQUESTED') ...[
                                    FilledButton(
                                      onPressed: () => _act(
                                        context,
                                        ref,
                                        a['id'] as String,
                                        'confirm',
                                      ),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(110, 44),
                                      ),
                                      child: const Text('បញ្ជាក់ · Confirm'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _act(
                                        context,
                                        ref,
                                        a['id'] as String,
                                        'reject',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(110, 44),
                                      ),
                                      child: const Text('បដិសេធ · Decline'),
                                    ),
                                  ],
                                  if (isDoctor && status == 'CONFIRMED')
                                    FilledButton(
                                      onPressed: () => _act(
                                        context,
                                        ref,
                                        a['id'] as String,
                                        'complete',
                                      ),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(130, 44),
                                      ),
                                      child: const Text(
                                        'បញ្ចប់ · Mark completed',
                                      ),
                                    ),
                                  if (!isDoctor)
                                    OutlinedButton(
                                      onPressed: () =>
                                          _reschedule(context, ref, a),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(110, 44),
                                      ),
                                      child: const Text(
                                        'ប្តូរម៉ោង · Reschedule',
                                      ),
                                    ),
                                  OutlinedButton(
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            'លុបចោលការណាត់ជួប? · Cancel appointment?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text(
                                                'រក្សាទុក · Keep',
                                              ),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              style: FilledButton.styleFrom(
                                                minimumSize: const Size(
                                                  100,
                                                  48,
                                                ),
                                              ),
                                              child: const Text(
                                                'លុប · Cancel it',
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true && context.mounted) {
                                        await _act(
                                          context,
                                          ref,
                                          a['id'] as String,
                                          'cancel',
                                        );
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(110, 44),
                                    ),
                                    child: const Text('លុបចោល · Cancel'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
