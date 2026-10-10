import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/kit.dart';
import '../../core/design/palette.dart';
import '../../core/i18n/language.dart';
import '../../core/network/providers.dart';

final notificationsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  return Map<String, dynamic>.from(
    await ref.read(apiClientProvider).get('/notifications') as Map,
  );
});

(IconData, Tone) _category(String c) {
  if (c.startsWith('EMERGENCY') || c.startsWith('RESPONDER'))
    return (Icons.emergency_rounded, Tone.red);
  if (c.startsWith('APPOINTMENT'))
    return (Icons.event_available_rounded, Tone.blue);
  if (c.startsWith('MEDICATION')) return (Icons.medication_rounded, Tone.teal);
  return (Icons.notifications_rounded, Tone.neutral);
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
    final data = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('ការជូនដំណឹង', 'Notifications'))),
      body: PageWidth(
        child: data.when(
          loading: () => const SkeletonList(itemHeight: 76),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
          data: (d) {
            final items = List<Map<String, dynamic>>.from(d['items'] as List);
            if (items.isEmpty) {
              return EmptyState(
                art: Art.bell,
                title: context.t(
                  'គ្មានការជូនដំណឹងថ្មី',
                  'You are all caught up',
                ),
                message: context.t(
                  'ព័ត៌មានអំពីការណាត់ជួប និងសំណើនឹងបង្ហាញនៅទីនេះ។',
                  'Updates about appointments and requests show up here.',
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.sm,
                Gap.page,
                Gap.xl,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = items[i];
                final read = n['read'] as bool;
                final (icon, tone) = _category(n['category'] as String);
                final created = DateTime.parse(n['createdAt'] as String)
                    .toLocal();
                return Surface(
                  color: read ? p.surface : p.tealSoft.withValues(alpha: 0.5),
                  onTap: read
                      ? null
                      : () async {
                          await ref
                              .read(apiClientProvider)
                              .post('/notifications/${n['id']}/read');
                          ref.invalidate(notificationsProvider);
                        },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: tone == Tone.red
                              ? p.redSoft
                              : (tone == Tone.blue
                                    ? p.blue.withValues(alpha: .12)
                                    : p.sand),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          size: 21,
                          color: tone == Tone.red
                              ? p.red
                              : (tone == Tone.blue ? p.blue : p.tealDeep),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n['title'] as String,
                              style: TextStyle(
                                fontWeight: read
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              n['body'] as String,
                              style: TextStyle(color: p.inkSoft, height: 1.45),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.fmt('d MMM · HH:mm', created),
                              style: TextStyle(color: p.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      if (!read)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: p.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
