import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api.dart';
import 'management_pages.dart';

final _time = DateFormat('d MMM HH:mm:ss');

String _t(dynamic iso) =>
    iso == null ? '' : _time.format(DateTime.parse(iso as String).toLocal());

// ---------------------------------------------------------------- shared widgets

/// Loads data, shows loading / error (with retry) / content. Optional periodic refresh.
class Loader<T> extends StatefulWidget {
  const Loader({
    super.key,
    required this.load,
    required this.builder,
    this.every,
  });
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;
  final Duration? every;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future = widget.load();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.every != null) {
      _timer = Timer.periodic(widget.every!, (_) => _reload());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() => _future = widget.load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done && !snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snap.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: Color(0xFFD92D20),
              ),
              const SizedBox(height: 8),
              Text('${snap.error}'),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        );
      }
      return widget.builder(context, snap.data as T, _reload);
    },
  );
}

void _toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Widget _statusChip(String s) {
  final color = switch (s) {
    'SUBMITTED' => const Color(0xFFD92D20),
    'ACKNOWLEDGED' ||
    'RESPONDER_ASSIGNED' ||
    'RESPONDER_EN_ROUTE' ||
    'ARRIVED' => const Color(0xFFB54708),
    'RESOLVED' || 'CONFIRMED' || 'COMPLETED' => const Color(0xFF067647),
    _ => Colors.grey,
  };
  return Chip(
    label: Text(
      s.replaceAll('_', ' '),
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    ),
    backgroundColor: color.withValues(alpha: 0.1),
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
  );
}

// ---------------------------------------------------------------- login

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.onSignedIn});
  final Api api;
  final VoidCallback onSignedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.login(_email.text.trim(), _password.text);
      widget.onSignedIn();
    } on ApiFailure catch (e) {
      setState(
        () =>
            _error = e.status == 401 ? 'Invalid email or password' : e.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'HealthResponse Operations',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text('Hospital staff and administrators'),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_busy ? 'Signing in…' : 'Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- shell

class Shell extends StatefulWidget {
  const Shell({super.key, required this.api});
  final Api api;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  List<(String, IconData, Widget Function())> _destinations() {
    final api = widget.api;
    return [
      if (api.can('EMERGENCY_QUEUE_VIEW'))
        ('Overview', Icons.dashboard_outlined, () => OverviewPage(api: api)),
      if (api.can('EMERGENCY_QUEUE_VIEW'))
        (
          'Emergency queue',
          Icons.emergency_outlined,
          () => EmergencyQueuePage(api: api),
        ),
      if (api.can('APPOINTMENT_ADMIN') || api.can('APPOINTMENT_DOCTOR'))
        (
          'Appointments',
          Icons.event_outlined,
          () => AppointmentsPage(api: api),
        ),
      if (api.can('DIRECTORY_MANAGE'))
        (
          'Hospitals',
          Icons.local_hospital_outlined,
          () => HospitalsPage(api: api),
        ),
      if (api.can('DOCTOR_VERIFY') || api.can('DIRECTORY_MANAGE'))
        (
          'Doctors',
          Icons.medical_services_outlined,
          () => DoctorsPage(api: api),
        ),
      if (api.can('USER_ADMIN'))
        ('Users & roles', Icons.group_outlined, () => UsersPage(api: api)),
      if (api.can('AUDIT_VIEW'))
        ('Audit log', Icons.fact_check_outlined, () => AuditPage(api: api)),
      ('System status', Icons.settings_outlined, () => SystemPage(api: api)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dests = _destinations();
    if (_index >= dests.length) _index = 0;
    final wide = MediaQuery.of(context).size.width >= 900;
    final body = dests[_index].$3();
    return Scaffold(
      appBar: AppBar(
        title: Text(dests[_index].$1),
        actions: [
          Center(child: Text('${widget.api.me?['email'] ?? ''}  ')),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.api.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: ListView(
                children: [
                  for (var i = 0; i < dests.length; i++)
                    ListTile(
                      leading: Icon(dests[i].$2),
                      title: Text(dests[i].$1),
                      selected: i == _index,
                      onTap: () {
                        setState(() => _index = i);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: true,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in dests)
                  NavigationRailDestination(
                    icon: Icon(d.$2),
                    label: Text(d.$1),
                  ),
              ],
            ),
          Expanded(
            child: KeyedSubtree(key: ValueKey(_index), child: body),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- overview

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
    every: const Duration(seconds: 10),
    load: () async =>
        Map<String, dynamic>.from(await api.get('/admin/overview') as Map),
    builder: (context, d, reload) {
      Widget block(String title, Map data) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (data.isEmpty) const Text('No data yet'),
              for (final e in data.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(e.key.toString().replaceAll('_', ' ')),
                      ),
                      Text(
                        '${e.value}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: (d['pendingAcknowledgements'] as num) > 0
                ? const Color(0xFFFEF3F2)
                : null,
            child: ListTile(
              leading: const Icon(Icons.notification_important_outlined),
              title: Text(
                '${d['pendingAcknowledgements']} emergency event(s) awaiting acknowledgement',
              ),
              subtitle: Text(
                'Live data from the backend · updated ${_t(d['generatedAt'])}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in {
                'Emergency events by status': d['emergenciesByStatus'],
                'Appointments by status': d['appointmentsByStatus'],
                'Doctors by verification': d['doctorsByVerification'],
                'Notification deliveries': d['notificationDeliveries'],
              }.entries)
                SizedBox(
                  width: 320,
                  child: block(entry.key, entry.value as Map),
                ),
            ],
          ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------- emergency queue

class EmergencyQueuePage extends StatefulWidget {
  const EmergencyQueuePage({super.key, required this.api});
  final Api api;

  @override
  State<EmergencyQueuePage> createState() => _EmergencyQueuePageState();
}

class _EmergencyQueuePageState extends State<EmergencyQueuePage> {
  String? _filter;
  int _epoch = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('Status: '),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _filter,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  for (final s in const [
                    'SUBMITTED',
                    'ACKNOWLEDGED',
                    'RESPONDER_ASSIGNED',
                    'RESPONDER_EN_ROUTE',
                    'ARRIVED',
                    'RESOLVED',
                    'CANCELLED',
                  ])
                    DropdownMenuItem(
                      value: s,
                      child: Text(s.replaceAll('_', ' ')),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _filter = v;
                  _epoch++;
                }),
              ),
              const Spacer(),
              const Text(
                'Demonstration response workflow — not a real dispatch network',
              ),
            ],
          ),
        ),
        Expanded(
          child: Loader<List<dynamic>>(
            key: ValueKey('$_filter-$_epoch'),
            every: const Duration(seconds: 5),
            load: () async => List<dynamic>.from(
              await widget.api.get(
                '/emergencies',
                query: {if (_filter != null) 'status': _filter, 'limit': 100},
              ) as List,
            ),
            builder: (context, items, reload) => items.isEmpty
                ? const Center(child: Text('No emergency events'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = items[i] as Map;
                      return Card(
                        child: ListTile(
                          leading: _statusChip(e['status'] as String),
                          title: Text(
                            '${e['patientName'] ?? 'Patient'}'
                            '${e['demo'] == true ? '  (DEMO)' : ''}',
                          ),
                          subtitle: Text(
                            'Created ${_t(e['createdAt'])} · updated ${_t(e['updatedAt'])}'
                            '${e['location'] == null ? ' · no location shared' : ''}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await showDialog<void>(
                              context: context,
                              builder: (_) => EmergencyDialog(
                                api: widget.api,
                                id: e['id'] as String,
                              ),
                            );
                            reload();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class EmergencyDialog extends StatefulWidget {
  const EmergencyDialog({super.key, required this.api, required this.id});
  final Api api;
  final String id;

  @override
  State<EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<EmergencyDialog> {
  Map<String, dynamic>? _event;
  List<dynamic> _responders = const [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.api
        .get('/emergencies/responders')
        .then((r) {
          if (mounted) setState(() => _responders = r as List);
        })
        .catchError((_) {});
  }

  Future<void> _refresh() async {
    try {
      final e = await widget.api.get('/emergencies/${widget.id}');
      if (mounted) setState(() => _event = Map<String, dynamic>.from(e as Map));
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _act(String path, [Object? body]) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final e = await widget.api.post(
        '/emergencies/${widget.id}/$path',
        body: body,
      );
      setState(() => _event = Map<String, dynamic>.from(e as Map));
    } on ApiFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _event;
    final status = e?['status'] as String?;
    final canManage = widget.api.can('EMERGENCY_MANAGE');
    final next = {
      'RESPONDER_ASSIGNED': 'RESPONDER_EN_ROUTE',
      'RESPONDER_EN_ROUTE': 'ARRIVED',
      'ARRIVED': 'RESOLVED',
    }[status];
    final loc = e?['location'] as Map?;
    return AlertDialog(
      title: Row(
        children: [
          const Text('Emergency event'),
          const SizedBox(width: 12),
          if (status != null) _statusChip(status),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: e == null
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e['patientName'] ?? ''}  ${e['patientPhone'] ?? ''}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      loc == null
                          ? 'No location was shared.'
                          : 'Location: ${loc['latitude']}, ${loc['longitude']}'
                                '${loc['accuracyMeters'] == null ? '' : ' (±${(loc['accuracyMeters'] as num).round()} m)'}'
                                ' · captured ${_t(loc['capturedAt'])}',
                    ),
                    if (e['demo'] == true) const Text('DEMONSTRATION EVENT'),
                    const SizedBox(height: 12),
                    Text(
                      'Timeline',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final h in e['history'] as List)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${_t((h as Map)['at'])}  ${h['toStatus']}'
                          '${h['note'] == null ? '' : ' — ${h['note']}'}',
                        ),
                      ),
                    if ((e['assignments'] as List).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Responders: ${(e['assignments'] as List).map((a) => (a as Map)['responderName']).join(', ')}',
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        if (canManage && status == 'SUBMITTED') ...[
          FilledButton(
            onPressed: _busy ? null : () => _act('acknowledge'),
            child: const Text('Acknowledge'),
          ),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _act('status', {
                    'status': 'REJECTED',
                    'note': 'Rejected by staff',
                  }),
            child: const Text('Reject'),
          ),
        ],
        if (canManage &&
            (status == 'ACKNOWLEDGED' || status == 'RESPONDER_ASSIGNED'))
          PopupMenuButton<String>(
            tooltip: 'Assign responder',
            enabled: !_busy && _responders.isNotEmpty,
            onSelected: (id) => _act('assign', {'responderId': id}),
            itemBuilder: (_) => [
              for (final r in _responders)
                PopupMenuItem(
                  value: (r as Map)['id'] as String,
                  child: Text('${r['fullName']} (${r['role']})'),
                ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Assign responder ▾'),
            ),
          ),
        if (canManage && next != null)
          FilledButton(
            onPressed: _busy ? null : () => _act('status', {'status': next}),
            child: Text('Mark ${next.replaceAll('_', ' ').toLowerCase()}'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- appointments

class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
    load: () async => Map<String, dynamic>.from(
      await api.get('/appointments', query: {'size': 100}) as Map,
    ),
    builder: (context, page, reload) {
      final items = List<dynamic>.from(page['items'] as List);
      if (items.isEmpty) return const Center(child: Text('No appointments'));
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('When')),
              DataColumn(label: Text('Patient')),
              DataColumn(label: Text('Doctor')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('')),
            ],
            rows: [
              for (final a in items.cast<Map>())
                DataRow(
                  cells: [
                    DataCell(Text(_t(a['startsAt']))),
                    DataCell(Text('${a['patientName']}')),
                    DataCell(Text('${a['doctorName']}')),
                    DataCell(_statusChip(a['status'] as String)),
                    DataCell(
                      (a['status'] == 'REQUESTED' || a['status'] == 'CONFIRMED')
                          ? TextButton(
                              onPressed: () async {
                                try {
                                  await api.post(
                                    '/appointments/${a['id']}/cancel',
                                  );
                                  reload();
                                } on ApiFailure catch (e) {
                                  if (context.mounted) {
                                    _toast(context, e.message);
                                  }
                                }
                              },
                              child: const Text('Cancel'),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------- users

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.api});
  final Api api;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _q = '';
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name or email',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => setState(() {
              _q = v.trim();
              _page = 0;
            }),
          ),
        ),
        Expanded(
          child: Loader<Map<String, dynamic>>(
            key: ValueKey('$_q-$_page'),
            load: () async => Map<String, dynamic>.from(
              await widget.api.get(
                '/admin/users',
                query: {'q': _q, 'page': _page, 'size': 25},
              ) as Map,
            ),
            builder: (context, page, reload) {
              final items = (page['items'] as List).cast<Map>();
              final total = (page['total'] as num).toInt();
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        for (final u in items)
                          ListTile(
                            title: Text('${u['fullName']}  ·  ${u['email']}'),
                            subtitle: Text(
                              '${(u['roles'] as List).join(', ')} · ${u['status']}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                try {
                                  if (v.startsWith('ROLE:')) {
                                    await widget.api.post(
                                      '/admin/users/${u['id']}/roles',
                                      body: {'role': v.substring(5)},
                                    );
                                  } else {
                                    await widget.api.patch(
                                      '/admin/users/${u['id']}/status',
                                      body: {'status': v},
                                    );
                                  }
                                  reload();
                                } on ApiFailure catch (e) {
                                  if (context.mounted) {
                                    _toast(context, e.message);
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'ACTIVE',
                                  child: Text('Set active'),
                                ),
                                const PopupMenuItem(
                                  value: 'SUSPENDED',
                                  child: Text('Suspend'),
                                ),
                                const PopupMenuDivider(),
                                for (final r in const [
                                  'PATIENT',
                                  'DOCTOR',
                                  'HOSPITAL_STAFF',
                                  'SYSTEM_ADMIN',
                                ])
                                  PopupMenuItem(
                                    value: 'ROLE:$r',
                                    child: Text('Set role: $r'),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _page > 0
                              ? () => setState(() => _page--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page ${_page + 1} · $total users'),
                        IconButton(
                          onPressed: (_page + 1) * 25 < total
                              ? () => setState(() => _page++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- audit

class AuditPage extends StatefulWidget {
  const AuditPage({super.key, required this.api});
  final Api api;

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  int _page = 0;
  String? _outcome;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Text('Outcome: '),
            DropdownButton<String?>(
              value: _outcome,
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'SUCCESS', child: Text('Success')),
                DropdownMenuItem(value: 'DENIED', child: Text('Denied')),
                DropdownMenuItem(value: 'FAILURE', child: Text('Failure')),
              ],
              onChanged: (v) => setState(() {
                _outcome = v;
                _page = 0;
              }),
            ),
          ],
        ),
      ),
      Expanded(
        child: Loader<Map<String, dynamic>>(
          key: ValueKey('$_outcome-$_page'),
          load: () async => Map<String, dynamic>.from(
            await widget.api.get(
              '/admin/audit-logs',
              query: {'page': _page, 'size': 50, 'outcome': _outcome},
            ) as Map,
          ),
          builder: (context, page, reload) {
            final rows = (page['items'] as List).cast<Map>();
            final total = (page['total'] as num).toInt();
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      for (final r in rows)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            r['outcome'] == 'DENIED'
                                ? Icons.block
                                : Icons.check_circle_outline,
                            color: r['outcome'] == 'DENIED'
                                ? const Color(0xFFD92D20)
                                : null,
                          ),
                          title: Text(
                            '${r['action']}  ${r['targetType'] ?? ''} ${r['targetId'] ?? ''}',
                          ),
                          subtitle: Text(
                            '${_t(r['createdAt'])} · ${r['actorRole'] ?? 'anonymous'} · ${r['outcome']}'
                            '${r['detail'] == null ? '' : ' · ${r['detail']}'}',
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _page > 0
                          ? () => setState(() => _page--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('Page ${_page + 1} · $total entries'),
                    IconButton(
                      onPressed: (_page + 1) * 50 < total
                          ? () => setState(() => _page++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------- system

class SystemPage extends StatelessWidget {
  const SystemPage({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
    load: () async =>
        Map<String, dynamic>.from(await api.get('/system/settings') as Map),
    builder: (context, settings, reload) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Integration status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Push notifications (FCM): not configured in this build — in-app inbox only',
                ),
                const Text(
                  '• SMS / voice to emergency contacts: no provider configured — contacts are NOT notified automatically',
                ),
                const Text(
                  '• AI provider: deterministic demonstration provider (rule based, not a language model)',
                ),
                const Text('• OCR for scanned documents: not configured'),
                const Text(
                  '• Real emergency dispatch: none — in-app demonstration workflow only',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final e in settings.entries)
          Card(
            child: ListTile(
              title: Text(e.key),
              subtitle: Text('${e.value}'),
              trailing: api.can('SETTINGS_MANAGE')
                  ? IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final c = TextEditingController(text: '${e.value}');
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(e.key),
                            content: TextField(controller: c),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          try {
                            await api.put(
                              '/admin/settings/${e.key}',
                              body: {'value': c.text.trim()},
                            );
                            reload();
                          } on ApiFailure catch (err) {
                            if (context.mounted) _toast(context, err.message);
                          }
                        }
                      },
                    )
                  : null,
            ),
          ),
      ],
    ),
  );
}
