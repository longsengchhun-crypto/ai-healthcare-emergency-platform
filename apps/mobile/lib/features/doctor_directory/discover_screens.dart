import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/cached_get.dart';
import '../../core/design/kit.dart';
import '../../core/design/kit_extra.dart';
import '../../core/design/palette.dart';
import '../../core/errors/app_exception.dart';
import '../../core/i18n/language.dart';
import '../../core/network/providers.dart';
import '../../core/widgets/media.dart';
import '../appointments/appointments_screen.dart';
import '../location/location_service.dart';

typedef Rows = List<Map<String, dynamic>>;

final doctorsProvider = FutureProvider.autoDispose
    .family<CachedResult<Rows>, String>((ref, q) async {
      final api = ref.read(apiClientProvider);
      final r = await cachedGet(
        'doctors.$q',
        () => api.get('/doctors', query: {'q': q, 'size': 50}),
      );
      return CachedResult(
        Rows.from((r.data as Map)['items'] as List),
        fromCache: r.fromCache,
        savedAt: r.savedAt,
      );
    });

final hospitalsProvider = FutureProvider.autoDispose
    .family<CachedResult<Rows>, String>((ref, q) async {
      final api = ref.read(apiClientProvider);
      final loc = await DeviceLocationProvider().current(
        requestPermission: false,
      );
      final r = await cachedGet(
        'hospitals.$q',
        () => api.get(
          '/hospitals',
          query: {
            'q': q,
            'size': 30,
            if (loc.hasFix) 'lat': loc.latitude,
            if (loc.hasFix) 'lon': loc.longitude,
          },
        ),
      );
      return CachedResult(
        Rows.from((r.data as Map)['items'] as List),
        fromCache: r.fromCache,
        savedAt: r.savedAt,
      );
    });

final _hospitalDoctorsProvider = FutureProvider.autoDispose
    .family<Rows, String>((ref, id) async {
      final res = await ref
          .read(apiClientProvider)
          .get('/doctors', query: {'hospitalId': id, 'size': 20});
      return Rows.from((res as Map)['items'] as List);
    });

String specialtyOf(BuildContext context, Map<String, dynamic> d) {
  final km = d['specialtyKm'] as String?;
  final en = d['specialty'] as String;
  return context.isKhmer && km != null && km.isNotEmpty ? km : en;
}

String doctorTitle(BuildContext context, Map<String, dynamic> d) =>
    context.isKhmer
    ? d['fullName'] as String
    : ((d['nameLatin'] as String?) ?? d['fullName'] as String);

String? doctorSubtitle(BuildContext context, Map<String, dynamic> d) =>
    context.isKhmer ? d['nameLatin'] as String? : d['fullName'] as String?;

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.md),
    child: Notice(
      context.t(
        'អ្នកកំពុងមើលទិន្នន័យដែលបានរក្សាទុក ព្រោះគ្មានអ៊ីនធឺណិត។',
        'You are offline. Showing the last saved list.',
      ),
      tone: Tone.amber,
      icon: Icons.cloud_off_rounded,
    ),
  );
}

// ------------------------------------------------------------------ list row

class DoctorRow extends StatelessWidget {
  const DoctorRow({super.key, required this.doctor});
  final Map<String, dynamic> doctor;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final d = doctor;
    final sub = doctorSubtitle(context, d);
    return Surface(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/doctor/${d['id']}'),
      child: Row(
        children: [
          Hero(
            tag: 'doctor-${d['id']}',
            child: Portrait(
              name: d['fullName'] as String,
              photoUrl: d['photoUrl'] as String?,
              width: 88,
              height: 104,
              radius: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorTitle(context, d),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    height: 1.4,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.muted, fontSize: 13),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(specialtyOf(context, d), tone: Tone.blue),
                    if (d['yearsExperience'] != null)
                      Pill(
                        context.t(
                          '${d['yearsExperience']} ឆ្នាំ',
                          '${d['yearsExperience']} yrs',
                        ),
                        icon: Icons.workspace_premium_outlined,
                      ),
                  ],
                ),
                if (d['hospitalName'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.place_outlined, size: 14, color: p.muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            d['hospitalName'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.muted, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (d['demo'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Pill(context.t('គំរូ', 'Sample'), tone: Tone.amber),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Portrait card for horizontal carousels.
class DoctorTile extends StatelessWidget {
  const DoctorTile({super.key, required this.doctor});
  final Map<String, dynamic> doctor;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Tap(
      onTap: () => context.push('/doctor/${doctor['id']}'),
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Portrait(
              name: doctor['fullName'] as String,
              photoUrl: doctor['photoUrl'] as String?,
              width: 132,
              height: 150,
              radius: 22,
            ),
            const SizedBox(height: 8),
            Text(
              doctorTitle(context, doctor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, color: p.ink),
            ),
            Text(
              specialtyOf(context, doctor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ discover

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, this.initialSpecialty});

  /// English specialty name (as stored on the doctor) to pre-select, e.g. from a home-screen shortcut.
  final String? initialSpecialty;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _controller = TextEditingController();
  String _query = '';
  int _tab = 0;
  late String? _specialty = widget.initialSpecialty;

  @override
  void didUpdateWidget(covariant DiscoverScreen old) {
    super.didUpdateWidget(old);
    if (old.initialSpecialty != widget.initialSpecialty) {
      setState(() => _specialty = widget.initialSpecialty);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: SafeArea(
        child: PageWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.lg,
                  Gap.page,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('ស្វែងរកការថែទាំ', 'Find care'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: Gap.lg),
                    TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: context.t(
                          'ឈ្មោះគ្រូពេទ្យ ឬឯកទេស',
                          'Doctor name or specialty',
                        ),
                        prefixIcon: Icon(Icons.search_rounded, color: p.muted),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: context.t('សម្អាត', 'Clear'),
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                      onSubmitted: (v) => setState(() => _query = v.trim()),
                    ),
                    const SizedBox(height: Gap.md),
                    Segmented(
                      labels: [
                        context.t('គ្រូពេទ្យ', 'Doctors'),
                        context.t('មន្ទីរពេទ្យ', 'Hospitals'),
                      ],
                      index: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _tab == 0
                      ? _DoctorList(
                          key: const ValueKey('d'),
                          query: _query,
                          specialty: _specialty,
                          onSpecialty: (s) => setState(() => _specialty = s),
                        )
                      : _HospitalList(key: const ValueKey('h'), query: _query),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorList extends ConsumerWidget {
  const _DoctorList({
    super.key,
    required this.query,
    required this.specialty,
    required this.onSpecialty,
  });
  final String query;
  final String? specialty;
  final ValueChanged<String?> onSpecialty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(doctorsProvider(query));
    return doctors.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(doctorsProvider(query)),
      ),
      data: (res) {
        final all = res.data;
        final specialties = {for (final d in all) d['specialty'] as String: d}
            .values
            .toList();
        final items = specialty == null
            ? all
            : all.where((d) => d['specialty'] == specialty).toList();
        if (all.isEmpty) {
          return EmptyState(
            art: Art.search,
            title: context.t('រកមិនឃើញគ្រូពេទ្យ', 'No doctors found'),
            message: context.t(
              'សូមសាកល្បងឈ្មោះ ឬឯកទេសផ្សេង។',
              'Try a different name or specialty.',
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.md,
            Gap.page,
            Gap.xl,
          ),
          children: [
            if (res.fromCache) const OfflineBanner(),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: context.t('ទាំងអស់', 'All'),
                    selected: specialty == null,
                    onTap: () => onSpecialty(null),
                  ),
                  for (final d in specialties)
                    _FilterChip(
                      label: specialtyOf(context, d),
                      selected: specialty == d['specialty'],
                      onTap: () => onSpecialty(d['specialty'] as String),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.md),
            for (final d in items) ...[
              DoctorRow(doctor: d),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? p.brand : p.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: selected ? p.brand : p.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : p.inkSoft,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _HospitalList extends ConsumerWidget {
  const _HospitalList({super.key, required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final hospitals = ref.watch(hospitalsProvider(query));
    return hospitals.when(
      loading: () => const SkeletonList(itemHeight: 190),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(hospitalsProvider(query)),
      ),
      data: (res) {
        final items = res.data;
        if (items.isEmpty) {
          return EmptyState(
            art: Art.search,
            title: context.t('រកមិនឃើញមន្ទីរពេទ្យ', 'No hospitals found'),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.md,
            Gap.page,
            Gap.xl,
          ),
          children: [
            if (res.fromCache) const OfflineBanner(),
            for (final h in items) ...[
              Tap(
                onTap: () => context.push('/hospital/${h['id']}'),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: p.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BannerImage(
                        photoUrl: h['photoUrl'] as String?,
                        height: 124,
                        radius: 0,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.isKhmer
                                  ? h['name'] as String
                                  : ((h['nameLatin'] as String?) ??
                                        h['name'] as String),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16.5,
                                color: p.ink,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (h['city'] != null)
                                  Pill(
                                    h['city'] as String,
                                    icon: Icons.place_outlined,
                                  ),
                                if (h['distanceKm'] != null)
                                  Pill(
                                    '${h['distanceKm']} km',
                                    tone: Tone.blue,
                                    icon: Icons.near_me_outlined,
                                  ),
                                if (h['openingHours'] != null)
                                  Pill(
                                    h['openingHours'] as String,
                                    tone: Tone.brand,
                                    icon: Icons.schedule_rounded,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ doctor detail

final _doctorProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
      return Map<String, dynamic>.from(
        await ref.read(apiClientProvider).get('/doctors/$id') as Map,
      );
    });

final _slotsProvider = FutureProvider.autoDispose
    .family<List<DateTime>, ({String doctorId, String date})>((ref, a) async {
      final res = await ref
          .read(apiClientProvider)
          .get('/doctors/${a.doctorId}/slots', query: {'date': a.date});
      return [
        for (final s in res as List)
          DateTime.parse((s as Map)['startsAt'] as String).toLocal(),
      ];
    });

class DoctorDetailScreen extends ConsumerStatefulWidget {
  const DoctorDetailScreen({super.key, required this.doctorId});
  final String doctorId;

  @override
  ConsumerState<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends ConsumerState<DoctorDetailScreen> {
  late DateTime _day = DateTime.now().add(const Duration(days: 1));
  DateTime? _selected;
  bool _booking = false;

  String get _dateKey =>
      '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

  Future<void> _book() async {
    final slot = _selected;
    if (slot == null) return;
    final reason = TextEditingController();
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
              ctx.t('បញ្ជាក់ការស្នើសុំ', 'Confirm your request'),
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${ctx.fmt('EEEE d MMMM', slot)} · ${ctx.fmt('HH:mm', slot)}',
              style: TextStyle(color: Palette.of(ctx).muted),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: reason,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: ctx.t('មូលហេតុ (មិនចាំបាច់)', 'Reason (optional)'),
                helperText: ctx.t(
                  'សូមកុំសរសេរព័ត៌មានវេជ្ជសាស្ត្រលម្អិត។',
                  'Please avoid detailed medical information.',
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
            PrimaryButton(
              label: ctx.t('ផ្ញើសំណើ', 'Send request'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _booking = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/appointments',
            body: {
              'doctorId': widget.doctorId,
              'startsAt': slot.toUtc().toIso8601String(),
              if (reason.text.trim().isNotEmpty) 'reason': reason.text.trim(),
            },
          );
      ref.invalidate(appointmentsProvider);
      ref.invalidate(_slotsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'បានផ្ញើសំណើ។ គ្រូពេទ្យនឹងបញ្ជាក់ក្នុងពេលឆាប់ៗ។',
                'Request sent. The doctor will confirm soon.',
              ),
            ),
          ),
        );
        context.go('/appointments');
      }
    } on AppException catch (e) {
      ref.invalidate(_slotsProvider);
      setState(() => _selected = null);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final doctor = ref.watch(_doctorProvider(widget.doctorId));
    final slots = ref.watch(
      _slotsProvider((doctorId: widget.doctorId, date: _dateKey)),
    );
    return Scaffold(
      body: doctor.when(
        loading: () => const SkeletonList(count: 3, itemHeight: 140),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(_doctorProvider(widget.doctorId)),
        ),
        data: (d) => Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 330,
                  pinned: true,
                  backgroundColor: p.surface,
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Tap(
                      onTap: () => context.pop(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.surface.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_back_rounded, color: p.ink),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Hero(
                      tag: 'doctor-${d['id']}',
                      child: Builder(
                        builder: (context) {
                          final url = mediaUrl(d['photoUrl'] as String?);
                          final fallback = Container(
                            color: p.brandSoft,
                            alignment: Alignment.center,
                            child: Text(
                              initialsOf(d['fullName'] as String),
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w700,
                                color: p.brand,
                              ),
                            ),
                          );
                          return url == null
                              ? fallback
                              : Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                  errorBuilder: (_, _, _) => fallback,
                                  loadingBuilder: (_, child, progress) =>
                                      progress == null ? child : fallback,
                                );
                        },
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: PageWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        Gap.lg,
                        Gap.page,
                        120,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctorTitle(context, d),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (doctorSubtitle(context, d) != null)
                            Text(
                              doctorSubtitle(context, d)!,
                              style: TextStyle(color: p.muted),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            specialtyOf(context, d),
                            style: TextStyle(
                              color: p.brandDeep,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: Gap.lg),
                          Surface(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Stat(
                                      value: '${d['yearsExperience'] ?? '—'}',
                                      caption: context.t(
                                        'ឆ្នាំបទពិសោធន៍',
                                        'Years',
                                      ),
                                    ),
                                  ),
                                  VerticalDivider(color: p.line, width: 1),
                                  Expanded(
                                    child: Stat(
                                      value:
                                          (d['languages'] as String?)
                                              ?.split(',')
                                              .length
                                              .toString() ??
                                          '—',
                                      caption: context.t('ភាសា', 'Languages'),
                                    ),
                                  ),
                                  VerticalDivider(color: p.line, width: 1),
                                  Expanded(
                                    child: Stat(
                                      value:
                                          d['verificationStatus'] == 'VERIFIED'
                                          ? context.t(
                                              'បានផ្ទៀងផ្ទាត់',
                                              'Verified',
                                            )
                                          : context.t('គំរូ', 'Sample'),
                                      caption: context.t('ស្ថានភាព', 'Status'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (d['demo'] == true) ...[
                            const SizedBox(height: Gap.md),
                            Notice(
                              context.t(
                                'នេះជាប្រវត្តិរូបគំរូសម្រាប់បង្ហាញកម្មវិធី មិនមែនជាគ្រូពេទ្យពិតទេ។',
                                'Sample profile for demonstration. Not a real doctor and not verified.',
                              ),
                              tone: Tone.amber,
                            ),
                          ],
                          const SizedBox(height: Gap.xl),
                          if (d['hospitalName'] != null)
                            InfoRow(
                              icon: Icons.local_hospital_outlined,
                              label: context.t('ទីតាំងធ្វើការ', 'Works at'),
                              value: d['hospitalName'] as String,
                              onTap: d['hospitalId'] == null
                                  ? null
                                  : () => context.push(
                                      '/hospital/${d['hospitalId']}',
                                    ),
                            ),
                          if (d['languages'] != null)
                            InfoRow(
                              icon: Icons.translate_rounded,
                              label: context.t('ភាសា', 'Languages'),
                              value: d['languages'] as String,
                            ),
                          const SizedBox(height: Gap.lg),
                          SectionHeader(context.t('អំពីគ្រូពេទ្យ', 'About')),
                          Text(
                            context.isKhmer
                                ? (d['bio'] as String? ?? '')
                                : ((d['bioEn'] as String?) ??
                                      (d['bio'] as String? ?? '')),
                            style: TextStyle(height: 1.6, color: p.inkSoft),
                          ),
                          const SizedBox(height: Gap.xl),
                          SectionHeader(
                            context.t('ជ្រើសរើសពេលណាត់ជួប', 'Pick a time'),
                          ),
                          SizedBox(
                            height: 74,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 14,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final day = DateTime.now().add(
                                  Duration(days: i + 1),
                                );
                                final sel =
                                    day.day == _day.day &&
                                    day.month == _day.month;
                                return Tap(
                                  onTap: () => setState(() {
                                    _day = day;
                                    _selected = null;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 58,
                                    decoration: BoxDecoration(
                                      color: sel ? p.brand : p.surface,
                                      borderRadius: BorderRadius.circular(
                                        Radii.md,
                                      ),
                                      border: Border.all(
                                        color: sel ? p.brand : p.line,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          context.fmt('EEE', day),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: sel
                                                ? Colors.white.withValues(alpha: .8)
                                                : p.muted,
                                          ),
                                        ),
                                        Text(
                                          '${day.day}',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: sel ? Colors.white : p.ink,
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
                          slots.when(
                            loading: () => Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < 6; i++)
                                  const Skeleton(
                                    width: 82,
                                    height: 46,
                                    radius: 14,
                                  ),
                              ],
                            ),
                            error: (e, _) => ErrorState(
                              error: e,
                              onRetry: () => ref.invalidate(
                                _slotsProvider((
                                  doctorId: widget.doctorId,
                                  date: _dateKey,
                                )),
                              ),
                            ),
                            data: (times) => times.isEmpty
                                ? Notice(
                                    context.t(
                                      'គ្មានពេលទំនេរនៅថ្ងៃនេះ សូមជ្រើសថ្ងៃផ្សេង។',
                                      'No free times this day. Try another day.',
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final t in times)
                                        TimeTile(
                                          label: context.fmt('HH:mm', t),
                                          selected: _selected == t,
                                          onTap: () =>
                                              setState(() => _selected = t),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: _selected == null ? const Offset(0, 1.2) : Offset.zero,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    Gap.page,
                    12,
                    Gap.page,
                    MediaQuery.of(context).padding.bottom + 12,
                  ),
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border(top: BorderSide(color: p.line)),
                  ),
                  child: PrimaryButton(
                    label: _selected == null
                        ? ''
                        : '${context.t('ណាត់ជួបម៉ោង', 'Book')} ${context.fmt('HH:mm', _selected!)}',
                    busy: _booking,
                    onPressed: _selected == null ? null : _book,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ hospital detail

final _hospitalProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
      return Map<String, dynamic>.from(
        await ref.read(apiClientProvider).get('/hospitals/$id') as Map,
      );
    });

class HospitalDetailScreen extends ConsumerWidget {
  const HospitalDetailScreen({super.key, required this.hospitalId});
  final String hospitalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final hospital = ref.watch(_hospitalProvider(hospitalId));
    final doctors = ref.watch(_hospitalDoctorsProvider(hospitalId));
    return Scaffold(
      appBar: AppBar(title: Text(context.t('មន្ទីរពេទ្យ', 'Hospital'))),
      body: hospital.when(
        loading: () => const SkeletonList(count: 3, itemHeight: 150),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(_hospitalProvider(hospitalId)),
        ),
        data: (h) {
          final departments = List<String>.from(
            h['departments'] as List? ?? const [],
          );
          final lat = (h['latitude'] as num?)?.toDouble();
          final lon = (h['longitude'] as num?)?.toDouble();
          final name = context.isKhmer
              ? h['name'] as String
              : ((h['nameLatin'] as String?) ?? h['name'] as String);
          return PageWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                0,
                Gap.page,
                Gap.xxl,
              ),
              children: [
                BannerImage(
                  photoUrl: h['photoUrl'] as String?,
                  height: 180,
                  radius: Radii.lg,
                ),
                const SizedBox(height: Gap.lg),
                Text(name, style: Theme.of(context).textTheme.headlineSmall),
                if (h['demo'] == true) ...[
                  const SizedBox(height: Gap.md),
                  Notice(
                    context.t(
                      'ទិន្នន័យគំរូ សមត្ថភាព និងភាពទំនេរមិនមែនជាការពិតទេ។',
                      'Sample record. Capabilities and availability are not real.',
                    ),
                    tone: Tone.amber,
                  ),
                ],
                const SizedBox(height: Gap.md),
                if (h['address'] != null)
                  InfoRow(
                    icon: Icons.place_outlined,
                    label: context.t('អាសយដ្ឋាន', 'Address'),
                    value: '${h['address']}',
                  ),
                if (h['openingHours'] != null)
                  InfoRow(
                    icon: Icons.schedule_rounded,
                    label: context.t('ម៉ោងបើក', 'Hours'),
                    value: '${h['openingHours']}',
                  ),
                if (h['phone'] != null)
                  InfoRow(
                    icon: Icons.call_outlined,
                    label: context.t('ទូរស័ព្ទ', 'Phone'),
                    value: h['phone'] as String,
                    onTap: () => launchUrl(
                      Uri(scheme: 'tel', path: h['phone'] as String),
                    ),
                  ),
                if (lat != null && lon != null) ...[
                  const SizedBox(height: Gap.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.lg),
                    child: SizedBox(
                      height: 190,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(lat, lon),
                          initialZoom: 14,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.pinchZoom |
                                InteractiveFlag.drag,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.sengchhun.healthresponse',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(lat, lon),
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.location_on_rounded,
                                  color: p.red,
                                  size: 44,
                                ),
                              ),
                            ],
                          ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                '© OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  GhostButton(
                    compact: true,
                    icon: Icons.directions_rounded,
                    label: context.t(
                      'បើកក្នុងកម្មវិធីផែនទី',
                      'Open in maps app',
                    ),
                    onPressed: () => launchUrl(
                      Uri.parse('geo:$lat,$lon?q=$lat,$lon'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
                if (departments.isNotEmpty) ...[
                  const SizedBox(height: Gap.xl),
                  SectionHeader(
                    context.t('ផ្នែក', 'Departments'),
                    count: departments.length,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in departments) Pill(d, tone: Tone.brand),
                    ],
                  ),
                ],
                const SizedBox(height: Gap.xl),
                SectionHeader(context.t('គ្រូពេទ្យនៅទីនេះ', 'Doctors here')),
                doctors.when(
                  loading: () => const Skeleton(height: 92, radius: Radii.lg),
                  error: (e, _) => Text(describeError(e)),
                  data: (list) => list.isEmpty
                      ? Text(
                          context.t(
                            'មិនទាន់មានគ្រូពេទ្យ',
                            'No doctors listed yet',
                          ),
                          style: TextStyle(color: p.muted),
                        )
                      : Column(
                          children: [
                            for (final d in list)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: DoctorRow(doctor: d),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
