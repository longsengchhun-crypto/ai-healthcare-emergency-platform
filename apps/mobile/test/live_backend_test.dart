// Contract test: runs the real ApiClient and response models against a running backend.
// Skipped unless LIVE_API_URL is set, e.g.
//   LIVE_API_URL=http://localhost:18080 flutter test test/live_backend_test.dart
// The backend must be started with SEED_DEMO_DATA=true and SEED_DEMO_PASSWORD=Demo-Password-123.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_response/core/errors/app_exception.dart';
import 'package:health_response/core/network/api_client.dart';
import 'package:health_response/core/storage/token_storage.dart';
import 'package:health_response/features/authentication/auth_controller.dart';
import 'package:health_response/features/emergency/emergency_models.dart';

class _MemoryTokens implements TokenStorage {
  String? access;
  String? refresh;
  @override
  Future<String?> readAccess() async => access;
  @override
  Future<String?> readRefresh() async => refresh;
  @override
  Future<void> save({required String access, required String refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

Future<ApiClient> _login(String base, String email) async {
  final tokens = _MemoryTokens();
  final api = ApiClient(tokens: tokens, baseUrl: base, onSessionExpired: () {});
  final res = await api.post(
    '/auth/login',
    body: {'email': email, 'password': 'Demo-Password-123'},
    skipAuth: true,
  );
  await tokens.save(
    access: res['accessToken'] as String,
    refresh: res['refreshToken'] as String,
  );
  return api;
}

void main() {
  final base = Platform.environment['LIVE_API_URL'];

  test('mobile client and models work end to end against the backend', () async {
    final patient = await _login(base!, 'patient.demo@example.test');
    final doctor = await _login(base, 'doctor.demo@example.test');
    final staff = await _login(base, 'staff.demo@example.test');

    final me = CurrentUser.fromJson(
      await patient.get('/users/me') as Map<String, dynamic>,
    );
    expect(me.isPatient, isTrue);
    expect(me.fullName, 'Demo Patient');

    // directory + booking
    final doctors = await patient.get('/doctors', query: {'q': 'Cardio'});
    final doctorId = (doctors['items'] as List).first['id'] as String;
    DateTime? slot;
    for (var d = 1; d < 10 && slot == null; d++) {
      final day = DateTime.now().add(Duration(days: d));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final slots = await patient.get(
        '/doctors/$doctorId/slots',
        query: {'date': key},
      );
      if ((slots as List).isNotEmpty) {
        slot = DateTime.parse(slots[5]['startsAt'] as String);
      }
    }
    final appt = await patient.post(
      '/appointments',
      body: {'doctorId': doctorId, 'startsAt': slot!.toUtc().toIso8601String()},
    );
    expect(appt['status'], 'REQUESTED');
    await doctor.post('/appointments/${appt['id']}/confirm');
    final fetched = await patient.get('/appointments/${appt['id']}');
    expect(fetched['status'], 'CONFIRMED');

    // double booking surfaces as a conflict AppException
    await expectLater(
      patient.post(
        '/appointments',
        body: {
          'doctorId': doctorId,
          'startsAt': slot.toUtc().toIso8601String(),
        },
      ),
      throwsA(
        isA<AppException>().having((e) => e.kind, 'kind', ErrorKind.conflict),
      ),
    );

    // emergency, with idempotent retry
    const key = 'live-test-key-0001';
    final body = {'demo': true, 'latitude': 11.56, 'longitude': 104.93};
    final created = EmergencyEvent.fromJson(
      await patient.post(
        '/emergencies',
        headers: {'Idempotency-Key': key},
        body: body,
      ) as Map<String, dynamic>,
    );
    final retry = EmergencyEvent.fromJson(
      await patient.post(
        '/emergencies',
        headers: {'Idempotency-Key': key},
        body: body,
      ) as Map<String, dynamic>,
    );
    expect(retry.id, created.id);
    expect(created.status, 'SUBMITTED');
    expect(created.latitude, closeTo(11.56, 0.001));

    await staff.post('/emergencies/${created.id}/acknowledge');
    final updated = EmergencyEvent.fromJson(
      await patient.get('/emergencies/${created.id}') as Map<String, dynamic>,
    );
    expect(updated.status, 'ACKNOWLEDGED');
    expect(updated.history.length, greaterThanOrEqualTo(4));

    // patient cannot drive staff transitions
    await expectLater(
      patient.post('/emergencies/${created.id}/acknowledge'),
      throwsA(
        isA<AppException>().having((e) => e.kind, 'kind', ErrorKind.forbidden),
      ),
    );

    // triage red flag
    final triage = await patient.post(
      '/ai/triage',
      body: {'symptoms': 'severe chest pain and shortness of breath'},
    );
    expect(triage['urgency'], 'EMERGENCY');
    expect(triage['emergencyActionRecommended'], isTrue);
  }, skip: base == null ? 'LIVE_API_URL not set' : false);
}
