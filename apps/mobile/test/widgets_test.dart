import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_response/core/errors/app_exception.dart';
import 'package:health_response/core/widgets/state_views.dart';
import 'package:health_response/features/authentication/auth_screens.dart';
import 'package:health_response/features/emergency/emergency_models.dart';
import 'package:health_response/features/emergency/hold_to_confirm_button.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email('a@b.co'), isNull);
    });
    test('password needs 10 characters', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('long-enough-1'), isNull);
    });
    test('phone is optional but validated', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('abc'), isNotNull);
      expect(Validators.phone('+855 12 345 678'), isNull);
    });
  });

  group('HoldToConfirmButton', () {
    testWidgets('does not fire on a quick tap', (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoldToConfirmButton(onConfirmed: () => fired++),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(HoldToConfirmButton));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(fired, 0);
    });

    testWidgets('fires after a sustained hold', (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoldToConfirmButton(onConfirmed: () => fired++),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToConfirmButton)),
      );
      await tester.pump(const Duration(milliseconds: 150)); // press timeout
      await tester.pump(); // first frame starts the ticker
      await tester.pump(const Duration(milliseconds: 2000));
      await gesture.up();
      await tester.pump();
      expect(fired, 1);
    });

    testWidgets('does not fire when disabled', (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoldToConfirmButton(
                enabled: false,
                onConfirmed: () => fired++,
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToConfirmButton)),
      );
      await tester.pump(const Duration(milliseconds: 2500));
      await gesture.up();
      expect(fired, 0);
    });
  });

  group('State views', () {
    testWidgets('error view shows message and retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              error: AppException(
                ErrorKind.offline,
                'You appear to be offline.',
              ),
              onRetry: () => retried = true,
            ),
          ),
        ),
      );
      expect(find.text('You appear to be offline.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });

    testWidgets('empty view', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyView(icon: Icons.inbox, title: 'Nothing here'),
          ),
        ),
      );
      expect(find.text('Nothing here'), findsOneWidget);
    });
  });

  group('Emergency status wording', () {
    test('submitted is never described as help on the way', () {
      expect(
        describeEmergencyStatus('SUBMITTED'),
        isNot(contains('on the way')),
      );
      expect(describeEmergencyStatus('SUBMITTED'), contains('Waiting'));
    });
    test('terminal and cancel flags', () {
      final e = EmergencyEvent.fromJson({
        'id': '1',
        'status': 'SUBMITTED',
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
      });
      expect(e.isTerminal, isFalse);
      expect(e.canCancel, isTrue);
    });
  });
}
