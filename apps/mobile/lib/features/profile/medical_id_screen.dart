import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/kit.dart';
import '../../core/design/palette.dart';
import '../../core/i18n/language.dart';
import '../medications/medications_screen.dart';
import 'profile_screen.dart';

/// One screen a paramedic or a nurse can read in ten seconds: who you are, blood group, allergies, conditions,
/// current medicines and who to call. Built only from data the user already entered; nothing is guessed.
class MedicalIdScreen extends ConsumerWidget {
  const MedicalIdScreen({super.key});

  static int? _age(String? dob) {
    final d = dob == null ? null : DateTime.tryParse(dob);
    if (d == null) return null;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final profile = ref.watch(profileProvider);
    final contacts = ref.watch(contactsProvider).value ?? const [];
    final meds = ref.watch(medicationsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(context.t('អត្តសញ្ញាណសុខភាព', 'Medical ID'))),
      body: PageWidth(
        child: profile.when(
          loading: () => const SkeletonList(count: 3, itemHeight: 120),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(profileProvider),
          ),
          data: (pr) {
            final name = (pr['fullName'] as String?) ?? '';
            final age = _age(pr['dateOfBirth'] as String?);
            final blood = (pr['bloodGroup'] as String?)?.trim() ?? '';
            final allergies = (pr['allergies'] as String?)?.trim() ?? '';
            final conditions = (pr['conditions'] as String?)?.trim() ?? '';
            final missing = <String>[
              if (blood.isEmpty) context.t('ក្រុមឈាម', 'blood group'),
              if (allergies.isEmpty) context.t('ជំងឺអាលែហ្ស៊ី', 'allergies'),
              if (contacts.isEmpty)
                context.t('អ្នកទាក់ទងសង្គ្រោះបន្ទាន់', 'an emergency contact'),
            ];

            String asText() {
              final b = StringBuffer()
                ..writeln('MEDICAL ID — $name${age == null ? '' : ', $age'}')
                ..writeln('Blood group: ${blood.isEmpty ? 'not set' : blood}')
                ..writeln(
                  'Allergies: ${allergies.isEmpty ? 'none recorded' : allergies}',
                )
                ..writeln(
                  'Conditions: ${conditions.isEmpty ? 'none recorded' : conditions}',
                )
                ..writeln(
                  'Medicines: ${meds.isEmpty ? 'none recorded' : meds.map((m) => [m['name'], m['dosage']].where((x) => x != null).join(' ')).join('; ')}',
                );
              for (final c in contacts) {
                b.writeln(
                  'Contact: ${c['name']}${c['relationship'] == null ? '' : ' (${c['relationship']})'} ${c['phone']}',
                );
              }
              return b.toString().trim();
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.sm,
                Gap.page,
                Gap.xxl,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(Gap.lg),
                  decoration: BoxDecoration(
                    color: p.brand,
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            if (age != null)
                              Text(
                                context.t('អាយុ $age ឆ្នាំ', 'Age $age'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 76,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              blood.isEmpty ? '?' : blood,
                              style: TextStyle(
                                color: blood.isEmpty ? p.muted : p.red,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              context.t('ក្រុមឈាម', 'Blood'),
                              style: TextStyle(color: p.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: Gap.md),
                  Notice(
                    context.t(
                      'ព័ត៌មានដែលនៅខ្វះ៖ ${missing.join(', ')}។ ព័ត៌មានពេញលេញជួយអ្នកថែទាំរហ័ស។',
                      'Still missing: ${missing.join(', ')}. A complete card helps whoever treats you.',
                    ),
                    tone: Tone.amber,
                  ),
                ],
                const SizedBox(height: Gap.xl),
                _Block(
                  icon: Icons.warning_amber_rounded,
                  title: context.t('ជំងឺអាលែហ្ស៊ី', 'Allergies'),
                  body: allergies,
                  emptyText: context.t('មិនទាន់បានកត់ត្រា', 'None recorded'),
                  tone: allergies.isEmpty ? null : p.red,
                  onEdit: () => context.push('/profile/edit'),
                ),
                const SizedBox(height: Gap.md),
                _Block(
                  icon: Icons.healing_rounded,
                  title: context.t('ជំងឺប្រចាំកាយ', 'Conditions'),
                  body: conditions,
                  emptyText: context.t('មិនទាន់បានកត់ត្រា', 'None recorded'),
                  onEdit: () => context.push('/profile/edit'),
                ),
                const SizedBox(height: Gap.md),
                _Block(
                  icon: Icons.medication_rounded,
                  title: context.t('ថ្នាំកំពុងប្រើ', 'Current medicines'),
                  body: meds
                      .map(
                        (m) => [
                          m['name'],
                          m['dosage'],
                        ].where((x) => x != null).join(' · '),
                      )
                      .join('\n'),
                  emptyText: context.t('មិនទាន់បានកត់ត្រា', 'None recorded'),
                  onEdit: () => context.push('/medications'),
                ),
                const SizedBox(height: Gap.xl),
                SectionHeader(
                  context.t('អ្នកត្រូវទាក់ទង', 'Who to call'),
                  action: context.t('កែប្រែ', 'Edit'),
                  onAction: () => context.push('/profile/contacts'),
                ),
                if (contacts.isEmpty)
                  Surface(
                    onTap: () => context.push('/profile/contacts'),
                    child: Row(
                      children: [
                        Icon(Icons.person_add_alt_1_rounded, color: p.brand),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.t(
                              'បន្ថែមអ្នកទាក់ទងសង្គ្រោះបន្ទាន់',
                              'Add an emergency contact',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final c in contacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Surface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${c['relationship'] ?? ''}  ${c['phone']}',
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filled(
                            tooltip: context.t('ហៅទូរស័ព្ទ', 'Call'),
                            style: IconButton.styleFrom(
                              backgroundColor: p.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => launchUrl(
                              Uri(scheme: 'tel', path: c['phone'] as String),
                            ),
                            icon: const Icon(Icons.call_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: Gap.lg),
                PrimaryButton(
                  icon: Icons.copy_rounded,
                  label: context.t('ចម្លងជាអត្ថបទ', 'Copy as text'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: asText()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.t(
                              'បានចម្លង។ អាចបិទភ្ជាប់ទៅក្នុងសារ។',
                              'Copied. You can paste it into a message.',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: Gap.md),
                Notice(
                  context.t(
                    'កាតនេះបង្ហាញតែចំពោះអ្នកក្នុងគណនីរបស់អ្នក។ ក្នុងគ្រាអាសន្ន សូមបង្ហាញវាដល់អ្នកព្យាបាលដោយខ្លួនឯង ឬចម្លងផ្ញើ។',
                    'This card is shown only to you inside your account. In an emergency, show it to whoever treats you, or copy and send it.',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.title,
    required this.body,
    required this.emptyText,
    required this.onEdit,
    this.tone,
  });
  final IconData icon;
  final String title;
  final String body;
  final String emptyText;
  final VoidCallback onEdit;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final empty = body.trim().isEmpty;
    return Surface(
      onTap: onEdit,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone ?? p.brandDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  empty ? emptyText : body,
                  style: TextStyle(
                    fontSize: 16.5,
                    height: 1.45,
                    fontWeight: empty ? FontWeight.w500 : FontWeight.w700,
                    color: empty ? p.muted : (tone ?? p.ink),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, size: 18, color: p.muted),
        ],
      ),
    );
  }
}
