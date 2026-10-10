import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';
import '../emergency/emergency_controller.dart';
import 'accident_detector.dart';

enum SensorAvailability { unknown, available, unavailable }

class SensorSettings {
  const SensorSettings({
    this.monitoringEnabled = false,
    this.autoDispatchEnabled = false,
    this.countdownSeconds = 20,
  });

  final bool monitoringEnabled;

  /// Separate explicit opt-in: only then may an expired countdown create an emergency event.
  final bool autoDispatchEnabled;
  final int countdownSeconds;

  SensorSettings copyWith({
    bool? monitoringEnabled,
    bool? autoDispatchEnabled,
    int? countdownSeconds,
  }) => SensorSettings(
    monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
    autoDispatchEnabled: autoDispatchEnabled ?? this.autoDispatchEnabled,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
  );
}

class SensorState {
  const SensorState({
    this.settings = const SensorSettings(),
    this.availability = SensorAvailability.unknown,
    this.candidate,
    this.remaining = 0,
    this.message,
  });

  final SensorSettings settings;
  final SensorAvailability availability;
  final IncidentCandidate? candidate;
  final int remaining;
  final String? message;

  SensorState copyWith({
    SensorSettings? settings,
    SensorAvailability? availability,
    IncidentCandidate? candidate,
    int? remaining,
    String? message,
    bool clearCandidate = false,
    bool clearMessage = false,
  }) => SensorState(
    settings: settings ?? this.settings,
    availability: availability ?? this.availability,
    candidate: clearCandidate ? null : (candidate ?? this.candidate),
    remaining: remaining ?? this.remaining,
    message: clearMessage ? null : (message ?? this.message),
  );
}

class SensorController extends Notifier<SensorState> {
  final AccidentDetector _detector = AccidentDetector();
  StreamSubscription<dynamic>? _accelSub;
  StreamSubscription<dynamic>? _gyroSub;
  Timer? _countdown;
  final List<Map<String, dynamic>> _recent = [];

  @override
  SensorState build() {
    ref.onDispose(_stopStreams);
    return const SensorState();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SensorSettings(
      monitoringEnabled: prefs.getBool('sensor.enabled') ?? false,
      autoDispatchEnabled: prefs.getBool('sensor.autodispatch') ?? false,
      countdownSeconds: prefs.getInt('sensor.countdown') ?? 20,
    );
    state = state.copyWith(settings: settings);
    if (settings.monitoringEnabled) _startStreams();
  }

  Future<void> setMonitoring(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sensor.enabled', enabled);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/consents',
            body: {'purpose': 'SENSOR_MONITORING', 'granted': enabled},
          );
    } on AppException {
      // Local preference still applies; server record is best-effort.
    }
    var settings = state.settings.copyWith(monitoringEnabled: enabled);
    if (!enabled) {
      // Turning monitoring off also withdraws the auto-dispatch opt-in.
      await prefs.setBool('sensor.autodispatch', false);
      settings = settings.copyWith(autoDispatchEnabled: false);
      _stopStreams();
    }
    state = state.copyWith(settings: settings);
    if (enabled) _startStreams();
  }

  Future<void> setAutoDispatch(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sensor.autodispatch', enabled);
    state = state.copyWith(
      settings: state.settings.copyWith(autoDispatchEnabled: enabled),
    );
  }

  Future<void> setCountdown(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = seconds.clamp(10, 60);
    await prefs.setInt('sensor.countdown', clamped);
    state = state.copyWith(
      settings: state.settings.copyWith(countdownSeconds: clamped),
    );
  }

  void _startStreams() {
    _stopStreams();
    try {
      _accelSub =
          userAccelerometerEventStream(
            samplingPeriod: SensorInterval.normalInterval,
          ).listen(
            (e) {
              final sample = SensorSample(e.x, e.y, e.z, DateTime.now());
              _remember('ACCELEROMETER', sample);
              final c = _detector.addAccelerometer(sample);
              if (c != null) _onCandidate(c);
            },
            onError: (_) {
              state = state.copyWith(
                availability: SensorAvailability.unavailable,
              );
            },
          );
      _gyroSub =
          gyroscopeEventStream(samplingPeriod: SensorInterval.normalInterval)
              .listen(
                (e) {
                  final sample = SensorSample(e.x, e.y, e.z, DateTime.now());
                  _remember('GYROSCOPE', sample);
                  _detector.addGyroscope(sample);
                },
                onError: (_) {
                  state = state.copyWith(
                    availability: SensorAvailability.unavailable,
                  );
                },
              );
      state = state.copyWith(availability: SensorAvailability.available);
    } catch (_) {
      state = state.copyWith(availability: SensorAvailability.unavailable);
    }
  }

  void _stopStreams() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
  }

  void _remember(String sensor, SensorSample s) {
    _recent.add({
      'sensor': sensor,
      'x': s.x,
      'y': s.y,
      'z': s.z,
      'recordedAt': s.at.toUtc().toIso8601String(),
    });
    if (_recent.length > 40) _recent.removeAt(0);
  }

  /// Demonstration mode: feeds a synthetic impact + rotation + stillness sequence through the real detector.
  /// The resulting candidate is flagged simulated and is never presented as a detected accident.
  void simulateIncident() {
    final t0 = DateTime.now();
    _detector.reset();
    _detector.addGyroscope(SensorSample(4.5, 0, 0, t0));
    _detector.addAccelerometer(SensorSample(30, 5, 5, t0), simulated: true);
    IncidentCandidate? candidate;
    for (var i = 1; i <= 80 && candidate == null; i++) {
      final t = t0.add(Duration(milliseconds: 100 * i));
      _detector.addGyroscope(SensorSample(0.02, 0.02, 0.02, t));
      candidate = _detector.addAccelerometer(
        SensorSample(0.1, 0.1, 0.1, t),
        simulated: true,
      );
    }
    _onCandidate(
      candidate ??
          IncidentCandidate(
            detectedAt: t0,
            peakAcceleration: 30,
            peakRotation: 4.5,
            inactivitySeconds: 5,
            simulated: true,
          ),
    );
  }

  void _onCandidate(IncidentCandidate c) {
    if (state.candidate != null) return;
    state = state.copyWith(
      candidate: c,
      remaining: state.settings.countdownSeconds,
      clearMessage: true,
    );
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.remaining - 1;
      if (left <= 0) {
        t.cancel();
        _expire();
      } else {
        state = state.copyWith(remaining: left);
      }
    });
  }

  Future<void> confirmSafe() async {
    final c = state.candidate;
    _countdown?.cancel();
    state = state.copyWith(
      clearCandidate: true,
      remaining: 0,
      message: 'Glad you are OK. No alert was sent.',
    );
    if (c != null) await _record(c, 'USER_SAFE');
  }

  Future<void> requestHelpNow() async {
    final c = state.candidate;
    _countdown?.cancel();
    state = state.copyWith(clearCandidate: true, remaining: 0);
    if (c == null) return;
    await ref
        .read(emergencyControllerProvider.notifier)
        .activate(trigger: 'SENSOR_COUNTDOWN', demo: c.simulated);
    await _record(
      c,
      'EMERGENCY_CREATED',
      emergencyId: ref.read(emergencyControllerProvider).event?.id,
    );
  }

  Future<void> _expire() async {
    final c = state.candidate;
    if (c == null) return;
    if (state.settings.autoDispatchEnabled) {
      await requestHelpNow();
    } else {
      state = state.copyWith(
        clearCandidate: true,
        remaining: 0,
        message:
            'The countdown ended. Automatic alerts are turned off, so nothing was sent. '
            'Use the Emergency tab if you need help.',
      );
      await _record(c, 'COUNTDOWN_EXPIRED_NOT_ENABLED');
    }
  }

  Future<void> _record(
    IncidentCandidate c,
    String outcome, {
    String? emergencyId,
  }) async {
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/sensor-events',
            body: {
              'simulated': c.simulated,
              'peakAcceleration': c.peakAcceleration,
              'rotationRate': c.peakRotation,
              'inactivitySeconds': c.inactivitySeconds,
              'outcome': outcome,
              'emergencyEventId': emergencyId,
              'detectedAt': c.detectedAt.toUtc().toIso8601String(),
              'readings': c.simulated
                  ? <Map<String, dynamic>>[]
                  : List.of(_recent),
            },
          );
    } on AppException {
      // Evidence upload is best-effort and must never block the safety flow.
    }
  }
}

final sensorControllerProvider =
    NotifierProvider<SensorController, SensorState>(SensorController.new);
