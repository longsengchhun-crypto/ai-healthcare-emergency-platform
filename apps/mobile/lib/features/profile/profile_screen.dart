import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/kit.dart';
import '../../core/design/kit_extra.dart';
import '../../core/design/palette.dart';
import '../../core/errors/app_exception.dart';
import '../../core/i18n/language.dart';
import '../../core/network/providers.dart';
import '../../core/widgets/media.dart';
import '../authentication/auth_controller.dart';

final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  return Map<String, dynamic>.from(
    await ref.read(apiClientProvider).get('/patients/me') as Map,
  );
});

final contactsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    final res = await ref
        .read(apiClientProvider)
        .get('/patients/me/emergency-contacts');
    return List<Map<String, dynamic>>.from(res as List);
  },
);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final user = ref.watch(authControllerProvider).user;
    final isPatient = user?.isPatient ?? false;
    final isDoctor = user?.isDoctor ?? false;

    Widget group(List<Widget> rows) => Surface(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(color: p.line),
            rows[i],
          ],
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.lg,
              Gap.page,
              Gap.xxl,
            ),
            children: [
              Row(
                children: [
                  PersonAvatar(name: user?.fullName ?? '?', size: 68),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? '',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(color: p.muted),
                        ),
                        const SizedBox(height: 6),
                        Pill(
                          isDoctor
                              ? context.t('គ្រូពេទ្យ', 'Doctor')
                              : isPatient
                              ? context.t('អ្នកជំងឺ', 'Patient')
                              : context.t('បុគ្គលិក', 'Staff'),
                          tone: Tone.teal,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xl),
              if (isPatient) ...[
                SectionHeader(context.t('សុខភាពរបស់ខ្ញុំ', 'My health')),
                group([
                  InfoRow(
                    icon: Icons.badge_outlined,
                    label: context.t('ព័ត៌មានសុខភាព', 'Health profile'),
                    onTap: () => context.push('/profile/edit'),
                  ),
                  InfoRow(
                    icon: Icons.contacts_outlined,
                    label: context.t(
                      'អ្នកទាក់ទងសង្គ្រោះបន្ទាន់',
                      'Emergency contacts',
                    ),
                    onTap: () => context.push('/profile/contacts'),
                  ),
                  InfoRow(
                    icon: Icons.folder_open_rounded,
                    label: context.t('កំណត់ត្រាសុខភាព', 'Health records'),
                    onTap: () => context.push('/records'),
                  ),
                  InfoRow(
                    icon: Icons.medication_rounded,
                    label: context.t(
                      'ថ្នាំ និងការរំលឹក',
                      'Medicines & reminders',
                    ),
                    onTap: () => context.push('/medications'),
                  ),
                  InfoRow(
                    icon: Icons.auto_awesome_rounded,
                    label: context.t('ជំនួយសុខភាព', 'Health assistant'),
                    onTap: () => context.push('/assistant'),
                  ),
                ]),
                const SizedBox(height: Gap.xl),
              ],
              if (isDoctor) ...[
                SectionHeader(context.t('ការងាររបស់ខ្ញុំ', 'My practice')),
                group([
                  InfoRow(
                    icon: Icons.schedule_rounded,
                    label: context.t('ម៉ោងទទួលអ្នកជំងឺ', 'Working hours'),
                    onTap: () => context.push('/profile/availability'),
                  ),
                ]),
                const SizedBox(height: Gap.xl),
              ],
              SectionHeader(context.t('ការកំណត់', 'Settings')),
              group([
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.tealSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.translate_rounded,
                          size: 19,
                          color: p.tealDeep,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.t('ភាសា', 'Language'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      LanguageToggle(
                        isKhmer: context.isKhmer,
                        onChanged: (c) => languageController.set(c),
                      ),
                    ],
                  ),
                ),
                InfoRow(
                  icon: Icons.notifications_none_rounded,
                  label: context.t('ការជូនដំណឹង', 'Notifications'),
                  onTap: () => context.push('/notifications'),
                ),
                if (isPatient) ...[
                  InfoRow(
                    icon: Icons.sensors_rounded,
                    label: context.t(
                      'ឧបករណ៍ចាប់សញ្ញាសុវត្ថិភាព',
                      'Safety sensors',
                    ),
                    onTap: () => context.push('/profile/sensors'),
                  ),
                  InfoRow(
                    icon: Icons.shield_outlined,
                    label: context.t('ឯកជនភាព និងទិន្នន័យ', 'Privacy & data'),
                    onTap: () => context.push('/profile/privacy'),
                  ),
                ],
              ]),
              const SizedBox(height: Gap.xl),
              GhostButton(
                icon: Icons.logout_rounded,
                label: context.t('ចាកចេញ', 'Sign out'),
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _dob = TextEditingController();
  final _blood = TextEditingController();
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _dob.dispose();
    _blood.dispose();
    _allergies.dispose();
    _conditions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .patch(
            '/patients/me',
            body: {
              if (_dob.text.trim().isNotEmpty) 'dateOfBirth': _dob.text.trim(),
              if (_blood.text.trim().isNotEmpty)
                'bloodGroup': _blood.text.trim().toUpperCase(),
              if (_allergies.text.trim().isNotEmpty)
                'allergies': _allergies.text.trim(),
              if (_conditions.text.trim().isNotEmpty)
                'conditions': _conditions.text.trim(),
            },
          );
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('បានរក្សាទុក។', 'Saved.'))),
        );
        context.pop();
      }
    } on AppException catch (e) {
      final detail = e.fields?.entries
          .map((f) => '${f.key}: ${f.value}')
          .join('\n');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(detail ?? describeError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dob.text) ?? DateTime(1995, 1, 1);
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      _dob.text =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('ព័ត៌មានសុខភាព', 'Health profile'))),
      body: profile.when(
        loading: () => const SkeletonList(count: 4, itemHeight: 64),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (pr) {
          if (!_loaded) {
            _loaded = true;
            _dob.text = (pr['dateOfBirth'] as String?) ?? '';
            _blood.text = (pr['bloodGroup'] as String?) ?? '';
            _allergies.text = (pr['allergies'] as String?) ?? '';
            _conditions.text = (pr['conditions'] as String?) ?? '';
          }
          return PageWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                0,
                Gap.page,
                Gap.xxl,
              ),
              children: [
                Notice(
                  context.t(
                    'ព័ត៌មានទាំងអស់មិនចាំបាច់ត្រូវបំពេញទេ។ វាជួយអ្នកឆ្លើយតប និងគ្រូពេទ្យ ហើយចែករំលែកតាមដែលបានពន្យល់ក្នុង "ឯកជនភាព"។',
                    'Everything here is optional. It helps responders and clinicians and is shared only as explained in Privacy.',
                  ),
                  tone: Tone.teal,
                ),
                const SizedBox(height: Gap.lg),
                TextField(
                  controller: _dob,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: InputDecoration(
                    labelText: context.t('ថ្ងៃខែឆ្នាំកំណើត', 'Date of birth'),
                    suffixIcon: const Icon(Icons.calendar_today_rounded),
                  ),
                ),
                const SizedBox(height: Gap.md),
                TextField(
                  controller: _blood,
                  decoration: InputDecoration(
                    labelText: context.t(
                      'ក្រុមឈាម (មិនចាំបាច់)',
                      'Blood group (optional)',
                    ),
                    hintText: 'O+',
                  ),
                ),
                const SizedBox(height: Gap.md),
                TextField(
                  controller: _allergies,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.t('អាឡែរហ្សី', 'Allergies'),
                  ),
                ),
                const SizedBox(height: Gap.md),
                TextField(
                  controller: _conditions,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.t(
                      'ជំងឺដែលមានស្រាប់',
                      'Existing conditions',
                    ),
                  ),
                ),
                const SizedBox(height: Gap.xl),
                PrimaryButton(
                  label: context.t('រក្សាទុក', 'Save'),
                  busy: _busy,
                  onPressed: _save,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final contacts = ref.watch(contactsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t('អ្នកទាក់ទងសង្គ្រោះបន្ទាន់', 'Emergency contacts'),
        ),
      ),
      floatingActionButton: Tap(
        onTap: () => _add(context, ref),
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
              Icon(Icons.person_add_alt_1_rounded, color: p.paper, size: 20),
              const SizedBox(width: 8),
              Text(
                context.t('បន្ថែមអ្នកទាក់ទង', 'Add contact'),
                style: TextStyle(color: p.paper, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
      body: PageWidth(
        child: contacts.when(
          loading: () => const SkeletonList(itemHeight: 72),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(contactsProvider),
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 110),
            children: [
              Notice(
                context.t(
                  'ប្រសិនបើអ្នកបើកការផ្ញើសារខាងក្រោម អ្នកទាក់ទងនឹងទទួលសារដែលមានឈ្មោះ និងទីតាំងដែលបានចែករំលែករបស់អ្នក នៅពេលអ្នកផ្ញើសំណើសង្គ្រោះបន្ទាន់ពិតប្រាកដ។ ត្រូវការអ្នកផ្តល់សេវា SMS នៅលើម៉ាស៊ីនមេ។',
                  'If you turn on SMS alerts below, contacts get a text with your name and shared location when you send a real (non-practice) emergency request. Needs an SMS provider on the server.',
                ),
                tone: Tone.amber,
              ),
              const SizedBox(height: Gap.md),
              const _SmsConsentTile(),
              const SizedBox(height: Gap.sm),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: EmptyState(
                    art: Art.shield,
                    title: context.t('មិនទាន់មានអ្នកទាក់ទង', 'No contacts yet'),
                    message: context.t(
                      'បន្ថែមមនុស្សដែលអ្នកទុកចិត្ត។',
                      'Add people you trust.',
                    ),
                  ),
                ),
              for (final c in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Surface(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        PersonAvatar(name: c['name'] as String, size: 44),
                        const SizedBox(width: 12),
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
                                style: TextStyle(color: p.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: context.t('លុប', 'Remove'),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: p.muted,
                          ),
                          onPressed: () async {
                            await ref
                                .read(apiClientProvider)
                                .delete(
                                  '/patients/me/emergency-contacts/${c['id']}',
                                );
                            ref.invalidate(contactsProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final relation = TextEditingController();
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
              ctx.t('អ្នកទាក់ទងថ្មី', 'New contact'),
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: ctx.t('ឈ្មោះ', 'Name')),
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: ctx.t('លេខទូរស័ព្ទ (+855…)', 'Phone (+855…)'),
              ),
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: relation,
              decoration: InputDecoration(
                labelText: ctx.t(
                  'ទំនាក់ទំនង (មិនចាំបាច់)',
                  'Relationship (optional)',
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
    if (ok != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/patients/me/emergency-contacts',
            body: {
              'name': name.text.trim(),
              'phone': phone.text.trim(),
              if (relation.text.trim().isNotEmpty)
                'relationship': relation.text.trim(),
            },
          );
      ref.invalidate(contactsProvider);
    } on AppException catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }
}

/// Opt-in for SMS alerts to emergency contacts. Stored server-side as a consent record.
class _SmsConsentTile extends ConsumerStatefulWidget {
  const _SmsConsentTile();

  @override
  ConsumerState<_SmsConsentTile> createState() => _SmsConsentTileState();
}

class _SmsConsentTileState extends ConsumerState<_SmsConsentTile> {
  bool? _value;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/consents') as Map;
      if (mounted)
        setState(() => _value = res['EMERGENCY_CONTACT_SMS'] == true);
    } on AppException {
      if (mounted) setState(() => _value = false);
    }
  }

  Future<void> _set(bool v) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/consents',
            body: {'purpose': 'EMERGENCY_CONTACT_SMS', 'granted': v},
          );
      if (mounted) setState(() => _value = v);
    } on AppException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 4),
    child: SwitchRow(
      title: Text(
        context.t(
          'ផ្ញើសារទៅអ្នកទាក់ទងពេលខ្ញុំស្នើជំនួយ',
          'Text my contacts when I ask for help',
        ),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        context.t(
          'បិទតាមលំនាំដើម មិនប្រើសម្រាប់សំណើសាកល្បងទេ។',
          'Off by default. Never used for practice requests.',
        ),
      ),
      value: _value ?? false,
      onChanged: (_value == null || _busy) ? null : _set,
    ),
  );
}
