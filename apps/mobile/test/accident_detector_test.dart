import 'package:flutter_test/flutter_test.dart';
import 'package:health_response/features/sensors/accident_detector.dart';

SensorSample s(double x, double y, double z, DateTime t) =>
    SensorSample(x, y, z, t);

void main() {
  final t0 = DateTime(2026, 1, 1, 12);

  group('AccidentDetector', () {
    test('impact + rotation + stillness yields a possible incident', () {
      final d = AccidentDetector();
      d.addGyroscope(s(4.5, 0, 0, t0));
      expect(d.addAccelerometer(s(30, 0, 0, t0)), isNull);
      IncidentCandidate? c;
      for (var i = 1; i <= 100 && c == null; i++) {
        final t = t0.add(Duration(milliseconds: 100 * i));
        d.addGyroscope(s(0.02, 0.02, 0.02, t)); // gyroscope keeps streaming
        c = d.addAccelerometer(s(0.1, 0.1, 0.1, t));
      }
      expect(c, isNotNull);
      expect(c!.peakAcceleration, greaterThanOrEqualTo(30));
      expect(c.inactivitySeconds, greaterThanOrEqualTo(5));
      expect(c.simulated, isFalse);
    });

    test('impact without rotation is not a candidate', () {
      final d = AccidentDetector();
      d.addAccelerometer(s(30, 0, 0, t0));
      IncidentCandidate? c;
      for (var i = 1; i <= 100; i++) {
        c ??= d.addAccelerometer(
          s(0.1, 0.1, 0.1, t0.add(Duration(milliseconds: 100 * i))),
        );
      }
      expect(c, isNull);
    });

    test('continued movement after impact cancels the candidate', () {
      final d = AccidentDetector();
      d.addGyroscope(s(5, 0, 0, t0));
      d.addAccelerometer(s(30, 0, 0, t0));
      IncidentCandidate? c;
      for (var i = 1; i <= 120; i++) {
        // person keeps moving: magnitude ~6 m/s^2
        c ??= d.addAccelerometer(
          s(6, 0, 0, t0.add(Duration(milliseconds: 100 * i))),
        );
      }
      expect(c, isNull);
    });

    test('ordinary walking never triggers', () {
      final d = AccidentDetector();
      IncidentCandidate? c;
      for (var i = 0; i < 600; i++) {
        c ??= d.addAccelerometer(
          s(3, 2, 1, t0.add(Duration(milliseconds: 50 * i))),
        );
      }
      expect(c, isNull);
    });
  });
}
