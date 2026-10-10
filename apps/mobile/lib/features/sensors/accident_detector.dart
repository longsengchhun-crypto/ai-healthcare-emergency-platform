import 'dart:math' as math;

/// One timestamped 3-axis reading (m/s² for accelerometer, rad/s for gyroscope).
class SensorSample {
  const SensorSample(this.x, this.y, this.z, this.at);
  final double x;
  final double y;
  final double z;
  final DateTime at;

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

class DetectorConfig {
  const DetectorConfig({
    this.impactThreshold = 22.0,
    this.rotationThreshold = 3.0,
    this.rotationWindow = const Duration(seconds: 3),
    this.inactivityDuration = const Duration(seconds: 5),
    this.stillAccelThreshold = 1.2,
    this.stillGyroThreshold = 0.35,
    this.candidateTimeout = const Duration(seconds: 12),
    this.smoothing = 0.3,
  });

  /// User-acceleration magnitude (gravity removed) that counts as a hard impact.
  final double impactThreshold;

  /// Angular speed that counts as a violent rotation.
  final double rotationThreshold;
  final Duration rotationWindow;
  final Duration inactivityDuration;
  final double stillAccelThreshold;
  final double stillGyroThreshold;

  /// How long after an impact we keep waiting for inactivity before giving up.
  final Duration candidateTimeout;

  /// Exponential smoothing factor applied to magnitudes used for the inactivity check.
  final double smoothing;
}

/// Evidence for a POSSIBLE incident. This is never a confirmed accident.
class IncidentCandidate {
  const IncidentCandidate({
    required this.detectedAt,
    required this.peakAcceleration,
    required this.peakRotation,
    required this.inactivitySeconds,
    required this.simulated,
  });

  final DateTime detectedAt;
  final double peakAcceleration;
  final double peakRotation;
  final int inactivitySeconds;
  final bool simulated;
}

enum _Stage { monitoring, awaitingInactivity }

/// Educational heuristic: sudden acceleration + rotation + subsequent inactivity.
/// A phone-only algorithm cannot reliably detect all accidents and will produce false positives
/// (dropped phone, gym, rough transport) and false negatives.
class AccidentDetector {
  AccidentDetector({this.config = const DetectorConfig()});

  final DetectorConfig config;

  _Stage _stage = _Stage.monitoring;
  DateTime? _impactAt;
  double _impactPeak = 0;
  double _rotationPeak = 0;
  DateTime? _lastRotationAt;
  DateTime? _stillSince;
  double _smoothedAccel = 0;
  double _smoothedGyro = 0;
  bool _simulated = false;

  bool get isAwaitingInactivity => _stage == _Stage.awaitingInactivity;

  void reset() {
    _stage = _Stage.monitoring;
    _impactAt = null;
    _impactPeak = 0;
    _rotationPeak = 0;
    _lastRotationAt = null;
    _stillSince = null;
    _simulated = false;
  }

  /// Feed gyroscope samples. Rotation is remembered so it can be matched to a nearby impact.
  void addGyroscope(SensorSample s) {
    final w = s.magnitude;
    _smoothedGyro =
        config.smoothing * w + (1 - config.smoothing) * _smoothedGyro;
    if (w >= config.rotationThreshold) {
      _rotationPeak = math.max(_rotationPeak, w);
      _lastRotationAt = s.at;
    }
  }

  /// Feed USER acceleration samples (gravity already removed). Returns a candidate when all
  /// three conditions have been met, otherwise null.
  IncidentCandidate? addAccelerometer(
    SensorSample s, {
    bool simulated = false,
  }) {
    final a = s.magnitude;
    _smoothedAccel =
        config.smoothing * a + (1 - config.smoothing) * _smoothedAccel;

    if (_stage == _Stage.monitoring) {
      if (a >= config.impactThreshold) {
        _impactAt = s.at;
        _impactPeak = a;
        _simulated = simulated;
        _stage = _Stage.awaitingInactivity;
        _stillSince = null;
      }
      return null;
    }

    // awaitingInactivity
    final impactAt = _impactAt!;
    if (s.at.difference(impactAt) > config.candidateTimeout) {
      reset();
      return null;
    }
    if (a > _impactPeak) _impactPeak = a;

    final rotationConfirmed =
        _lastRotationAt != null &&
        (_lastRotationAt!.difference(impactAt).abs() <= config.rotationWindow);
    final still =
        _smoothedAccel <= config.stillAccelThreshold &&
        _smoothedGyro <= config.stillGyroThreshold;

    if (!still) {
      _stillSince = null;
      return null;
    }
    _stillSince ??= s.at;
    final stillFor = s.at.difference(_stillSince!);
    if (stillFor >= config.inactivityDuration) {
      if (!rotationConfirmed) {
        // Impact without rotation: not enough evidence for a possible incident.
        reset();
        return null;
      }
      final candidate = IncidentCandidate(
        detectedAt: s.at,
        peakAcceleration: _impactPeak,
        peakRotation: _rotationPeak,
        inactivitySeconds: stillFor.inSeconds,
        simulated: _simulated || simulated,
      );
      reset();
      return candidate;
    }
    return null;
  }
}
