import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_response/core/design/palette.dart';
import 'package:health_response/core/theme/app_theme.dart';
import 'package:health_response/features/authentication/auth_controller.dart';
import 'package:health_response/features/authentication/auth_screens.dart';

class _RecordingAuth extends AuthController {
  static String? email;
  static String? password;

  @override
  Future<void> login(String e, String p) async {
    email = e;
    password = p;
    state = AuthState(
      AuthStatus.authenticated,
      user: CurrentUser(
        id: '1',
        email: e,
        fullName: 'Test',
        roles: const ['PATIENT'],
        permissions: const [],
      ),
    );
  }
}

Widget _app(ThemeData theme) => ProviderScope(
  overrides: [authControllerProvider.overrideWith(_RecordingAuth.new)],
  child: MaterialApp(theme: theme, home: const LoginScreen()),
);

void main() {
  for (final entry in {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  }.entries) {
    testWidgets(
      'sign-in button submits typed credentials (${entry.key} theme)',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1600);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        _RecordingAuth.email = null;
        await tester.pumpWidget(_app(entry.value));

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'patient@demo.test');
        await tester.enterText(fields.at(1), 'Health2026!');
        await tester.pump();

        // the label must be legible: its colour must differ strongly from the button fill
        final p = entry.value.extension<Palette>()!;
        final text = tester.widget<Text>(find.text('ចូលគណនី').last);
        expect(
          text.style!.color,
          isNot(equals(p.ink)),
          reason: 'label must not match the button fill',
        );

        await tester.tap(find.text('ចូលគណនី').last);
        await tester.pump();
        expect(_RecordingAuth.email, 'patient@demo.test');
        expect(_RecordingAuth.password, 'Health2026!');
      },
    );
  }

  testWidgets('invalid email blocks submission with a message', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    _RecordingAuth.email = null;
    await tester.pumpWidget(_app(AppTheme.light()));
    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'x');
    await tester.tap(find.text('ចូលគណនី').last);
    await tester.pump();
    expect(_RecordingAuth.email, isNull);
  });
}
