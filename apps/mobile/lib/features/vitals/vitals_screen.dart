import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design/kit.dart';
import '../../core/design/palette.dart';
import '../../core/errors/app_exception.dart';
import '../../core/i18n/language.dart';
import '../../core/network/providers.dart';

/// Order matters: it is the order of the chips.
const vitalTypes = <String>[
  'BLOOD_PRESSURE',
  'HEART_RATE',
  'BLOOD_GLUCOSE',
  'OXYGEN_SATURATION',
  'TEMPERATURE',
  'WEIGHT',
];

final vitalsSummaryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final res = await ref.read(apiClientProvider).get('/vitals/summary');
      return List<Map<String, dynamic>>.from(res as List);
    });

final vitalsSeriesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, type) async {
      final res = await ref
          .read(apiClientProvider)
          .get('/vitals', query: {'type': type, 'days': '90'});
      return List<Map<String, dynamic>>.from(res as List);
    });

String vitalName(BuildContext c, String type) => switch (type) {
  'BLOOD_PRESSURE' => c.t('សម្ពាធឈាម', 'Blood pressure'),
  'HEART_RATE' => c.t('ចង្វាក់បេះដូង', 'Heart rate'),
  'BLOOD_GLUCOSE' => c.t('ជាតិស្ករក្នុងឈាម', 'Blood sugar'),
  'OXYGEN_SATURATION' => c.t('អុកស៊ីសែនក្នុងឈាម', 'Oxygen (SpO₂)'),
  'TEMPERATURE' => c.t('កម្ដៅ', 'Temperature'),
  _ => c.t('ទម្ងន់', 'Weight'),
};

IconData vitalIcon(String type) => switch (type) {
  'BLOOD_PRESSURE' => Icons.speed_rounded,
  'HEART_RATE' => Icons.favorite_rounded,
  'BLOOD_GLUCOSE' => Icons.water_drop_rounded,
  'OXYGEN_SATURATION' => Icons.air_rounded,
  'TEMPERATURE' => Icons.thermostat_rounded,
  _ => Icons.monitor_weight_rounded,
};

String formatVital(Map<String, dynamic> v) {
  String n(num x) =>
      x == x.roundToDouble() ? x.toInt().toString() : x.toStringAsFixed(1);
  final v1 = n(v['value1'] as num);
  final v2 = v['value2'] as num?;
  return v2 == null ? v1 : '$v1/${n(v2)}';
}

/// Plain-language reading of the server's assessment code. Information only, never a diagnosis.
String vitalAdvice(BuildContext c, String code) => switch (code) {
  'BP_VERY_HIGH' => c.t(
    'ខ្ពស់ខ្លាំង។ បើមានឈឺក្បាល ឈឺទ្រូង ឬមើល/និយាយមិនច្បាស់ សូមស្វែងរកជំនួយបន្ទាន់ភ្លាម។ បើមិនដូច្នោះ សូមសម្រាក វាស់ម្ដងទៀត ហើយទាក់ទងគ្រូពេទ្យថ្ងៃនេះ។',
    'Very high. If you have a headache, chest pain, or trouble seeing or speaking, get emergency help now. Otherwise rest, measure again and contact a doctor today.',
  ),
  'BP_HIGH' => c.t(
    'ខ្ពស់ជាងធម្មតា។ សូមវាស់ម្ដងទៀតពេលសម្រាក ហើយប្រាប់គ្រូពេទ្យប្រសិនបើនៅតែខ្ពស់។',
    'Higher than typical. Measure again while resting and tell your doctor if it stays high.',
  ),
  'BP_LOW' => c.t(
    'ទាបជាងធម្មតា។ បើវិលមុខ ឬចង់ដួល សូមអង្គុយ ហើយទាក់ទងគ្រូពេទ្យ។',
    'Lower than typical. If you feel dizzy or faint, sit down and contact a doctor.',
  ),
  'HR_EXTREME' => c.t(
    'ចង្វាក់ខុសពីធម្មតាខ្លាំង។ បើមានឈឺទ្រូង ហត់ ឬវិលមុខ សូមស្វែងរកជំនួយបន្ទាន់។',
    'Far outside the typical range. With chest pain, breathlessness or dizziness, get emergency help.',
  ),
  'HR_HIGH' => c.t(
    'លឿនជាងធម្មតា (ពេលសម្រាក)។ សូមសម្រាក ហើយវាស់ម្ដងទៀត។',
    'Faster than typical at rest. Rest and measure again.',
  ),
  'HR_LOW' => c.t(
    'យឺតជាងធម្មតា។ ប្រាប់គ្រូពេទ្យបើអ្នកមិនមែនជាអត្តពលិក ឬមានវិលមុខ។',
    'Slower than typical. Tell a doctor if you are not an athlete or feel dizzy.',
  ),
  'GLUCOSE_VERY_LOW' => c.t(
    'ទាបខ្លាំង។ សូមទទួលទានស្ករ ឬភេសជ្ជៈផ្អែមភ្លាមៗ ហើយស្វែងរកជំនួយបើមិនប្រសើរ។',
    'Very low. Take fast sugar or a sweet drink now and get help if you do not improve.',
  ),
  'GLUCOSE_LOW' => c.t(
    'ទាបជាងធម្មតា។ សូមញ៉ាំអ្វីមួយ ហើយវាស់ម្ដងទៀត។',
    'Lower than typical. Eat something and measure again.',
  ),
  'GLUCOSE_HIGH' => c.t(
    'ខ្ពស់ជាងធម្មតា។ ប្រាប់គ្រូពេទ្យប្រសិនបើកើតឡើងញឹកញាប់។',
    'Higher than typical. Tell your doctor if this happens often.',
  ),
  'GLUCOSE_VERY_HIGH' => c.t(
    'ខ្ពស់ខ្លាំង។ សូមទាក់ទងគ្រូពេទ្យថ្ងៃនេះ ហើយស្វែងរកជំនួយបន្ទាន់បើក្អួត ឬច្របូកច្របល់។',
    'Very high. Contact a doctor today, and get emergency help if you vomit or feel confused.',
  ),
  'TEMP_VERY_HIGH' => c.t(
    'គ្រុនក្តៅខ្លាំង។ សូមទាក់ទងគ្រូពេទ្យឥឡូវនេះ។',
    'High fever. Contact a doctor now.',
  ),
  'TEMP_FEVER' => c.t(
    'មានគ្រុន។ សូមសម្រាក ផឹកទឹកឲ្យបានច្រើន ហើយតាមដាន។',
    'Fever. Rest, drink plenty of fluids and keep monitoring.',
  ),
  'TEMP_LOW' => c.t(
    'ទាបជាងធម្មតា។ សូមកក់ក្ដៅ ហើយវាស់ម្ដងទៀត។',
    'Lower than typical. Warm up and measure again.',
  ),
  'SPO2_VERY_LOW' => c.t(
    'ទាបខ្លាំង។ បើមានពិបាកដកដង្ហើម សូមស្វែងរកជំនួយបន្ទាន់ភ្លាម។',
    'Very low. If you are short of breath, get emergency help immediately.',
  ),
  'SPO2_LOW' => c.t(
    'ទាបជាងធម្មតា។ សូមវាស់ម្ដងទៀតពេលស្ងប់ ហើយទាក់ទងគ្រូពេទ្យបើនៅតែទាប។',
    'Lower than typical. Measure again while calm and contact a doctor if it stays low.',
  ),
  _ => c.t('ស្ថិតក្នុងកម្រិតធម្មតា។', 'Within the typical range.'),
};

Tone toneFor(String level) => switch (level) {
  'URGENT' => Tone.red,
  'ATTENTION' => Tone.amber,
  'NORMAL' => Tone.green,
  _ => Tone.neutral,
};

String levelLabel(BuildContext c, String level) => switch (level) {
  'URGENT' => c.t('ត្រូវការយកចិត្តទុកដាក់ភ្លាម', 'Needs attention now'),
  'ATTENTION' => c.t('ចាប់អារម្មណ៍', 'Worth noting'),
  'NORMAL' => c.t('ធម្មតា', 'Typical'),
  _ => c.t('បានកត់ត្រា', 'Recorded'),
};

class VitalsScreen extends ConsumerStatefulWidget {
  const VitalsScreen({super.key});

  @override
  ConsumerState<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends ConsumerState<VitalsScreen> {
  String _type = vitalTypes.first;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final series = ref.watch(vitalsSeriesProvider(_type));
    final summary = ref.watch(vitalsSummaryProvider).value;
    final stat = summary?.firstWhere(
      (s) => s['type'] == _type,
      orElse: () => const {},
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('ការវាស់សុខភាព', 'Health readings')),
      ),
      floatingActionButton: Tap(
        onTap: () => _add(context),
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
                context.t('កត់ត្រាលទ្ធផល', 'Add reading'),
                style: TextStyle(color: p.paper, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
      body: PageWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 110),
          children: [
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: vitalTypes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final t = vitalTypes[i];
                  final on = t == _type;
                  return Tap(
                    onTap: () => setState(() => _type = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? p.ink : p.surface,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        border: Border.all(color: on ? p.ink : p.line),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            vitalIcon(t),
                            size: 17,
                            color: on ? p.paper : p.inkSoft,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            vitalName(context, t),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: on ? p.paper : p.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Gap.lg),
            series.when(
              loading: () => Column(
                children: const [
                  Skeleton(height: 230, radius: 22),
                  SizedBox(height: 12),
                  Skeleton(height: 90, radius: 22),
                ],
              ),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(vitalsSeriesProvider(_type)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EmptyState(
                      art: Art.pulse,
                      title: context.t('មិនទាន់មានលទ្ធផល', 'No readings yet'),
                      message: context.t(
                        'កត់ត្រាលទ្ធផលដំបូង ដើម្បីមើលនិន្នាការ។',
                        'Add your first reading to see your trend.',
                      ),
                    ),
                  );
                }
                final latest = items.first;
                final level = latest['level'] as String;
                final avg = stat?['average30d'] as num?;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatVital(latest),
                                style: TextStyle(
                                  fontSize: 44,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: p.ink,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Text(
                                  latest['unit'] as String,
                                  style: TextStyle(
                                    color: p.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Pill(
                            levelLabel(context, level),
                            tone: toneFor(level),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _when(
                              DateTime.parse(latest['measuredAt'] as String)
                                  .toLocal(),
                            ),
                            style: TextStyle(color: p.muted, fontSize: 13),
                          ),
                          if (avg != null &&
                              (stat?['count30d'] as num) > 1) ...[
                            const SizedBox(height: 2),
                            Text(
                              context.t(
                                'មធ្យម ៣០ ថ្ងៃ៖ ${avg.toStringAsFixed(1)}',
                                '30-day average: ${avg.toStringAsFixed(1)}',
                              ),
                              style: TextStyle(color: p.muted, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: Gap.lg),
                          SizedBox(
                            height: 150,
                            child: CustomPaint(
                              painter: _TrendPainter(
                                values: items.reversed.toList(),
                                type: _type,
                                line: p.ink,
                                second: p.teal,
                                band: p.greenSoft,
                                grid: p.line,
                                dot: p.ink,
                                label: p.muted,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (level != 'NORMAL' && level != 'RECORDED') ...[
                      const SizedBox(height: Gap.md),
                      Notice(
                        vitalAdvice(context, latest['code'] as String),
                        tone: level == 'URGENT' ? Tone.red : Tone.amber,
                      ),
                    ],
                    const SizedBox(height: Gap.xl),
                    SectionHeader(
                      context.t('ប្រវត្តិ', 'History'),
                      count: items.length,
                    ),
                    Surface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: p.line),
                            _HistoryRow(
                              item: items[i],
                              onDelete: () => _delete(context, items[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    Notice(
                      context.t(
                        'ព័ត៌មាននេះសម្រាប់តាមដាន មិនមែនជាការធ្វើរោគវិនិច្ឆ័យទេ។ សូមសួរគ្រូពេទ្យអំពីលទ្ធផលរបស់អ្នក។',
                        'This is for tracking, not a diagnosis. Ask your doctor what your numbers mean for you.',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _when(DateTime d) => DateFormat('d MMM yyyy · HH:mm').format(d);

  Future<void> _delete(BuildContext context, Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('លុបលទ្ធផលនេះ?', 'Delete this reading?')),
        content: Text(
          '${formatVital(item)} ${item['unit']} · ${_when(DateTime.parse(item['measuredAt'] as String).toLocal())}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('បោះបង់', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('លុប', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).delete('/vitals/${item['id']}');
      ref.invalidate(vitalsSeriesProvider(_type));
      ref.invalidate(vitalsSummaryProvider);
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }

  Future<void> _add(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddReadingSheet(type: _type),
    );
    if (saved == true) {
      ref.invalidate(vitalsSeriesProvider(_type));
      ref.invalidate(vitalsSummaryProvider);
    }
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item, required this.onDelete});
  final Map<String, dynamic> item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final level = item['level'] as String;
    final color = switch (level) {
      'URGENT' => p.red,
      'ATTENTION' => p.amber,
      'NORMAL' => p.green,
      _ => p.muted,
    };
    final when = DateFormat('d MMM · HH:mm')
        .format(DateTime.parse(item['measuredAt'] as String).toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatVital(item)} ${item['unit']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  [
                    when,
                    if (item['note'] != null) item['note'] as String,
                  ].join(' · '),
                  style: TextStyle(color: p.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.t('លុប', 'Delete'),
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _AddReadingSheet extends ConsumerStatefulWidget {
  const _AddReadingSheet({required this.type});
  final String type;

  @override
  ConsumerState<_AddReadingSheet> createState() => _AddReadingSheetState();
}

class _AddReadingSheetState extends ConsumerState<_AddReadingSheet> {
  final _v1 = TextEditingController();
  final _v2 = TextEditingController();
  final _note = TextEditingController();
  late String _type = widget.type;
  DateTime? _when; // null = now
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _v1.dispose();
    _v2.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _when ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when ?? now),
    );
    if (t == null) return;
    var picked = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (picked.isAfter(now)) picked = now;
    setState(() => _when = picked);
  }

  Future<void> _save() async {
    final a = double.tryParse(_v1.text.trim().replaceAll(',', '.'));
    final b = double.tryParse(_v2.text.trim().replaceAll(',', '.'));
    if (a == null || (_type == 'BLOOD_PRESSURE' && b == null)) {
      setState(
        () => _error = context.t(
          'សូមបញ្ចូលលេខឲ្យត្រឹមត្រូវ។',
          'Please enter the number(s).',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/vitals',
            body: {
              'type': _type,
              'value1': a,
              if (_type == 'BLOOD_PRESSURE') 'value2': b,
              if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
              if (_when != null) 'measuredAt': _when!.toUtc().toIso8601String(),
            },
          );
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final isBp = _type == 'BLOOD_PRESSURE';
    final unit = switch (_type) {
      'BLOOD_PRESSURE' => 'mmHg',
      'HEART_RATE' => 'bpm',
      'BLOOD_GLUCOSE' => 'mg/dL',
      'OXYGEN_SATURATION' => '%',
      'TEMPERATURE' => '°C',
      _ => 'kg',
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.page,
        4,
        Gap.page,
        MediaQuery.of(context).viewInsets.bottom + Gap.page,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('កត់ត្រាលទ្ធផលថ្មី', 'New reading'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in vitalTypes)
                  ChoiceChip(
                    label: Text(vitalName(context, t)),
                    selected: t == _type,
                    onSelected: (_) => setState(() {
                      _type = t;
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _v1,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: isBp
                          ? context.t(
                              'លេខលើ (Systolic)',
                              'Top number (systolic)',
                            )
                          : '${vitalName(context, _type)} ($unit)',
                    ),
                  ),
                ),
                if (isBp) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _v2,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.t(
                          'លេខក្រោម (Diastolic)',
                          'Bottom number (diastolic)',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: _note,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: context.t(
                  'កំណត់ចំណាំ (មិនចាំបាច់)',
                  'Note (optional), e.g. after meal',
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: Gap.sm),
            Tap(
              onTap: _pickTime,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 19, color: p.teal),
                    const SizedBox(width: 8),
                    Text(
                      _when == null
                          ? context.t('ពេលនេះ · ប្ដូរម៉ោង', 'Now · change time')
                          : DateFormat('d MMM yyyy · HH:mm').format(_when!),
                      style: TextStyle(
                        color: p.teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Gap.sm),
              Notice(_error!, tone: Tone.red),
            ],
            const SizedBox(height: Gap.lg),
            PrimaryButton(
              label: context.t('រក្សាទុក', 'Save'),
              busy: _busy,
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal line chart: typical-range band, one line (two for blood pressure), last point emphasised.
class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.type,
    required this.line,
    required this.second,
    required this.band,
    required this.grid,
    required this.dot,
    required this.label,
  });

  final List<Map<String, dynamic>> values; // oldest -> newest
  final String type;
  final Color line, second, band, grid, dot, label;

  static const _bands = <String, (double, double)>{
    'BLOOD_PRESSURE': (90, 130),
    'HEART_RATE': (50, 100),
    'BLOOD_GLUCOSE': (70, 180),
    'OXYGEN_SATURATION': (95, 100),
    'TEMPERATURE': (35, 38),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final isBp = type == 'BLOOD_PRESSURE';
    final all = <double>[
      for (final v in values) (v['value1'] as num).toDouble(),
      if (isBp)
        for (final v in values)
          if (v['value2'] != null) (v['value2'] as num).toDouble(),
    ];
    final ref = _bands[type];
    var lo = all.reduce((a, b) => a < b ? a : b);
    var hi = all.reduce((a, b) => a > b ? a : b);
    if (ref != null) {
      lo = lo < ref.$1 ? lo : ref.$1;
      hi = hi > ref.$2 ? hi : ref.$2;
    }
    final pad = (hi - lo) == 0 ? 1.0 : (hi - lo) * 0.12;
    lo -= pad;
    hi += pad;
    const left = 4.0, right = 4.0, top = 8.0, bottom = 8.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    double x(int i) =>
        left + (values.length == 1 ? w / 2 : w * i / (values.length - 1));
    double y(double v) => top + h * (1 - (v - lo) / (hi - lo));

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final gy = top + h * i / 2;
      canvas.drawLine(Offset(left, gy), Offset(left + w, gy), gridPaint);
    }
    if (ref != null) {
      canvas.drawRect(
        Rect.fromLTRB(left, y(ref.$2), left + w, y(ref.$1)),
        Paint()..color = band.withValues(alpha: 0.75),
      );
    }

    void series(String key, Color c) {
      final path = Path();
      var started = false;
      final points = <Offset>[];
      for (var i = 0; i < values.length; i++) {
        final raw = values[i][key] as num?;
        if (raw == null) continue;
        final o = Offset(x(i), y(raw.toDouble()));
        points.add(o);
        if (!started) {
          path.moveTo(o.dx, o.dy);
          started = true;
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (var i = 0; i < points.length; i++) {
        final last = i == points.length - 1;
        canvas.drawCircle(points[i], last ? 5 : 3, Paint()..color = c);
      }
    }

    if (isBp) series('value2', second);
    series('value1', line);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.type != type || old.line != line;
}

/// Compact tile for the home screen: latest value or a prompt to start tracking.
class VitalsHomeCard extends ConsumerWidget {
  const VitalsHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final summary = ref.watch(vitalsSummaryProvider).value;
    final withData =
        summary?.where((s) => s['latest'] != null).toList() ?? const [];
    String text;
    if (withData.isEmpty) {
      text = context.t(
        'កត់ត្រាសម្ពាធឈាម ស្ករ ទម្ងន់…',
        'Track blood pressure, sugar, weight…',
      );
    } else {
      final s = withData.first;
      text =
          '${vitalName(context, s['type'] as String)}: ${formatVital(Map<String, dynamic>.from(s['latest'] as Map))} ${s['unit']}';
    }
    return Surface(
      onTap: () => context.push('/vitals'),
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.tealSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.monitor_heart_rounded, color: p.tealDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('ការវាស់សុខភាព', 'Health readings'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.muted, fontSize: 13, height: 1.35),
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
