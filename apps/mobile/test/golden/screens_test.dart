// Renders the main screens with canned data to PNG so the design can be reviewed without a device.
// Regenerate: GOLDEN=1 flutter test --update-goldens test/golden/screens_test.dart
// Skipped by default: pixel output differs between operating systems, so it is a design aid, not a CI gate.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_response/core/data/cached_get.dart';
import 'package:health_response/core/i18n/language.dart';
import 'package:health_response/core/theme/app_theme.dart';
import 'package:health_response/features/appointments/appointments_screen.dart';
import 'package:health_response/features/authentication/auth_controller.dart';
import 'package:health_response/features/authentication/auth_screens.dart';
import 'package:health_response/features/doctor_directory/discover_screens.dart';
import 'package:health_response/features/emergency/emergency_controller.dart';
import 'package:health_response/features/emergency/emergency_screen.dart';
import 'package:health_response/features/medications/medications_screen.dart';
import 'package:health_response/features/notifications/notifications_screen.dart';
import 'package:health_response/features/patient_home/home_screen.dart';
import 'package:health_response/features/profile/medical_id_screen.dart';
import 'package:health_response/features/profile/profile_screen.dart';
import 'package:health_response/features/vitals/vitals_screen.dart';

class _FakeAuth extends AuthController {
  @override
  AuthState build() => AuthState(
    AuthStatus.authenticated,
    user: CurrentUser(
      id: 'u1',
      email: 'patient@demo.test',
      fullName: 'ស៊ុន ចាន់ថា',
      roles: const ['PATIENT'],
      permissions: const ['PROFILE_OWN', 'EMERGENCY_CREATE'],
    ),
  );
}

class _QuietEmergency extends EmergencyController {
  @override
  Future<void> restoreActive() async {}
}

Map<String, dynamic> _doctor(
  int i,
  String km,
  String latin,
  String spec,
  String specKm,
  String hospital,
) => {
  'id': 'd$i',
  'fullName': km,
  'nameLatin': latin,
  'specialty': spec,
  'specialtyKm': specKm,
  'bio': 'វេជ្ជបណ្ឌិតឯកទេស$specKm មានបទពិសោធន៍ ១២ ឆ្នាំ។',
  'bioEn': '$spec specialist.',
  'verificationStatus': 'UNVERIFIED',
  'demo': true,
  'hospitalName': hospital,
  'photoUrl': null,
  'yearsExperience': 10 + i,
  'languages': 'ខ្មែរ, English',
};

final _doctors = [
  _doctor(
    1,
    'វេជ្ជ. សុខ វិសាល',
    'Dr. Sok Visal',
    'Cardiology',
    'បេះដូង',
    'មន្ទីរពេទ្យទូទៅភ្នំពេញ (គំរូ)',
  ),
  _doctor(
    2,
    'វេជ្ជ. ចាន់ សុភាព',
    'Dr. Chan Sopheap',
    'General Practice',
    'វេជ្ជសាស្ត្រទូទៅ',
    'គ្លីនិកមិត្តភាព សៀមរាប (គំរូ)',
  ),
  _doctor(
    3,
    'វេជ្ជ. គង់ សុភ័ក្ត្រ',
    'Dr. Kong Sophak',
    'Pediatrics',
    'កុមារ',
    'មន្ទីរពេទ្យទូទៅភ្នំពេញ (គំរូ)',
  ),
  _doctor(
    4,
    'វេជ្ជ. ហេង រតនា',
    'Dr. Heng Rattana',
    'Orthopedics',
    'ឆ្អឹង និងសន្លាក់',
    'មន្ទីរពេទ្យខេត្តបាត់ដំបង (គំរូ)',
  ),
];

final _appointments = [
  {
    'id': 'a1',
    'patientId': 'p1',
    'patientName': 'ស៊ុន ចាន់ថា',
    'doctorId': 'd1',
    'doctorName': 'វេជ្ជ. សុខ វិសាល',
    'startsAt': DateTime.now()
        .add(const Duration(days: 2))
        .toUtc()
        .toIso8601String(),
    'endsAt': DateTime.now()
        .add(const Duration(days: 2, minutes: 30))
        .toUtc()
        .toIso8601String(),
    'status': 'CONFIRMED',
    'reason': 'តាមដានការព្យាបាល',
    'doctorPhotoUrl': null,
    'doctorSpecialty': 'Cardiology',
  },
  {
    'id': 'a2',
    'patientId': 'p1',
    'patientName': 'ស៊ុន ចាន់ថា',
    'doctorId': 'd3',
    'doctorName': 'វេជ្ជ. គង់ សុភ័ក្ត្រ',
    'startsAt': DateTime.now()
        .add(const Duration(days: 4))
        .toUtc()
        .toIso8601String(),
    'endsAt': DateTime.now()
        .add(const Duration(days: 4, minutes: 30))
        .toUtc()
        .toIso8601String(),
    'status': 'REQUESTED',
    'reason': 'ពិនិត្យសុខភាពទូទៅ',
    'doctorPhotoUrl': null,
    'doctorSpecialty': 'Pediatrics',
  },
];

Future<void> _loadFonts() async {
  final loader = FontLoader('NotoSansKhmer')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/NotoSansKhmer.ttf').readAsBytesSync(),
        ),
      ),
    );
  await loader.load();
}

Widget _app(Widget home) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith(_FakeAuth.new),
    emergencyControllerProvider.overrideWith(_QuietEmergency.new),
    appointmentsProvider.overrideWith(
      (ref) async =>
          _appointments.map((e) => Map<String, dynamic>.from(e)).toList(),
    ),
    remindersProvider.overrideWith(
      (ref) async => [
        {
          'id': 'r1',
          'medicationId': 'm1',
          'medicationName': 'Amlodipine',
          'timeOfDay': '07:30:00',
          'timezone': 'Asia/Phnom_Penh',
          'active': true,
        },
        {
          'id': 'r2',
          'medicationId': 'm2',
          'medicationName': 'Vitamin D',
          'timeOfDay': '20:00:00',
          'timezone': 'Asia/Phnom_Penh',
          'active': true,
        },
      ],
    ),
    notificationsProvider.overrideWith(
      (ref) async => {'items': [], 'unread': 2},
    ),
    doctorsProvider.overrideWith((ref, q) async => CachedResult(_doctors)),
    hospitalsProvider.overrideWith(
      (ref, q) async => CachedResult(<Map<String, dynamic>>[
        {
          'id': 'h1',
          'name': 'មន្ទីរពេទ្យទូទៅភ្នំពេញ (គំរូ)',
          'nameLatin': 'Phnom Penh General Hospital (Sample)',
          'city': 'Phnom Penh',
          'distanceKm': 2.4,
          'openingHours': '24 ម៉ោង / 24 hours',
          'photoUrl': null,
          'demo': true,
        },
        {
          'id': 'h2',
          'name': 'គ្លីនិកមិត្តភាព សៀមរាប (គំរូ)',
          'nameLatin': 'Siem Reap Friendship Clinic (Sample)',
          'city': 'Siem Reap',
          'openingHours': '07:00 – 19:00',
          'photoUrl': null,
          'demo': true,
        },
      ]),
    ),
    systemSettingsProvider.overrideWith(
      (ref) async => {
        'emergency.local_number': 'UNCONFIGURED',
        'emergency.disclaimer': '',
      },
    ),
    emergencyHistoryProvider.overrideWith((ref) async => []),
    profileProvider.overrideWith(
      (ref) async => {
        'fullName': 'ស៊ុន ចាន់ថា',
        'dateOfBirth': '1991-06-14',
        'bloodGroup': 'O+',
        'allergies': 'ប៉េនីស៊ីលីន (Penicillin)',
        'conditions': 'លើសសម្ពាធឈាម',
      },
    ),
    contactsProvider.overrideWith(
      (ref) async => [
        {
          'id': 'c1',
          'name': 'ស៊ុន សុភា',
          'relationship': 'ប្តី',
          'phone': '+855 12 345 678',
        },
      ],
    ),
    medicationsProvider.overrideWith(
      (ref) async => [
        {
          'id': 'm1',
          'name': 'Amlodipine',
          'dosage': '5 mg',
          'source': 'PRESCRIPTION',
        },
      ],
    ),
    vitalsSummaryProvider.overrideWith((ref) async => []),
    vitalsSeriesProvider.overrideWith((ref, type) async {
      final now = DateTime.now();
      final bp = [
        for (var i = 0; i < 9; i++)
          {
            'id': 'v$i',
            'type': 'BLOOD_PRESSURE',
            'value1': [148, 142, 138, 135, 140, 132, 128, 131, 126][i],
            'value2': [94, 92, 90, 88, 91, 86, 84, 85, 82][i],
            'unit': 'mmHg',
            'note': i == 0 ? 'ក្រោយអាហារព្រឹក' : null,
            'measuredAt': now
                .subtract(Duration(days: i * 3))
                .toUtc()
                .toIso8601String(),
            'level': 'ATTENTION',
            'code': 'BP_HIGH',
          },
      ];
      return bp;
    }),
    contactsProvider.overrideWith((ref) async => []),
    medicationsProvider.overrideWith(
      (ref) async => [
        {
          'id': 'm1',
          'name': 'Amlodipine',
          'dosage': '5 mg',
          'instructions': 'ថ្ងៃម្តង ពេលព្រឹក / once daily',
          'source': 'PRESCRIPTION',
        },
        {
          'id': 'm2',
          'name': 'Vitamin D',
          'dosage': '1000 IU',
          'instructions': null,
          'source': 'USER_ENTERED',
        },
      ],
    ),
  ],
  child: LanguageScope(
    controller: languageController,
    child: MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: home,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (Platform.environment['GOLDEN'] != '1') {
    test(
      'golden screens (set GOLDEN=1 to render)',
      () {},
      skip: 'design preview only',
    );
    return;
  }

  setUpAll(() async {
    await _loadFonts();
  });

  Future<void> shot(
    WidgetTester t,
    String name,
    Widget w, {
    bool english = false,
  }) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await languageController.set(english ? 'en' : 'km');
    await t.pumpWidget(_app(w));
    await t.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/$name.png'),
    );
  }

  testWidgets('home (khmer)', (t) => shot(t, 'home_km', const HomeScreen()));
  testWidgets(
    'home (english)',
    (t) => shot(t, 'home_en', const HomeScreen(), english: true),
  );
  testWidgets(
    'discover',
    (t) => shot(t, 'discover_km', const DiscoverScreen()),
  );
  testWidgets(
    'appointments',
    (t) => shot(t, 'appointments_km', const AppointmentsScreen()),
  );
  testWidgets(
    'emergency',
    (t) => shot(t, 'emergency_km', const EmergencyScreen()),
  );
  testWidgets('profile', (t) => shot(t, 'profile_km', const ProfileScreen()));
  testWidgets('login', (t) => shot(t, 'login_km', const LoginScreen()));
  testWidgets(
    'medications',
    (t) => shot(t, 'medications_km', const MedicationsScreen(), english: false),
  );
  testWidgets('vitals', (t) => shot(t, 'vitals_km', const VitalsScreen()));
  testWidgets(
    'vitals english',
    (t) => shot(t, 'vitals_en', const VitalsScreen(), english: true),
  );
  testWidgets(
    'medical id',
    (t) => shot(t, 'medical_id_km', const MedicalIdScreen()),
  );
}
