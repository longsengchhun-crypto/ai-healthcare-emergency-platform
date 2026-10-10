import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';
import '../appointments/appointments_screen.dart';
import '../location/location_service.dart';

final doctorsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, q) async {
      final res = await ref
          .read(apiClientProvider)
          .get('/doctors', query: {'q': q, 'size': 30});
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
        appBar: AppBar(
          title: const Text('Discover'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Doctors'),
              Tab(text: 'Hospitals'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by name or specialty',
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
              title: 'No doctors found',
              message: 'Try a different name or specialty.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final d = items[i];
                final verified = d['verificationStatus'] == 'VERIFIED';
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: const CircleAvatar(
                      child: Icon(Icons.medical_services_outlined),
                    ),
                    title: Text(d['fullName'] as String),
                    subtitle: Text(
                      '${d['specialty']}${d['hospitalName'] == null ? '' : ' · ${d['hospitalName']}'}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          verified ? Icons.verified : Icons.help_outline,
                          color: verified
                              ? AppColors.success
                              : AppColors.warning,
                          size: 20,
                        ),
                        Text(
                          verified ? 'Verified' : 'Unverified',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/doctor/${d['id']}'),
                  ),
                );
              },
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
              title: 'No hospitals found',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final h = items[i];
                final distance = h['distanceKm'];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: const CircleAvatar(
                      child: Icon(Icons.local_hospital_outlined),
                    ),
                    title: Text(h['name'] as String),
                    subtitle: Text(
                      [
                        if (h['city'] != null) h['city'],
                        if (distance != null) '$distance km away',
                        if (h['demo'] == true) 'SAMPLE record',
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/hospital/${h['id']}'),
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
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Request appointment',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(DateFormat('EEEE, d MMM yyyy · HH:mm').format(slot)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                helperText: 'Avoid sharing detailed medical information here.',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send request'),
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
      appBar: AppBar(title: const Text('Doctor')),
      body: doctor.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(_doctorProvider(widget.doctorId)),
        ),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              d['fullName'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(d['specialty'] as String),
            if (d['hospitalName'] != null) Text(d['hospitalName'] as String),
            const SizedBox(height: 12),
            if (d['verificationStatus'] != 'VERIFIED')
              const NoticeBanner(
                'This clinician profile has not been verified by the platform.',
                warning: true,
              ),
            if (d['demo'] == true) ...[
              const SizedBox(height: 8),
              const NoticeBanner(
                'Sample record for demonstration. Not a real doctor.',
              ),
            ],
            if (d['bio'] != null) ...[
              const SizedBox(height: 12),
              Text(d['bio'] as String),
            ],
            const SizedBox(height: 24),
            Text(
              'Choose a time',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
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
                        Text(DateFormat('d MMM').format(day)),
                      ],
                    ),
                    onSelected: (_) => setState(() => _day = day),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
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
                      title: 'No free times on this day',
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
      appBar: AppBar(title: const Text('Hospital')),
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
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                h['name'] as String,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (h['address'] != null)
                Text('${h['address']}, ${h['city'] ?? ''}'),
              if (h['demo'] == true) ...[
                const SizedBox(height: 12),
                const NoticeBanner(
                  'Sample record for demonstration. Capabilities and availability are not real.',
                ),
              ],
              const SizedBox(height: 16),
              if (h['phone'] != null)
                ListTile(
                  leading: const Icon(Icons.call),
                  title: Text(h['phone'] as String),
                  onTap: () =>
                      launchUrl(Uri(scheme: 'tel', path: h['phone'] as String)),
                ),
              if (lat != null && lon != null)
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Open in maps'),
                  onTap: () => launchUrl(
                    Uri.parse('geo:$lat,$lon?q=$lat,$lon'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              if (departments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Departments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [for (final d in departments) Chip(label: Text(d))],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
