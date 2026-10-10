import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

const _onboardedKey = 'onboarding.done';

Future<bool> isOnboarded() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  } catch (_) {
    return false;
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      Icons.health_and_safety_rounded,
      'Your care in one place',
      'Find doctors and hospitals, book appointments, keep records and medication reminders together.',
    ),
    (
      Icons.emergency_share_rounded,
      'Ask for help, simply',
      'Hold the emergency button to send your location to the response queue and follow the real status.',
    ),
    (
      Icons.shield_outlined,
      'Honest by design',
      'This app is a demonstration platform. AI features give informational guidance only and never a diagnosis, '
          'and it does not replace calling your local emergency number.',
    ),
  ];

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardedKey, true);
    } catch (_) {}
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final p in _pages)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(p.$1, size: 96, color: AppColors.teal),
                          const SizedBox(height: 32),
                          Text(
                            p.$2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            p.$3,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  Container(
                    margin: const EdgeInsets.all(4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.navy : Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: last
                    ? _finish
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
