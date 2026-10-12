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

final appointmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final res = await ref
          .read(apiClientProvider)
          .get('/appointments', query: {'size': 50});
      return List<Map<String, dynamic>>.from((res as Map)['items'] as List);
    });

(String, String, Tone) _status(String s) => switch (s) {
  'CONFIRMED' => ('បានបញ្ជាក់', 'Confirmed', Tone.green),
  'REQUESTED' => ('កំពុងរង់ចាំ', 'Waiting', Tone.blue),
  'COMPLETED' => ('បានបញ្ចប់', 'Completed', Tone.neutral),
  'CANCELLED' => ('បានលុបចោល', 'Cancelled', Tone.amber),
  'REJECTED' => ('បានបដិសេធ', 'Declined', Tone.amber),
  _ => (s, s, Tone.neutral),
};

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  int _tab = 0;

  Future<void> _act(String id, String action) async {
    try {
      await ref.read(apiClientProvider).post('/appointments/$id/$action');
      ref.invalidate(appointmentsProvider);
    } on AppException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _reschedule(Map<String, dynamic> a) async {
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (day == null || !mounted) return;
    try {
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final res = await ref
          .read(apiClientProvider)
          .get('/doctors/${a['doctorId']}/slots', query: {'date': key});
      final slots = [
        for (final s in res as List)
          DateTime.parse((s as Map)['startsAt'] as String).toLocal(),
      ];
      if (!mounted) return;
      if (slots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t('គ្មានពេលទំនេរនៅថ្ងៃនេះ។', 'No free times that day.'),
            ),
          ),
        );
        return;
      }
      final picked = await showModalBottomSheet<DateTime>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 4, Gap.page, Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ctx.t('ជ្រើសរើសម៉ោងថ្មី', 'Choose a new time'),
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: Gap.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in slots)
                    TimeTile(
                      label: ctx.fmt('HH:mm', t),
                      selected: false,
                      onTap: () => Navigator.pop(ctx, t),
                    ),
                ],
              ),
            ],
          ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'បានប្តូរម៉ោង។ គ្រូពេទ្យត្រូវបញ្ជាក់ម្តងទៀត។',
                'Rescheduled. The doctor needs to confirm again.',
              ),
            ),
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _confirmCancel(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('លុបចោលការណាត់ជួប?', 'Cancel this appointment?')),
        content: Text(
          ctx.t(
            'ពេលនេះនឹងត្រូវបានដោះលែងសម្រាប់អ្នកផ្សេង។',
            'The time will be released for other patients.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('រក្សាទុក', 'Keep it')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              ctx.t('លុបចោល', 'Cancel it'),
              style: TextStyle(
                color: Palette.of(ctx).red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await _act(id, 'cancel');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final isDoctor = user?.isDoctor ?? false;
    final appts = ref.watch(appointmentsProvider);
    return Scaffold(
      body: SafeArea(
        child: PageWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.lg,
                  Gap.page,
                  Gap.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDoctor
                          ? context.t('កាលវិភាគ', 'Schedule')
                          : context.t('ការណាត់ជួប', 'Appointments'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: Gap.md),
                    Segmented(
                      labels: [
                        context.t('ខាងមុខ', 'Upcoming'),
                        context.t('ប្រវត្តិ', 'History'),
                      ],
                      index: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(appointmentsProvider.future),
                  child: appts.when(
                    loading: () => const SkeletonList(),
                    error: (e, _) => ErrorState(
                      error: e,
                      onRetry: () => ref.invalidate(appointmentsProvider),
                    ),
                    data: (all) {
                      final upcoming =
                          all
                              .where(
                                (a) =>
                                    a['status'] == 'REQUESTED' ||
                                    a['status'] == 'CONFIRMED',
                              )
                              .toList()
                            ..sort(
                              (a, b) => (a['startsAt'] as String).compareTo(
                                b['startsAt'] as String,
                              ),
                            );
                      final history =
                          all
                              .where(
                                (a) =>
                                    !(a['status'] == 'REQUESTED' ||
                                        a['status'] == 'CONFIRMED'),
                              )
                              .toList()
                            ..sort(
                              (a, b) => (b['startsAt'] as String).compareTo(
                                a['startsAt'] as String,
                              ),
                            );
                      final items = _tab == 0 ? upcoming : history;
                      if (items.isEmpty) {
                        return ListView(
                          children: [
                            const SizedBox(height: 60),
                            EmptyState(
                              art: Art.calendar,
                              title: _tab == 0
                                  ? context.t(
                                      'មិនទាន់មានការណាត់ជួប',
                                      'No upcoming appointments',
                                    )
                                  : context.t(
                                      'មិនទាន់មានប្រវត្តិ',
                                      'No history yet',
                                    ),
                              message: _tab == 0 && !isDoctor
                                  ? context.t(
                                      'ស្វែងរកគ្រូពេទ្យ ហើយស្នើសុំពេលណាត់ជួប។',
                                      'Find a doctor and request a time.',
                                    )
                                  : null,
                              action: _tab == 0 && !isDoctor
                                  ? context.t('រកគ្រូពេទ្យ', 'Find a doctor')
                                  : null,
                              onAction: () => context.go('/discover'),
                            ),
                          ],
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          Gap.page,
                          0,
                          Gap.page,
                          Gap.xl,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _Card(
                          a: items[i],
                          isDoctor: isDoctor,
                          onConfirm: () =>
                              _act(items[i]['id'] as String, 'confirm'),
                          onReject: () =>
                              _act(items[i]['id'] as String, 'reject'),
                          onComplete: () =>
                              _act(items[i]['id'] as String, 'complete'),
                          onReschedule: () => _reschedule(items[i]),
                          onCancel: () =>
                              _confirmCancel(items[i]['id'] as String),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.a,
    required this.isDoctor,
    required this.onConfirm,
    required this.onReject,
    required this.onComplete,
    required this.onReschedule,
    required this.onCancel,
  });
  final Map<String, dynamic> a;
  final bool isDoctor;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onComplete;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final start = DateTime.parse(a['startsAt'] as String).toLocal();
    final status = a['status'] as String;
    final active = status == 'REQUESTED' || status == 'CONFIRMED';
    final (km, en, tone) = _status(status);
    final who = isDoctor
        ? a['patientName'] as String
        : a['doctorName'] as String;
    return Surface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DateBlock(
                day: '${start.day}',
                month: context.fmt('MMM', start),
                highlight: status == 'CONFIRMED',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.fmt('EEE', start)} · ${context.fmt('HH:mm', start)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      who,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isDoctor && a['doctorSpecialty'] != null)
                      Text(
                        a['doctorSpecialty'] as String,
                        style: TextStyle(color: p.muted, fontSize: 12.5),
                      ),
                  ],
                ),
              ),
              Pill(context.t(km, en), tone: tone),
            ],
          ),
          if (a['reason'] != null) ...[
            const SizedBox(height: 10),
            Text(
              '“${a['reason']}”',
              style: TextStyle(
                color: p.muted,
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ],
          if (active) ...[
            const SizedBox(height: 12),
            Divider(color: p.line),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isDoctor && status == 'REQUESTED') ...[
                  _Action(
                    context.t('បញ្ជាក់', 'Confirm'),
                    onConfirm,
                    strong: true,
                  ),
                  _Action(context.t('បដិសេធ', 'Decline'), onReject),
                ],
                if (isDoctor && status == 'CONFIRMED')
                  _Action(
                    context.t('បញ្ចប់ការពិនិត្យ', 'Mark completed'),
                    onComplete,
                    strong: true,
                  ),
                if (isDoctor)
                  _Action(
                    context.t('កំណត់ត្រាអ្នកជំងឺ', 'Patient records'),
                    () => context.push(
                      '/patient/${a['patientId']}/records',
                      extra: a['patientName'],
                    ),
                  ),
                if (!isDoctor)
                  _Action(context.t('ប្តូរម៉ោង', 'Reschedule'), onReschedule),
                _Action(context.t('លុបចោល', 'Cancel'), onCancel, danger: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(
    this.label,
    this.onTap, {
    this.strong = false,
    this.danger = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool strong;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (bg, fg) = danger
        ? (p.redSoft, p.red)
        : strong
        ? (p.brand, Colors.white)
        : (p.brandSoft, p.brandDeep);
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: fg,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
