import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/kit.dart';
import '../../core/design/palette.dart';
import '../../core/errors/app_exception.dart';
import '../../core/i18n/language.dart';
import '../../core/network/providers.dart';
import '../authentication/auth_controller.dart';

typedef Rows = List<Map<String, dynamic>>;

/// Own records for patients; records of [patientId] for authorised clinicians.
final recordsProvider = FutureProvider.autoDispose.family<Rows, String?>((
  ref,
  patientId,
) async {
  final res = await ref
      .read(apiClientProvider)
      .get(
        '/medical-records',
        query: {if (patientId != null) 'patientId': patientId},
      );
  return Rows.from(res as List);
});

final recordProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
      return Map<String, dynamic>.from(
        await ref.read(apiClientProvider).get('/medical-records/$id') as Map,
      );
    });

(IconData, String, String) _typeInfo(String type) => switch (type) {
  'CLINICAL_NOTE' => (
    Icons.medical_information_rounded,
    'កំណត់ត្រាគ្លីនិក',
    'Clinical note',
  ),
  'PRESCRIPTION' => (Icons.medication_rounded, 'វេជ្ជបញ្ជា', 'Prescription'),
  'TEST_REPORT' => (Icons.science_rounded, 'លទ្ធផលពិនិត្យ', 'Test report'),
  'DISCHARGE_SUMMARY' => (
    Icons.assignment_turned_in_rounded,
    'សង្ខេបពេលចេញពីពេទ្យ',
    'Discharge summary',
  ),
  'DOCUMENT' => (Icons.description_rounded, 'ឯកសារ', 'Document'),
  _ => (Icons.edit_note_rounded, 'កំណត់ចំណាំ', 'Note'),
};

class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key, this.patientId, this.patientName});

  /// When set, a clinician is viewing this patient's records.
  final String? patientId;
  final String? patientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final user = ref.watch(authControllerProvider).user;
    final records = ref.watch(recordsProvider(patientId));
    final clinician = patientId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          clinician
              ? (patientName ?? context.t('អ្នកជំងឺ', 'Patient'))
              : context.t('កំណត់ត្រាសុខភាព', 'Health records'),
        ),
      ),
      floatingActionButton: Tap(
        onTap: () => _addNote(
          context,
          ref,
          clinician: clinician && (user?.can('RECORD_WRITE_CLINICAL') ?? false),
        ),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: p.brand,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                context.t('បន្ថែមកំណត់ត្រា', 'Add note'),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
      body: PageWidth(
        child: records.when(
          loading: () => const SkeletonList(),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(recordsProvider(patientId)),
          ),
          data: (items) => items.isEmpty
              ? EmptyState(
                  art: Art.folder,
                  title: context.t('មិនទាន់មានកំណត់ត្រា', 'No records yet'),
                  message: context.t(
                    'កំណត់ត្រាដែលអ្នក និងគ្រូពេទ្យបន្ថែមនឹងបង្ហាញនៅទីនេះ។',
                    'Notes you and your clinicians add will appear here.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    Gap.sm,
                    Gap.page,
                    110,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = items[i];
                    final (icon, km, en) = _typeInfo(r['recordType'] as String);
                    final clin = r['authorKind'] == 'CLINICIAN';
                    final docs = (r['documents'] as List).length;
                    return Surface(
                      onTap: () => context.push('/record/${r['id']}'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: clin ? p.brandSoft : p.sand,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              icon,
                              color: clin ? p.brandDeep : p.inkSoft,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['title'] as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${context.fmt('d MMM yyyy', DateTime.parse(r['createdAt'] as String).toLocal())}  ·  ${context.t(km, en)}',
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    Pill(
                                      clin
                                          ? context.t(
                                              'ពីគ្រូពេទ្យ',
                                              'From clinician',
                                            )
                                          : context.t('ដោយអ្នក', 'By you'),
                                      tone: clin ? Tone.brand : Tone.neutral,
                                    ),
                                    if (docs > 0)
                                      Pill(
                                        '$docs ${context.t('ឯកសារ', 'files')}',
                                        icon: Icons.attach_file_rounded,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _addNote(
    BuildContext context,
    WidgetRef ref, {
    required bool clinician,
  }) async {
    final title = TextEditingController();
    final body = TextEditingController();
    String type = clinician ? 'CLINICAL_NOTE' : 'HISTORY';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            Gap.page,
            4,
            Gap.page,
            MediaQuery.of(ctx).viewInsets.bottom + Gap.page,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  clinician
                      ? ctx.t('កំណត់ត្រាគ្លីនិកថ្មី', 'New clinical note')
                      : ctx.t('កំណត់ចំណាំថ្មី', 'New note'),
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Notice(
                  clinician
                      ? ctx.t(
                          'កំណត់ត្រានេះនឹងបង្ហាញជាកំណត់ត្រារបស់គ្រូពេទ្យ ហើយមិនអាចកែដោយអ្នកជំងឺបានទេ។',
                          'This is stored as a clinician record and cannot be edited by the patient.',
                        )
                      : ctx.t(
                          'កំណត់ចំណាំរបស់អ្នកត្រូវបានសម្គាល់ថាជាព័ត៌មានដែលអ្នកបញ្ចូលខ្លួនឯង ហើយដាច់ដោយឡែកពីកំណត់ត្រាគ្រូពេទ្យ។',
                          'Your notes are labelled as patient-entered and kept separate from clinician records.',
                        ),
                  tone: Tone.brand,
                ),
                const SizedBox(height: Gap.md),
                if (clinician) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in const [
                        'CLINICAL_NOTE',
                        'PRESCRIPTION',
                        'TEST_REPORT',
                        'DISCHARGE_SUMMARY',
                      ])
                        ChoiceChip(
                          label: Text(ctx.t(_typeInfo(t).$2, _typeInfo(t).$3)),
                          selected: type == t,
                          onSelected: (_) => setSheet(() => type = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                ],
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: ctx.t('ចំណងជើង', 'Title'),
                  ),
                ),
                const SizedBox(height: Gap.md),
                TextField(
                  controller: body,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: ctx.t('ព័ត៌មានលម្អិត', 'Details'),
                    helperText: ctx.t(
                      'គន្លឹះ៖ បន្ទាត់ដូចជា "Allergy: …" ឬ "Medication: …" ជួយឱ្យសង្ខេប AI កាន់តែត្រឹមត្រូវ។',
                      'Tip: lines like "Allergy: …" or "Medication: …" help the AI summary.',
                    ),
                    helperMaxLines: 3,
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
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/medical-records',
            body: {
              if (patientId != null) 'patientId': patientId,
              'recordType': type,
              'title': title.text.trim(),
              'body': body.text.trim(),
            },
          );
      ref.invalidate(recordsProvider(patientId));
    } on AppException catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }
}

class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.recordId});
  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final user = ref.watch(authControllerProvider).user;
    final record = ref.watch(recordProvider(recordId));
    return Scaffold(
      appBar: AppBar(title: Text(context.t('កំណត់ត្រា', 'Record'))),
      body: record.when(
        loading: () => const SkeletonList(count: 2, itemHeight: 160),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(recordProvider(recordId)),
        ),
        data: (r) {
          final (icon, km, en) = _typeInfo(r['recordType'] as String);
          final clin = r['authorKind'] == 'CLINICIAN';
          final lines = ((r['body'] as String?) ?? '')
              .split('\n')
              .where((l) => l.trim().isNotEmpty)
              .toList();
          final docs = List<Map<String, dynamic>>.from(r['documents'] as List);
          final canAttach =
              !clin || (user?.can('RECORD_WRITE_CLINICAL') ?? false);
          return PageWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                0,
                Gap.page,
                Gap.xxl,
              ),
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: clin ? p.brandSoft : p.sand,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: clin ? p.brandDeep : p.inkSoft),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        r['title'] as String,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Pill(context.t(km, en)),
                    Pill(
                      clin
                          ? context.t('ពីគ្រូពេទ្យ', 'From clinician')
                          : context.t('ដោយអ្នកជំងឺ', 'By patient'),
                      tone: clin ? Tone.brand : Tone.neutral,
                    ),
                    Pill(
                      context.fmt(
                        'd MMM yyyy',
                        DateTime.parse(r['createdAt'] as String).toLocal(),
                      ),
                      icon: Icons.calendar_today_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${context.t('កត់ត្រាដោយ', 'Recorded by')} ${r['authorName']}',
                  style: TextStyle(color: p.muted),
                ),
                const SizedBox(height: Gap.xl),
                Surface(
                  child: lines.isEmpty
                      ? Text(
                          context.t('គ្មានព័ត៌មានលម្អិត។', 'No details.'),
                          style: TextStyle(color: p.muted),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final l in lines)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: _line(context, l),
                              ),
                          ],
                        ),
                ),
                if (r['amendsId'] != null) ...[
                  const SizedBox(height: Gap.md),
                  Notice(
                    context.t(
                      'នេះជាកំណែកែតម្រូវនៃកំណត់ត្រាមុន។',
                      'This is an amendment of an earlier record.',
                    ),
                    tone: Tone.amber,
                  ),
                ],
                const SizedBox(height: Gap.xl),
                SectionHeader(
                  context.t('ឯកសារភ្ជាប់', 'Attachments'),
                  count: docs.length,
                ),
                if (docs.isEmpty)
                  Text(
                    context.t('មិនមានឯកសារភ្ជាប់។', 'No attachments.'),
                    style: TextStyle(color: p.muted),
                  )
                else
                  for (final d in docs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Surface(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              (d['contentType'] as String).contains('pdf')
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.image_rounded,
                              color: p.brand,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                d['fileName'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${((d['sizeBytes'] as num) / 1024).round()} KB',
                              style: TextStyle(color: p.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (canAttach) ...[
                  const SizedBox(height: Gap.sm),
                  GhostButton(
                    icon: Icons.attach_file_rounded,
                    label: context.t(
                      'ភ្ជាប់ PDF ឬរូបភាព',
                      'Attach a PDF or image',
                    ),
                    onPressed: () => _attach(context, ref),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// "Label: value" lines render as a quiet label over the value; everything else is plain text.
  Widget _line(BuildContext context, String line) {
    final p = Palette.of(context);
    final idx = line.indexOf(':');
    if (idx > 0 && idx < 28) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              line.substring(0, idx),
              style: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              line.substring(idx + 1).trim(),
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5),
            ),
          ),
        ],
      );
    }
    return Text(line, style: const TextStyle(height: 1.55));
  }

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked.isEmpty) return;
    final file = picked.first;
    try {
      final bytes = await file.readAsBytes();
      await ref
          .read(apiClientProvider)
          .upload(
            '/medical-records/$recordId/documents',
            filename: file.name,
            bytes: bytes,
          );
      ref.invalidate(recordProvider(recordId));
      ref.invalidate(recordsProvider(null));
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('បានបញ្ចូលឯកសារ។', 'File uploaded.')),
          ),
        );
    } on AppException catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }
}
