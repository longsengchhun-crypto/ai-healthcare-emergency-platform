import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/kit.dart';
import '../../core/design/kit_extra.dart';
import '../../core/design/palette.dart';
import '../../core/errors/app_exception.dart';
import '../../core/i18n/language.dart';
import '../../core/network/providers.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('ជំនួយសុខភាព', 'Health assistant'))),
      body: PageWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
              child: Segmented(
                labels: [
                  context.t('រោគសញ្ញា', 'Symptoms'),
                  context.t('សង្ខេប', 'Summary'),
                  context.t('ឯកសារ', 'Document'),
                ],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [_TriageTab(), _SummaryTab(), _ExtractTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    final p = Palette.of(context);
    final urgency = _result?['urgency'] as String?;
    final emergency = urgency == 'EMERGENCY';
    final heading = switch (urgency) {
      'EMERGENCY' => context.t('អាចជាភាពអាសន្ន', 'This may be an emergency'),
      'URGENT' => context.t('គួរជួបគ្រូពេទ្យថ្ងៃនេះ', 'See a clinician today'),
      'UNCERTAIN' => context.t('ត្រូវការព័ត៌មានបន្ថែម', 'More detail needed'),
      _ => context.t('គួរពិចារណាជួបគ្រូពេទ្យ', 'Consider seeing a clinician'),
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xxl),
      children: [
        Notice(
          context.t(
            'នេះគ្រាន់តែជាព័ត៌មានបឋម មិនមែនការធ្វើរោគវិនិច្ឆ័យទេ។ ប្រសិនបើអ្នកគិតថាជាភាពអាសន្ន សូមប្រើផ្នែកសង្គ្រោះបន្ទាន់ ឬហៅលេខសង្គ្រោះបន្ទាន់ភ្លាមៗ។',
            'Preliminary information only, not a diagnosis. If you think this is an emergency, use Emergency or call your local number immediately.',
          ),
          tone: Tone.amber,
        ),
        const SizedBox(height: Gap.lg),
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: 6,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: context.t(
              'ពិពណ៌នារោគសញ្ញារបស់អ្នក',
              'Describe your symptoms',
            ),
            hintText: context.t(
              'កើតអ្វី តាំងពីពេលណា ហើយធ្ងន់ប៉ុណ្ណា?',
              'What is happening, since when, and how severe?',
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        PrimaryButton(
          label: context.t('ទទួលការណែនាំ', 'Get guidance'),
          busy: _busy,
          onPressed: _run,
        ),
        if (_error != null) ErrorState(error: _error!, onRetry: _run),
        if (_result != null) ...[
          const SizedBox(height: Gap.xl),
          Surface(
            color: emergency ? p.redSoft : p.surface,
            borderColor: emergency ? p.red.withValues(alpha: .4) : p.line,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: emergency ? p.red : p.ink,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _result!['guidance'] as String,
                  style: const TextStyle(height: 1.55),
                ),
                if ((_result!['followUpQuestions'] as List).isNotEmpty) ...[
                  const SizedBox(height: Gap.md),
                  Text(
                    context.t('សំណួរសម្រាប់ពិចារណា', 'Things to think about'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  for (final q in _result!['followUpQuestions'] as List)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• $q'),
                    ),
                ],
                const SizedBox(height: Gap.md),
                Text(
                  _result!['disclaimer'] as String,
                  style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.5),
                ),
                if (emergency) ...[
                  const SizedBox(height: Gap.lg),
                  PrimaryButton(
                    danger: true,
                    icon: Icons.emergency_rounded,
                    label: context.t(
                      'ទៅផ្នែកសង្គ្រោះបន្ទាន់',
                      'Go to Emergency',
                    ),
                    onPressed: () => context.go('/emergency'),
                  ),
                ],
              ],
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

  Widget _group(
    BuildContext context,
    String title,
    List<dynamic> items,
    IconData icon,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: p.teal),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 3),
              child: Text('$i', style: const TextStyle(height: 1.45)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final r = _result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xxl),
      children: [
        Notice(
          context.t(
            'សង្ខេបតែអ្វីដែលមានក្នុងកំណត់ត្រារបស់អ្នក។ វាអាចមិនពេញលេញ ហើយមិនមែនជាដំបូន្មានវេជ្ជសាស្ត្រទេ។',
            'Summarises only what appears in your records. It may be incomplete and is not medical advice.',
          ),
          tone: Tone.teal,
        ),
        const SizedBox(height: Gap.lg),
        PrimaryButton(
          icon: Icons.auto_awesome_rounded,
          label: context.t('សង្ខេបកំណត់ត្រារបស់ខ្ញុំ', 'Summarise my records'),
          busy: _busy,
          onPressed: _run,
        ),
        if (_error != null) ErrorState(error: _error!, onRetry: _run),
        if (r != null) ...[
          const SizedBox(height: Gap.xl),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['summary'] as String,
                  style: const TextStyle(height: 1.55),
                ),
                _group(
                  context,
                  context.t('ជំងឺដែលបានកត់ត្រា', 'Recorded conditions'),
                  r['recordedConditions'] as List,
                  Icons.healing_rounded,
                ),
                _group(
                  context,
                  context.t('ថ្នាំ', 'Medicines'),
                  r['medications'] as List,
                  Icons.medication_rounded,
                ),
                _group(
                  context,
                  context.t('អាឡែរហ្សី', 'Allergies'),
                  r['allergies'] as List,
                  Icons.warning_amber_rounded,
                ),
                _group(
                  context,
                  context.t('កាលបរិច្ឆេទ', 'Dates mentioned'),
                  r['datesMentioned'] as List,
                  Icons.event_rounded,
                ),
                _group(
                  context,
                  context.t(
                    'ពិភាក្សាជាមួយគ្រូពេទ្យ',
                    'Discuss with your clinician',
                  ),
                  r['discussWithClinician'] as List,
                  Icons.forum_rounded,
                ),
                _group(context, context.t('ប្រភព', 'Sources'), [
                  for (final s in r['sources'] as List) (s as Map)['title'],
                ], Icons.link_rounded),
                const SizedBox(height: Gap.lg),
                Text(
                  '${r['notice']}',
                  style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.5),
                ),
              ],
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
    final p = Palette.of(context);
    final fields = List<Map<String, dynamic>>.from(
      (_result?['fields'] as List?) ?? const [],
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xxl),
      children: [
        Notice(
          context.t(
            'ឧបករណ៍ពិសោធន៍សម្រាប់ឯកសារអក្សរធម្មតា (.txt) ប៉ុណ្ណោះ។ តម្លៃដែលទាញចេញមិនទាន់ត្រូវបានផ្ទៀងផ្ទាត់ជាវេជ្ជសាស្ត្រទេ។ PDF និងរូបភាពត្រូវការ OCR ដែលមិនទាន់បានកំណត់។',
            'Demonstration extractor for plain-text (.txt) files only. Values are not clinically validated. PDFs and images need an OCR provider that is not configured.',
          ),
          tone: Tone.amber,
        ),
        const SizedBox(height: Gap.lg),
        PrimaryButton(
          icon: Icons.upload_file_rounded,
          label: context.t('ជ្រើសរើសឯកសារ .txt', 'Choose a .txt document'),
          busy: _busy,
          onPressed: _pick,
        ),
        if (_error != null) ErrorState(error: _error!, onRetry: _pick),
        if (_result != null) ...[
          const SizedBox(height: Gap.xl),
          SectionHeader(
            '${context.t('ប្រភេទឯកសារ', 'Document type')}: ${_result!['documentType']}',
          ),
          if (fields.isEmpty)
            Text(
              context.t(
                'មិនបានស្គាល់វាលរចនាសម្ព័ន្ធទេ។',
                'No structured fields were recognised.',
              ),
              style: TextStyle(color: p.muted),
            ),
          for (final f in fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Surface(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${f['name']}',
                            style: TextStyle(color: p.muted, fontSize: 12.5),
                          ),
                          Text(
                            '${f['value']}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '“${f['evidence']}”',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    Pill(
                      '${((f['confidence'] as num) * 100).round()}%',
                      tone: Tone.teal,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Gap.sm),
          Text(
            '${_result!['notice']}',
            style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.5),
          ),
        ],
      ],
    );
  }
}
