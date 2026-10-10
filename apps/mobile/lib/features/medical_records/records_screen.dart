import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';
import '../../core/widgets/state_views.dart';

final recordsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  final res = await ref.read(apiClientProvider).get('/medical-records');
  return List<Map<String, dynamic>>.from(res as List);
});

class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsProvider);
    final fmt = DateFormat('d MMM yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Medical records')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNote(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add note'),
      ),
      body: records.when(
        loading: () => const LoadingView(),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(recordsProvider)),
        data: (items) => items.isEmpty
            ? const EmptyView(
                icon: Icons.folder_open_outlined,
                title: 'No records yet',
                message: 'Notes you add and records from your clinicians appear here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = items[i];
                  final clinician = r['authorKind'] == 'CLINICIAN';
                  final docs = List<Map<String, dynamic>>.from(
                    r['documents'] as List,
                  );
                  return Card(
                    child: ListTile(
                      isThreeLine: true,
                      leading: Icon(
                        clinician
                            ? Icons.medical_information_outlined
                            : Icons.edit_note,
                      ),
                      title: Text(r['title'] as String),
                      subtitle: Text(
                        '${clinician ? 'Clinician' : 'You'} · ${fmt.format(DateTime.parse(r['createdAt'] as String).toLocal())}'
                        '${docs.isEmpty ? '' : ' · ${docs.length} file(s)'}\n'
                        '${(r['body'] as String?) ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: clinician
                          ? null
                          : IconButton(
                              tooltip: 'Attach a PDF or image',
                              icon: const Icon(Icons.attach_file),
                              onPressed: () =>
                                  _attach(context, ref, r['id'] as String),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final body = TextEditingController();
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
            const NoticeBanner(
              'Notes you add are labelled as patient-entered and are kept separate from clinician records.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: body,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Details',
                helperText: 'Tip: lines like "Allergy: ..." or "Medication: ..." help the AI summary.',
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
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/medical-records',
            body: {
              'recordType': 'HISTORY',
              'title': title.text.trim(),
              'body': body.text.trim(),
            },
          );
      ref.invalidate(recordsProvider);
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }

  Future<void> _attach(
    BuildContext context,
    WidgetRef ref,
    String recordId,
  ) async {
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
      ref.invalidate(recordsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('File uploaded.')));
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }
}
