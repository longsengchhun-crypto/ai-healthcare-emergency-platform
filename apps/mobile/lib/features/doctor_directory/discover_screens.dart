import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/state_views.dart';
import '../appointments/appointments_screen.dart';
import '../location/location_service.dart';

final doctorsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, q) async {
      final res = await ref
          .read(apiClientProvider)
          .get('/doctors', query: {'q': q, 'size': 50});
      return List<Map<String, dynamic>>.from((res as Map)['items'] as List);
    });

final hospitalsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, q) async {
      final loc = await DeviceLocationProvider().current(
        requestPermission: false,
      );
      final res = await ref
          .read(apiClientProvider)
          .get(
            '/hospitals',
            query: {
              'q': q,
              'size': 30,
              if (loc.hasFix) 'lat': loc.latitude,
              if (loc.hasFix) 'lon': loc.longitude,
            },
          );
      return List<Map<String, dynamic>>.from((res as Map)['items'] as List);
    });

String specialtyLabel(Map<String, dynamic> d) {
  final km = d['specialtyKm'] as String?;
  final en = d['specialty'] as String;
  return km == null || km.isEmpty ? en : '$km · $en';
}

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ស្វែងរកការថែទាំ',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Find a doctor or hospital',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ឈ្មោះ ឬឯកទេស · Name or specialty',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onSubmitted: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'វេជ្ជបណ្ឌិត · Doctors'),
                  Tab(text: 'មន្ទីរពេទ្យ · Hospitals'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _DoctorList(query: _query),
                    _HospitalList(query: _query),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor, this.compact = false});
  final Map<String, dynamic> doctor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    final latin = d['nameLatin'] as String?;
    if (compact) {
      return SizedBox(
        width: 150,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/doctor/${d['id']}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PersonAvatar(
                    name: d['fullName'] as String,
                    photoUrl: d['photoUrl'] as String?,
                    size: 72,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    d['fullName'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    (d['specialtyKm'] as String?) ?? (d['specialty'] as String),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/doctor/${d['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              PersonAvatar(
                name: d['fullName'] as String,
                photoUrl: d['photoUrl'] as String?,
                size: 68,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d['fullName'] as String,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (latin != null)
                      Text(
                        latin,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        TagChip(specialtyLabel(d)),
                        if (d['demo'] == true)
                          const TagChip(
                            'គំរូ · Sample',
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                    if (d['hospitalName'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                d['hospitalName'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorList extends ConsumerWidget {
  const _DoctorList({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(doctorsProvider(query));
    return doctors.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(doctorsProvider(query)),
      ),
      data: (items) => items.isEmpty
          ? const EmptyView(
              icon: Icons.person_search,
              title: 'រកមិនឃើញវេជ្ជបណ្ឌិត · No doctors found',
              message: 'Try a different name or specialty.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => DoctorCard(doctor: items[i]),
            ),
    );
  }
}

class _HospitalList extends ConsumerWidget {
  const _HospitalList({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitals = ref.watch(hospitalsProvider(query));
    return hospitals.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(hospitalsProvider(query)),
      ),
      data: (items) => items.isEmpty
          ? const EmptyView(
              icon: Icons.local_hospital_outlined,
              title: 'រកមិនឃើញមន្ទីរពេទ្យ · No hospitals found',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final h = items[i];
                final distance = h['distanceKm'];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push('/hospital/${h['id']}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BannerImage(
                          photoUrl: h['photoUrl'] as String?,
                          height: 130,
                          radius: 0,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h['name'] as String,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (h['nameLatin'] != null)
                                Text(
                                  h['nameLatin'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (h['city'] != null)
                                    TagChip(
                                      h['city'] as String,
                                      icon: Icons.place_outlined,
                                    ),
                                  if (distance != null)
                                    TagChip(
                                      '$distance km',
                                      icon: Icons.near_me_outlined,
                                      color: AppColors.blue,
                                    ),
                                  if (h['openingHours'] != null)
                                    TagChip(
                                      h['openingHours'] as String,
                                      icon: Icons.schedule,
                                      color: AppColors.navy,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

final _doctorProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
      return Map<String, dynamic>.from(
        await ref.read(apiClientProvider).get('/doctors/$id') as Map,
      );
    });

final _slotsProvider = FutureProvider.autoDispose
    .family<List<DateTime>, ({String doctorId, String date})>((
      ref,
      args,
    ) async {
      final res = await ref
          .read(apiClientProvider)
          .get('/doctors/${args.doctorId}/slots', query: {'date': args.date});
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
  bool _booking = false;

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_day);

  Future<void> _book(DateTime slot) async {
    final reasonController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ស្នើសុំការណាត់ជួប',
              style: Theme.of(ctx).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(DateFormat('EEEE, d MMM yyyy · HH:mm').format(slot)),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'មូលហេតុ (មិនចាំបាច់) · Reason (optional)',
                helperText: 'Avoid sharing detailed medical information here.',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ផ្ញើសំណើ · Send request'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _booking = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/appointments',
            body: {
              'doctorId': widget.doctorId,
              'startsAt': slot.toUtc().toIso8601String(),
              if (reasonController.text.trim().isNotEmpty)
                'reason': reasonController.text.trim(),
            },
          );
      ref.invalidate(appointmentsProvider);
      ref.invalidate(_slotsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Request sent. The doctor will confirm your appointment.',
            ),
          ),
        );
        context.go('/appointments');
      }
    } on AppException catch (e) {
      ref.invalidate(_slotsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = ref.watch(_doctorProvider(widget.doctorId));
    final slots = ref.watch(
      _slotsProvider((doctorId: widget.doctorId, date: _dateKey)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('វេជ្ជបណ្ឌិត · Doctor')),
      body: doctor.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(_doctorProvider(widget.doctorId)),
        ),
        data: (d) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Center(
              child: PersonAvatar(
                name: d['fullName'] as String,
                photoUrl: d['photoUrl'] as String?,
                size: 120,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              d['fullName'] as String,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (d['nameLatin'] != null)
              Text(
                d['nameLatin'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                TagChip(specialtyLabel(d)),
                if (d['yearsExperience'] != null)
                  TagChip(
                    '${d['yearsExperience']} ឆ្នាំ · yrs',
                    icon: Icons.workspace_premium_outlined,
                    color: AppColors.navy,
                  ),
                if (d['languages'] != null)
                  TagChip(
                    d['languages'] as String,
                    icon: Icons.translate,
                    color: AppColors.blue,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (d['hospitalName'] != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_hospital_outlined),
                title: Text(d['hospitalName'] as String),
                onTap: d['hospitalId'] == null
                    ? null
                    : () => context.push('/hospital/${d['hospitalId']}'),
                trailing: const Icon(Icons.chevron_right),
              ),
            if (d['demo'] == true)
              const NoticeBanner(
                'ប្រវត្តិរូបគំរូ មិនមែនជាគ្រូពេទ្យពិតទេ · Sample profile for demonstration. Not a real doctor and not verified.',
                warning: true,
              )
            else if (d['verificationStatus'] != 'VERIFIED')
              const NoticeBanner(
                'This clinician profile has not been verified by the platform.',
                warning: true,
              ),
            if (d['bio'] != null) ...[
              const SizedBox(height: 14),
              Text(
                'អំពីវេជ្ជបណ្ឌិត · About',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(d['bio'] as String, style: const TextStyle(height: 1.5)),
              if (d['bioEn'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  d['bioEn'] as String,
                  style: TextStyle(
                    height: 1.5,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 22),
            Text(
              'ជ្រើសរើសពេលវេលា · Choose a time',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final day = DateTime.now().add(Duration(days: i + 1));
                  final selected =
                      DateFormat('yyyy-MM-dd').format(day) == _dateKey;
                  return ChoiceChip(
                    selected: selected,
                    label: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('EEE').format(day)),
                        Text(
                          DateFormat('d MMM').format(day),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    onSelected: (_) => setState(() => _day = day),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            slots.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: LoadingView(),
              ),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(
                  _slotsProvider((doctorId: widget.doctorId, date: _dateKey)),
                ),
              ),
              data: (times) => times.isEmpty
                  ? const EmptyView(
                      icon: Icons.event_busy,
                      title: 'គ្មានពេលទំនេរ · No free times on this day',
                      message: 'Try another day.',
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in times)
                          ActionChip(
                            label: Text(DateFormat('HH:mm').format(t)),
                            onPressed: _booking ? null : () => _book(t),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final hospital = ref.watch(_hospitalProvider(hospitalId));
    return Scaffold(
      appBar: AppBar(title: const Text('មន្ទីរពេទ្យ · Hospital')),
      body: hospital.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(_hospitalProvider(hospitalId)),
        ),
        data: (h) {
          final departments = List<String>.from(
            h['departments'] as List? ?? const [],
          );
          final lat = (h['latitude'] as num?)?.toDouble();
          final lon = (h['longitude'] as num?)?.toDouble();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              BannerImage(photoUrl: h['photoUrl'] as String?, height: 180),
              const SizedBox(height: 16),
              Text(
                h['name'] as String,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (h['nameLatin'] != null)
                Text(
                  h['nameLatin'] as String,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              const SizedBox(height: 12),
              if (h['demo'] == true)
                const NoticeBanner(
                  'ទិន្នន័យគំរូ សមត្ថភាព និងភាពទំនេរមិនមែនជាការពិតទេ · Sample record. Capabilities and availability are not real.',
                  warning: true,
                ),
              const SizedBox(height: 8),
              if (h['address'] != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: Text('${h['address']}'),
                  subtitle: Text('${h['city'] ?? ''}'),
                ),
              if (h['openingHours'] != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text('${h['openingHours']}'),
                ),
              if (h['phone'] != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.call_outlined),
                  title: Text(h['phone'] as String),
                  onTap: () =>
                      launchUrl(Uri(scheme: 'tel', path: h['phone'] as String)),
                ),
              if (lat != null && lon != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('បើកផែនទី · Open in maps'),
                  onTap: () => launchUrl(
                    Uri.parse('geo:$lat,$lon?q=$lat,$lon'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              if (departments.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'ផ្នែក · Departments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final d in departments) TagChip(d)],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
