import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';
import '../location/location_service.dart';
import 'emergency_models.dart';

final locationProviderProvider = Provider<LocationProvider>(
  (ref) => DeviceLocationProvider(),
);

enum EmergencyPhase {
  idle,
  locating,
  submitting,

  /// The backend persisted the event and returned it; [EmergencyState.event] is authoritative.
  active,

  /// The request could NOT be confirmed by the backend. Nothing is claimed as sent.
  failed,
}

class EmergencyState {
  const EmergencyState({
    this.phase = EmergencyPhase.idle,
    this.event,
    this.error,
    this.location,
    this.pendingKey,
    this.lastSyncAt,
    this.stale = false,
  });

  final EmergencyPhase phase;
  final EmergencyEvent? event;
  final AppException? error;
  final LocationResult? location;

  /// Idempotency key reused across retries of the same user action.
  final String? pendingKey;
  final DateTime? lastSyncAt;

  /// True when the last status refresh failed: the shown status may be out of date.
  final bool stale;

  EmergencyState copyWith({
    EmergencyPhase? phase,
    EmergencyEvent? event,
    AppException? error,
    LocationResult? location,
    String? pendingKey,
    DateTime? lastSyncAt,
    bool? stale,
    bool clearError = false,
    bool clearEvent = false,
    bool clearKey = false,
  }) => EmergencyState(
    phase: phase ?? this.phase,
    event: clearEvent ? null : (event ?? this.event),
    error: clearError ? null : (error ?? this.error),
    location: location ?? this.location,
    pendingKey: clearKey ? null : (pendingKey ?? this.pendingKey),
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    stale: stale ?? this.stale,
  );
}

class EmergencyController extends Notifier<EmergencyState> {
  Timer? _poll;

  @override
  EmergencyState build() {
    ref.onDispose(() => _poll?.cancel());
    return const EmergencyState();
  }

  /// Triggers an emergency. The same idempotency key is reused until the backend confirms,
  /// so retrying after a timeout can never create a second event.
  Future<void> activate({
    bool demo = false,
    String trigger = 'MANUAL',
    String? description,
  }) async {
    if (state.phase == EmergencyPhase.locating ||
        state.phase == EmergencyPhase.submitting) {
      return;
    }
    final key = state.pendingKey ?? const Uuid().v4();
    state = state.copyWith(
      phase: EmergencyPhase.locating,
      pendingKey: key,
      clearError: true,
    );

    final location = await ref
        .read(locationProviderProvider)
        .current()
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () => const LocationResult(LocationStatus.timeout),
        );
    state = state.copyWith(
      phase: EmergencyPhase.submitting,
      location: location,
    );

    try {
      final res = await ref
          .read(apiClientProvider)
          .post(
            '/emergencies',
            headers: {'Idempotency-Key': key},
            body: {
              'demo': demo,
              'triggerSource': trigger,
              'description': ?description,
              if (location.hasFix) ...{
                'latitude': location.latitude,
                'longitude': location.longitude,
                'accuracyMeters': location.accuracyMeters,
              },
            },
          );
      final event = EmergencyEvent.fromJson(res as Map<String, dynamic>);
      state = state.copyWith(
        phase: EmergencyPhase.active,
        event: event,
        lastSyncAt: DateTime.now(),
        stale: false,
        clearKey: true,
        clearError: true,
      );
      _startPolling();
    } on AppException catch (e) {
      state = state.copyWith(phase: EmergencyPhase.failed, error: e);
    }
  }

  Future<void> refresh() async {
    final id = state.event?.id;
    if (id == null) return;
    try {
      final res = await ref.read(apiClientProvider).get('/emergencies/$id');
      final event = EmergencyEvent.fromJson(res as Map<String, dynamic>);
      state = state.copyWith(
        event: event,
        lastSyncAt: DateTime.now(),
        stale: false,
      );
      if (event.isTerminal) _poll?.cancel();
    } on AppException {
      // Keep the last confirmed status but flag it as possibly outdated.
      state = state.copyWith(stale: true);
    }
  }

  Future<void> cancel({String? note}) async {
    final id = state.event?.id;
    if (id == null) return;
    try {
      final res = await ref
          .read(apiClientProvider)
          .post(
            '/emergencies/$id/cancel',
            body: {'note': note ?? 'Cancelled by patient'},
          );
      state = state.copyWith(
        event: EmergencyEvent.fromJson(res as Map<String, dynamic>),
        lastSyncAt: DateTime.now(),
        stale: false,
      );
      _poll?.cancel();
    } on AppException catch (e) {
      state = state.copyWith(error: e);
    }
  }

  /// Restores an in-progress event after app restart.
  Future<void> restoreActive() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/emergencies', query: {'limit': 5});
      final events = [
        for (final e in res as List)
          EmergencyEvent.fromJson(e as Map<String, dynamic>),
      ];
      final active = events.where((e) => !e.isTerminal).toList();
      if (active.isNotEmpty) {
        state = state.copyWith(
          phase: EmergencyPhase.active,
          event: active.first,
          lastSyncAt: DateTime.now(),
          stale: false,
        );
        _startPolling();
      }
    } on AppException {
      // Silent: the Emergency screen shows its own history load state.
    }
  }

  void dismiss() {
    _poll?.cancel();
    state = const EmergencyState();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }
}

final emergencyControllerProvider =
    NotifierProvider<EmergencyController, EmergencyState>(
      EmergencyController.new,
    );

final emergencyHistoryProvider =
    FutureProvider.autoDispose<List<EmergencyEvent>>((ref) async {
      final res = await ref
          .read(apiClientProvider)
          .get('/emergencies', query: {'limit': 20});
      return [
        for (final e in res as List)
          EmergencyEvent.fromJson(e as Map<String, dynamic>),
      ];
    });
