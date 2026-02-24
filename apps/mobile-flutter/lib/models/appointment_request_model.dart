import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of an appointment request
enum AppointmentRequestStatus {
  /// Waiting for receptionist to review
  pending,

  /// Receptionist confirmed the appointment (booked externally)
  confirmed,

  /// Receptionist denied the request
  denied,

  /// Pet owner cancelled/retracted the request
  cancelled,
}

/// Preferred time of day for the appointment
enum TimePreference {
  /// Any time works
  anyTime,

  /// Morning: 8am - 12pm
  morning,

  /// Afternoon: 12pm - 5pm
  afternoon,

  /// Evening: 5pm - 8pm
  evening,
}

/// Extension to get display text for TimePreference
extension TimePreferenceExtension on TimePreference {
  String get displayText {
    switch (this) {
      case TimePreference.anyTime:
        return 'Any time';
      case TimePreference.morning:
        return 'Morning (8am - 12pm)';
      case TimePreference.afternoon:
        return 'Afternoon (12pm - 5pm)';
      case TimePreference.evening:
        return 'Evening (5pm - 8pm)';
    }
  }

  String get shortText {
    switch (this) {
      case TimePreference.anyTime:
        return 'Any time';
      case TimePreference.morning:
        return 'Morning';
      case TimePreference.afternoon:
        return 'Afternoon';
      case TimePreference.evening:
        return 'Evening';
    }
  }
}

/// Extension to get display text for AppointmentRequestStatus
extension AppointmentRequestStatusExtension on AppointmentRequestStatus {
  String get displayText {
    switch (this) {
      case AppointmentRequestStatus.pending:
        return 'Pending';
      case AppointmentRequestStatus.confirmed:
        return 'Confirmed';
      case AppointmentRequestStatus.denied:
        return 'Denied';
      case AppointmentRequestStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Model representing an appointment request from a pet owner to a clinic
class AppointmentRequest {
  final String id;
  final String clinicId;

  /// Pet owner details
  final String petOwnerId;
  final String petOwnerName;

  /// Pet details
  final String petId;
  final String petName;
  final String? petSpecies;

  /// Preferred time window
  final DateTime preferredDateStart;
  final DateTime preferredDateEnd;
  final TimePreference timePreference;

  /// Request details
  final String reason;
  final String? notes;

  /// Status tracking
  final AppointmentRequestStatus status;
  final String? handledBy;
  final String? handledByName;
  final DateTime? handledAt;
  final String? responseMessage;

  /// Chat integration - linked chat room if receptionist opens chat
  final String? linkedChatRoomId;

  /// Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppointmentRequest({
    required this.id,
    required this.clinicId,
    required this.petOwnerId,
    required this.petOwnerName,
    required this.petId,
    required this.petName,
    this.petSpecies,
    required this.preferredDateStart,
    required this.preferredDateEnd,
    required this.timePreference,
    required this.reason,
    this.notes,
    this.status = AppointmentRequestStatus.pending,
    this.handledBy,
    this.handledByName,
    this.handledAt,
    this.responseMessage,
    this.linkedChatRoomId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppointmentRequest.fromJson(Map<String, dynamic> json, String id) {
    return AppointmentRequest(
      id: id,
      clinicId: json['clinicId'] ?? '',
      petOwnerId: json['petOwnerId'] ?? '',
      petOwnerName: json['petOwnerName'] ?? '',
      petId: json['petId'] ?? '',
      petName: json['petName'] ?? '',
      petSpecies: json['petSpecies'],
      preferredDateStart: _parseDateTime(json['preferredDateStart']),
      preferredDateEnd: _parseDateTime(json['preferredDateEnd']),
      timePreference: TimePreference.values[json['timePreference'] ?? 0],
      reason: json['reason'] ?? '',
      notes: json['notes'],
      status: AppointmentRequestStatus.values[json['status'] ?? 0],
      handledBy: json['handledBy'],
      handledByName: json['handledByName'],
      handledAt: json['handledAt'] != null
          ? _parseDateTime(json['handledAt'])
          : null,
      responseMessage: json['responseMessage'],
      linkedChatRoomId: json['linkedChatRoomId'],
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clinicId': clinicId,
      'petOwnerId': petOwnerId,
      'petOwnerName': petOwnerName,
      'petId': petId,
      'petName': petName,
      'petSpecies': petSpecies,
      'preferredDateStart': preferredDateStart.millisecondsSinceEpoch,
      'preferredDateEnd': preferredDateEnd.millisecondsSinceEpoch,
      'timePreference': timePreference.index,
      'reason': reason,
      'notes': notes,
      'status': status.index,
      'handledBy': handledBy,
      'handledByName': handledByName,
      'handledAt': handledAt?.millisecondsSinceEpoch,
      'responseMessage': responseMessage,
      'linkedChatRoomId': linkedChatRoomId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }

  AppointmentRequest copyWith({
    String? clinicId,
    String? petOwnerId,
    String? petOwnerName,
    String? petId,
    String? petName,
    String? petSpecies,
    DateTime? preferredDateStart,
    DateTime? preferredDateEnd,
    TimePreference? timePreference,
    String? reason,
    String? notes,
    AppointmentRequestStatus? status,
    String? handledBy,
    String? handledByName,
    DateTime? handledAt,
    String? responseMessage,
    String? linkedChatRoomId,
    DateTime? updatedAt,
  }) {
    return AppointmentRequest(
      id: id,
      clinicId: clinicId ?? this.clinicId,
      petOwnerId: petOwnerId ?? this.petOwnerId,
      petOwnerName: petOwnerName ?? this.petOwnerName,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      petSpecies: petSpecies ?? this.petSpecies,
      preferredDateStart: preferredDateStart ?? this.preferredDateStart,
      preferredDateEnd: preferredDateEnd ?? this.preferredDateEnd,
      timePreference: timePreference ?? this.timePreference,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      handledBy: handledBy ?? this.handledBy,
      handledByName: handledByName ?? this.handledByName,
      handledAt: handledAt ?? this.handledAt,
      responseMessage: responseMessage ?? this.responseMessage,
      linkedChatRoomId: linkedChatRoomId ?? this.linkedChatRoomId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if request is still pending
  bool get isPending => status == AppointmentRequestStatus.pending;

  /// Check if request has been handled (confirmed or denied)
  bool get isHandled =>
      status == AppointmentRequestStatus.confirmed ||
      status == AppointmentRequestStatus.denied;

  /// Check if request was cancelled by pet owner
  bool get isCancelled => status == AppointmentRequestStatus.cancelled;

  /// Get a formatted date range string
  String get dateRangeText {
    final startStr = '${preferredDateStart.month}/${preferredDateStart.day}';
    final endStr = '${preferredDateEnd.month}/${preferredDateEnd.day}';
    if (preferredDateStart.year == preferredDateEnd.year &&
        preferredDateStart.month == preferredDateEnd.month &&
        preferredDateStart.day == preferredDateEnd.day) {
      return startStr;
    }
    return '$startStr - $endStr';
  }
}

/// Filters a list of appointment requests to only confirmed ones
/// whose preferred date range overlaps [referenceDate].
List<AppointmentRequest> todaysConfirmedAppointments(
  List<AppointmentRequest> requests, {
  DateTime? referenceDate,
}) {
  final ref = referenceDate ?? DateTime.now();
  final dayStart = DateTime(ref.year, ref.month, ref.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  return requests.where((r) {
    if (r.status != AppointmentRequestStatus.confirmed) return false;
    return r.preferredDateStart.isBefore(dayEnd) &&
        r.preferredDateEnd.isAfter(dayStart);
  }).toList();
}
