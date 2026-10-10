import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/providers.dart';
import '../../core/widgets/state_views.dart';

final notificationsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  return Map<String, dynamic>.from(
    await ref.read(apiClientProvider).get('/notifications') as Map,
  );
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(notificationsProvider);
    final fmt = DateFormat('d MMM · HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (d) {
          final items = List<Map<String, dynamic>>.from(d['items'] as List);
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.notifications_none,
              title: 'You are all caught up',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = items[i];
              final read = n['read'] as bool;
              return Card(
                child: ListTile(
                  leading: Icon(
                    read
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: read ? null : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    n['title'] as String,
                    style: TextStyle(
                      fontWeight: read ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${n['body']}\n${fmt.format(DateTime.parse(n['createdAt'] as String).toLocal())}',
                  ),
                  isThreeLine: true,
                  onTap: read
                      ? null
                      : () async {
                          await ref
                              .read(apiClientProvider)
                              .post('/notifications/${n['id']}/read');
                          ref.invalidate(notificationsProvider);
                        },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
