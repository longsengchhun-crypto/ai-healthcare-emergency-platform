import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_response/core/theme/app_theme.dart';
import 'package:health_response/features/medications/medications_screen.dart';
import 'package:health_response/features/profile/medical_id_screen.dart';
import 'package:health_response/features/profile/profile_screen.dart';
import 'package:health_response/features/vitals/vitals_screen.dart';

Map<String, dynamic> _reading(
  String type,
  num v1,
  num? v2,
  String level,
  String code,
) => {
  'id': '$type-$v1',
  'type': type,
  'value1': v1,
  'value2': v2,
  'unit': type == 'BLOOD_PRESSURE' ? 'mmHg' : 'bpm',
  'note': null,
  'measuredAt': DateTime.now().toUtc().toIso8601String(),
  'level': level,
  'code': code,
};

Widget _app(List<Override> overrides, Widget home) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(theme: AppTheme.light(), home: home),
);

void main() {
  test('formatVital shows both blood pressure numbers and trims decimals', () {
    expect(formatVital({'value1': 118, 'value2': 76}), '118/76');
    expect(formatVital({'value1': 72.0, 'value2': null}), '72');
    expect(formatVital({'value1': 36.6, 'value2': null}), '36.6');
  });

  testWidgets('vitals screen shows the latest value, level and guidance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final data = [
      _reading('BLOOD_PRESSURE', 150, 95, 'ATTENTION', 'BP_HIGH'),
      _reading('BLOOD_PRESSURE', 118, 76, 'NORMAL', 'WITHIN_TYPICAL'),
    ];
    await tester.pumpWidget(
      _app([
        vitalsSeriesProvider.overrideWith((ref, type) async => data),
        vitalsSummaryProvider.overrideWith((ref) async => const []),
      ], const VitalsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('150/95'), findsOneWidget);
    expect(find.textContaining('118/76'), findsWidgets); // in the history list
    expect(
      find.textContaining('ខ្ពស់ជាងធម្មតា'),
      findsOneWidget,
    ); // advice notice
  });

  testWidgets('vitals screen invites the first reading when there is none', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app([
        vitalsSeriesProvider.overrideWith((ref, type) async => const []),
        vitalsSummaryProvider.overrideWith((ref) async => const []),
      ], const VitalsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('មិនទាន់មានលទ្ធផល'), findsOneWidget);
  });

  testWidgets('urgent reading is flagged and add sheet validates input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app([
        vitalsSeriesProvider.overrideWith(
          (ref, type) async => [
            _reading('BLOOD_PRESSURE', 190, 125, 'URGENT', 'BP_VERY_HIGH'),
          ],
        ),
        vitalsSummaryProvider.overrideWith((ref) async => const []),
      ], const VitalsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ជំនួយបន្ទាន់'), findsWidgets);

    await tester.tap(find.text('កត់ត្រាលទ្ធផល'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('រក្សាទុក'));
    await tester.pumpAndSettle();
    expect(find.text('សូមបញ្ចូលលេខឲ្យត្រឹមត្រូវ។'), findsOneWidget);
  });

  testWidgets('medical ID lists allergies and warns about missing data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app([
        profileProvider.overrideWith(
          (ref) async => {
            'fullName': 'Sok Dara',
            'dateOfBirth': '1990-04-02',
            'bloodGroup': 'O+',
            'allergies': 'Penicillin',
            'conditions': null,
          },
        ),
        contactsProvider.overrideWith((ref) async => const []),
        medicationsProvider.overrideWith(
          (ref) async => [
            {'name': 'Metformin', 'dosage': '500 mg'},
          ],
        ),
      ], const MedicalIdScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sok Dara'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('Metformin · 500 mg'), findsOneWidget);
    expect(find.textContaining('ព័ត៌មានដែលនៅខ្វះ'), findsOneWidget);
  });
}
