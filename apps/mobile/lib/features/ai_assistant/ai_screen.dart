import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';

class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Health assistant'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Symptoms'),
            Tab(text: 'Summary'),
            Tab(text: 'Document'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [_TriageTab(), _SummaryTab(), _ExtractTab()],
      ),
    ),
  );
}

class _TriageTab extends ConsumerStatefulWidget {
  const _TriageTab();

  @override
  ConsumerState<_TriageTab> createState() => _TriageTabState();
}

class _TriageTabState extends ConsumerState<_TriageTab> {
  final _text = TextEditingController();
  Map<String, dynamic>? _result;
  Object? _error;
  bool _busy = false;

  Future<void> _run() async {
    if (_text.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(apiClientProvider)
          .post('/ai/triage', body: {'symptoms': _text.text.trim()});
      setState(() => _result = Map<String, dynamic>.from(res as Map));
    } on AppException catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgency = _result?['urgency'] as String?;
    final emergency = urgency == 'EMERGENCY';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const NoticeBanner(
          'Preliminary information only. This cannot diagnose a condition. If you think this '
          'is an emergency, use the Emergency tab or call emergency services immediately.',
          warning: true,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Describe your symptoms',
            hintText: 'What is happening, since when, and how severe?',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _run,
          child: Text(_busy ? 'Checking…' : 'Get guidance'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          ErrorView(error: _error!, onRetry: _run),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          Card(
            color: emergency
                ? AppColors.emergency.withValues(alpha: 0.08)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    switch (urgency) {
                      'EMERGENCY' => 'Possible emergency',
                      'URGENT' => 'See a clinician today',
                      'UNCERTAIN' => 'More detail needed',
                      _ => 'Consider seeing a clinician',
                    },
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: emergency ? AppColors.emergency : null,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_result!['guidance'] as String),
                  if ((_result!['followUpQuestions'] as List).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Questions to think about:'),
                    for (final q in _result!['followUpQuestions'] as List)
                      Text('• $q'),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    _result!['disclaimer'] as String,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (emergency) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.go('/emergency'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emergency,
                      ),
                      icon: const Icon(Icons.emergency),
                      label: const Text('Go to Emergency'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryTab extends ConsumerStatefulWidget {
  const _SummaryTab();

  @override
  ConsumerState<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<_SummaryTab> {
  Map<String, dynamic>? _result;
  Object? _error;
  bool _busy = false;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(apiClientProvider)
          .post('/ai/medical-summary', body: {});
      setState(() => _result = Map<String, dynamic>.from(res as Map));
    } on AppException catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _list(String title, List<dynamic> items) => items.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              for (final i in items) Text('• $i'),
            ],
          ),
        );

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const NoticeBanner(
          'Summarises only what appears in your records. It may be incomplete, and it is not medical advice.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _run,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_busy ? 'Summarising…' : 'Summarise my records'),
        ),
        if (_error != null) ErrorView(error: _error!, onRetry: _run),
        if (r != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['summary'] as String),
                  _list('Recorded conditions', r['recordedConditions'] as List),
                  _list('Medication entries', r['medications'] as List),
                  _list('Allergy entries', r['allergies'] as List),
                  _list('Dates mentioned', r['datesMentioned'] as List),
                  _list(
                    'Discuss with your clinician',
                    r['discussWithClinician'] as List,
                  ),
                  _list('Sources', [
                    for (final s in r['sources'] as List) (s as Map)['title'],
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    '${r['notice']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExtractTab extends ConsumerStatefulWidget {
  const _ExtractTab();

  @override
  ConsumerState<_ExtractTab> createState() => _ExtractTabState();
}

class _ExtractTabState extends ConsumerState<_ExtractTab> {
  Map<String, dynamic>? _result;
  Object? _error;
  bool _busy = false;

  Future<void> _pick() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (picked.isEmpty) return;
    final file = picked.first;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final res = await ref
          .read(apiClientProvider)
          .upload('/ai/document-extraction', filename: file.name, bytes: bytes);
      setState(() => _result = Map<String, dynamic>.from(res as Map));
    } on AppException catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = List<Map<String, dynamic>>.from(
      (_result?['fields'] as List?) ?? const [],
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const NoticeBanner(
          'Demonstration extractor for plain-text documents only. Extracted values are not clinically '
          'validated. Scanned PDFs and images need an OCR provider that is not configured.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.upload_file),
          label: Text(_busy ? 'Reading…' : 'Choose a .txt document'),
        ),
        if (_error != null) ErrorView(error: _error!, onRetry: _pick),
        if (_result != null) ...[
          const SizedBox(height: 16),
          Text(
            'Document type: ${_result!['documentType']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (fields.isEmpty)
            const Text('No structured fields were recognised.'),
          for (final f in fields)
            Card(
              child: ListTile(
                title: Text('${f['name']}: ${f['value']}'),
                subtitle: Text('Evidence: ${f['evidence']}'),
                trailing: Text('${((f['confidence'] as num) * 100).round()}%'),
              ),
            ),
          Text(
            '${_result!['notice']}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
