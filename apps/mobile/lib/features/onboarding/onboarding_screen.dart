import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/kit.dart';
import '../../core/design/kit_extra.dart';
import '../../core/design/palette.dart';
import '../../core/i18n/language.dart';

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

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardedKey, true);
    } catch (_) {}
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pages = [
      (
        Art.calendar,
        context.t('ការថែទាំរបស់អ្នក នៅកន្លែងតែមួយ', 'Your care, in one place'),
        context.t(
          'រកគ្រូពេទ្យ ណាត់ជួប រក្សាកំណត់ត្រា និងតាមដានការលេបថ្នាំ ទាំងអស់ក្នុងកម្មវិធីតែមួយ។',
          'Find doctors, book visits, keep your records and never miss a medicine.',
        ),
      ),
      (
        Art.pulse,
        context.t('សុំជំនួយបានភ្លាមៗ', 'Ask for help, fast'),
        context.t(
          'សង្កត់ប៊ូតុងសង្គ្រោះបន្ទាន់ដើម្បីផ្ញើទីតាំងរបស់អ្នក ហើយតាមដានស្ថានភាពពិតប្រាកដ។',
          'Hold the emergency button to share your location and follow the real status.',
        ),
      ),
      (
        Art.shield,
        context.t('ស្មោះត្រង់ និងមានសុវត្ថិភាព', 'Honest and private'),
        context.t(
          'ជំនួយ AI ផ្តល់តែព័ត៌មានទូទៅ មិនមែនការធ្វើរោគវិនិច្ឆ័យទេ ហើយមិនជំនួសលេខសង្គ្រោះបន្ទាន់ឡើយ។',
          'AI gives general information, never a diagnosis, and does not replace your local emergency number.',
        ),
      ),
    ];
    final last = _page == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.sm, 0),
              child: Row(
                children: [
                  LanguageToggle(
                    isKhmer: context.isKhmer,
                    onChanged: (c) => languageController.set(c),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      context.t('រំលង', 'Skip'),
                      style: TextStyle(
                        color: p.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final pg in pages)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ArtImage(pg.$1, size: 190),
                          const SizedBox(height: Gap.xl),
                          Text(
                            pg.$2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: Gap.md),
                          Text(
                            pg.$3,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: p.inkSoft,
                              height: 1.6,
                              fontSize: 16,
                            ),
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
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    width: i == _page ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? p.ink : p.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.page),
              child: PrimaryButton(
                label: last
                    ? context.t('ចាប់ផ្តើម', 'Get started')
                    : context.t('បន្ទាប់', 'Next'),
                onPressed: last
                    ? _finish
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
