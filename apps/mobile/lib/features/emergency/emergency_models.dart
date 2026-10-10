class EmergencyHistoryEntry {
  EmergencyHistoryEntry({
    required this.fromStatus,
    required this.toStatus,
    required this.note,
    required this.at,
  });

  factory EmergencyHistoryEntry.fromJson(Map<String, dynamic> j) =>
      EmergencyHistoryEntry(
        fromStatus: j['fromStatus'] as String?,
        toStatus: j['toStatus'] as String,
        note: j['note'] as String?,
        at: DateTime.parse(j['at'] as String).toLocal(),
      );

  final String? fromStatus;
  final String toStatus;
  final String? note;
  final DateTime at;
}

class EmergencyEvent {
  EmergencyEvent({
    required this.id,
    required this.status,
    required this.demo,
    required this.createdAt,
    required this.updatedAt,
    required this.history,
    required this.responders,
    required this.disclaimer,
    this.latitude,
    this.longitude,
  });

  factory EmergencyEvent.fromJson(Map<String, dynamic> j) {
    final loc = j['location'] as Map<String, dynamic>?;
    return EmergencyEvent(
      id: j['id'] as String,
      status: j['status'] as String,
      demo: (j['demo'] as bool?) ?? false,
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(j['updatedAt'] as String).toLocal(),
      history: [
        for (final h in (j['history'] as List? ?? const []))
          EmergencyHistoryEntry.fromJson(h as Map<String, dynamic>),
      ],
      responders: [
        for (final a in (j['assignments'] as List? ?? const []))
          (a as Map<String, dynamic>)['responderName'] as String,
      ],
      disclaimer: (j['disclaimer'] as String?) ?? '',
      latitude: (loc?['latitude'] as num?)?.toDouble(),
      longitude: (loc?['longitude'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String status;
  final bool demo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<EmergencyHistoryEntry> history;
  final List<String> responders;
  final String disclaimer;
  final double? latitude;
  final double? longitude;

  bool get isTerminal =>
      const {'RESOLVED', 'CANCELLED', 'REJECTED', 'FAILED'}.contains(status);

  bool get canCancel => const {
    'SUBMITTED',
    'ACKNOWLEDGED',
    'RESPONDER_ASSIGNED',
    'RESPONDER_EN_ROUTE',
  }.contains(status);
}

/// Plain-language description of a backend status. These describe what staff have actually recorded:
/// SUBMITTED is not the same as help being on the way.
String describeEmergencyStatus(String status) {
  switch (status) {
    case 'CREATED':
      return 'Request saved';
    case 'SUBMITTED':
      return 'Sent to the response queue. Waiting for a person to acknowledge it.';
    case 'ACKNOWLEDGED':
      return 'Acknowledged by hospital staff.';
    case 'RESPONDER_ASSIGNED':
      return 'A responder has been assigned.';
    case 'RESPONDER_EN_ROUTE':
      return 'A responder is on the way (as recorded by staff).';
    case 'ARRIVED':
      return 'A responder has arrived (as recorded by staff).';
    case 'RESOLVED':
      return 'Resolved.';
    case 'CANCELLED':
      return 'Cancelled.';
    case 'REJECTED':
      return 'Rejected by staff. Please contact emergency services directly.';
    case 'FAILED':
      return 'Could not be processed. Please contact emergency services directly.';
    default:
      return status;
  }
}
