import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/palette.dart';
import '../../core/i18n/language.dart';
import 'sensor_controller.dart';

/// Full-screen "Are you OK?" prompt shown for a POSSIBLE incident. The countdown is cancellable.
class SafetyCheckScreen extends ConsumerWidget {
  const SafetyCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Palette.of(context);
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
        backgroundColor: p.red,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (candidate.simulated)
                  Align(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        context.t(
                          'របៀបបង្ហាញ · ក្លែង',
                          'DEMONSTRATION · simulated',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  context.t('តើអ្នកមិនអីទេឬ?', 'Are you OK?'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.t(
                    'យើងឃើញការប៉ះទង្គិចខ្លាំង បន្ទាប់មកគ្មានចលនា។ នេះគ្រាន់តែជាកាលៈទេសៈអាចមាន មិនមែនជាការបញ្ជាក់ថាមានគ្រោះថ្នាក់ទេ។',
                    'We noticed a sudden impact followed by no movement. This is only a possible incident, not a confirmed accident.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 34),
                Semantics(
                  liveRegion: true,
                  label: '${state.remaining}',
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 168,
                        height: 168,
                        child: CircularProgressIndicator(
                          value: total == 0 ? 0 : state.remaining / total,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Text(
                        '${state.remaining}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 60,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  state.settings.autoDispatchEnabled
                      ? context.t(
                          'ប្រសិនបើអ្នកមិនឆ្លើយតប សំណើសង្គ្រោះបន្ទាន់នឹងត្រូវបានផ្ញើ។',
                          'If you do not respond, an emergency request will be sent.',
                        )
                      : context.t(
                          'ការផ្ញើដោយស្វ័យប្រវត្តិត្រូវបានបិទ គ្មានអ្វីត្រូវបានផ្ញើទេលុះត្រាតែអ្នកស្នើ។',
                          'Automatic sending is off: nothing is sent unless you ask for help.',
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 64,
                  child: FilledButton(
                    onPressed: controller.confirmSafe,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: p.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      context.t('ខ្ញុំមិនអីទេ', "I'm OK"),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: OutlinedButton(
                    onPressed: controller.requestHelpNow,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      context.t('ខ្ញុំត្រូវការជំនួយឥឡូវនេះ', 'I need help now'),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
