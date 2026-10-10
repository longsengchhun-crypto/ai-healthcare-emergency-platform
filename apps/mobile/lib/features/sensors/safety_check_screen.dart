import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'sensor_controller.dart';

/// Full-screen "Are you OK?" prompt shown for a POSSIBLE incident. Countdown is cancellable.
class SafetyCheckScreen extends ConsumerWidget {
  const SafetyCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sensorControllerProvider);
    final controller = ref.read(sensorControllerProvider.notifier);
    final candidate = state.candidate;

    if (candidate == null) {
      // Candidate resolved (safe / help requested / expired): leave this screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && context.canPop()) context.pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final total = state.settings.countdownSeconds;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.emergency,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (candidate.simulated)
                  const Align(
                    child: Chip(
                      label: Text('DEMONSTRATION — simulated sensors'),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Are you OK?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We noticed a sudden impact followed by no movement. This is only a possible '
                  'incident, not a confirmed accident.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 32),
                Semantics(
                  liveRegion: true,
                  label: '${state.remaining} seconds remaining',
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: total == 0 ? 0 : state.remaining / total,
                          strokeWidth: 10,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Text(
                        '${state.remaining}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  state.settings.autoDispatchEnabled
                      ? 'If you do not respond, an emergency request will be sent.'
                      : 'Automatic alerts are off: nothing will be sent unless you ask for help.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: controller.confirmSafe,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.navy,
                    minimumSize: const Size.fromHeight(64),
                  ),
                  child: const Text("I'm OK", style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: controller.requestHelpNow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    minimumSize: const Size.fromHeight(64),
                  ),
                  child: const Text(
                    'I need help now',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
