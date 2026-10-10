import 'package:flutter/material.dart';

import 'api.dart';
import 'pages.dart' show Loader;

void _toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<String?> _ask(BuildContext context, String title, String label) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Hospitals and departments (permission DIRECTORY_MANAGE).
class HospitalsPage extends StatelessWidget {
  const HospitalsPage({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
    load: () async => Map<String, dynamic>.from(
      await api.get('/hospitals', query: {'size': 50}) as Map,
    ),
    builder: (context, page, reload) {
      final items = (page['items'] as List).cast<Map>();
      return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Add hospital'),
          onPressed: () async {
            final name = await _ask(context, 'New hospital', 'Name');
            if (name == null || name.isEmpty) return;
            try {
              await api.post('/admin/hospitals', body: {'name': name});
              reload();
            } on ApiFailure catch (e) {
              if (context.mounted) _toast(context, e.message);
            }
          },
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final h in items)
              Card(
                child: ListTile(
                  title: Text(
                    '${h['name']}${h['demo'] == true ? '  (SAMPLE)' : ''}',
                  ),
                  subtitle: Text('${h['city'] ?? ''} · ${h['phone'] ?? ''}'),
                  trailing: TextButton(
                    child: const Text('Add department'),
                    onPressed: () async {
                      final name = await _ask(
                        context,
                        'New department',
                        'Department name',
                      );
                      if (name == null || name.isEmpty) return;
                      try {
                        await api.post(
                          '/admin/hospitals/${h['id']}/departments',
                          body: {'name': name},
                        );
                        reload();
                      } on ApiFailure catch (e) {
                        if (context.mounted) _toast(context, e.message);
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Doctor directory with verification workflow (permission DOCTOR_VERIFY).
class DoctorsPage extends StatelessWidget {
  const DoctorsPage({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) => Loader<List<dynamic>>(
    load: () async =>
        List<dynamic>.from(await api.get('/admin/doctors') as List),
    builder: (context, doctors, reload) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final d in doctors.cast<Map>())
          Card(
            child: ListTile(
              title: Text('${d['fullName']} · ${d['specialty']}'),
              subtitle: Text(
                '${d['email']} · licence: ${(d['licenseNumber'] as String).isEmpty ? 'not provided' : d['licenseNumber']}'
                ' · ${d['verificationStatus']}${d['demo'] == true ? ' · DEMO' : ''}',
              ),
              trailing: api.can('DOCTOR_VERIFY')
                  ? PopupMenuButton<String>(
                      tooltip: 'Set verification',
                      onSelected: (status) async {
                        try {
                          await api.post(
                            '/admin/doctors/${d['id']}/verification',
                            body: {'status': status},
                          );
                          reload();
                        } on ApiFailure catch (e) {
                          if (context.mounted) _toast(context, e.message);
                        }
                      },
                      itemBuilder: (_) => [
                        for (final s in const [
                          'VERIFIED',
                          'PENDING',
                          'REJECTED',
                          'UNVERIFIED',
                        ])
                          PopupMenuItem(value: s, child: Text('Mark $s')),
                      ],
                    )
                  : null,
            ),
          ),
      ],
    ),
  );
}
