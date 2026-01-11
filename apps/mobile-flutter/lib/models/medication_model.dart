import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Status of a medication
enum MedicationStatus {
  active,     // Currently being taken
  paused,     // Temporarily stopped
  completed,  // Finished the course
  discontinued, // Stopped before completion
}

/// Frequency options for medications
enum MedicationFrequency {
  once,       // One-time medication
  daily,      // Once per day
  twiceDaily, // Twice per day (morning/evening)
  threeTimesDaily, // Three times per day
  weekly,     // Once per week
  asNeeded,   // Take when needed (PRN)
}

/// A single dose log entry
class DoseLog {
  final String id;
  final DateTime scheduledTime;
  final DateTime? takenAt;
  final bool skipped;
  final String? notes;

  const DoseLog({
    required this.id,
    required this.scheduledTime,
    this.takenAt,
    this.skipped = false,
    this.notes,
  });

  factory DoseLog.fromJson(Map<String, dynamic> json) {
    return DoseLog(
      id: json['id'] ?? const Uuid().v4(),
      scheduledTime: _parseDateTime(json['scheduledTime']),
      takenAt: json['takenAt'] != null ? _parseDateTime(json['takenAt']) : null,
      skipped: json['skipped'] ?? false,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      'takenAt': takenAt?.millisecondsSinceEpoch,
      'skipped': skipped,
      'notes': notes,
    };
  }

  DoseLog copyWith({
    DateTime? takenAt,
    bool? skipped,
    String? notes,
  }) {
    return DoseLog(
      id: id,
      scheduledTime: scheduledTime,
      takenAt: takenAt ?? this.takenAt,
      skipped: skipped ?? this.skipped,
      notes: notes ?? this.notes,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      return DateTime.parse(value);
    }
    throw ArgumentError('Invalid datetime value: $value');
  }
}

/// Represents a medication as a first-class entity (not an event)
class Medication {
  final String id;
  final String petId;
  final String ownerId;

  // Core medication info
  final String name;
  final String dosage;
  final String? instructions;

  // Schedule
  final MedicationFrequency frequency;
  final List<TimeOfDay> doseTimes; // Times of day for doses
  final DateTime startDate;
  final DateTime? endDate; // null = ongoing/indefinite
  final int? totalDays; // For time-limited courses

  // Status
  final MedicationStatus status;

  // Tracking
  final bool trackDoses;
  final List<DoseLog> doseHistory;

  // Notifications
  final bool remindersEnabled;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional: prescribed by vet
  final String? prescribedByVetId;
  final String? prescribedByVetName;

  const Medication({
    required this.id,
    required this.petId,
    required this.ownerId,
    required this.name,
    required this.dosage,
    this.instructions,
    required this.frequency,
    required this.doseTimes,
    required this.startDate,
    this.endDate,
    this.totalDays,
    required this.status,
    this.trackDoses = false,
    this.doseHistory = const [],
    this.remindersEnabled = true,
    required this.createdAt,
    required this.updatedAt,
    this.prescribedByVetId,
    this.prescribedByVetName,
  });

  /// Generate a unique ID for a new medication
  static String generateId() => const Uuid().v4();

  /// Create from Firestore document
  factory Medication.fromJson(Map<String, dynamic> json, String id) {
    // Parse dose times
    List<TimeOfDay> doseTimes = [];
    if (json['doseTimes'] != null) {
      for (final time in json['doseTimes'] as List) {
        if (time is Map) {
          doseTimes.add(TimeOfDay(
            hour: time['hour'] ?? 8,
            minute: time['minute'] ?? 0,
          ));
        } else if (time is int) {
          // Legacy format: minutes since midnight
          doseTimes.add(TimeOfDay(
            hour: time ~/ 60,
            minute: time % 60,
          ));
        }
      }
    }
    if (doseTimes.isEmpty) {
      doseTimes = [const TimeOfDay(hour: 8, minute: 0)];
    }

    // Parse dose history
    List<DoseLog> doseHistory = [];
    if (json['doseHistory'] != null) {
      for (final log in json['doseHistory'] as List) {
        doseHistory.add(DoseLog.fromJson(log as Map<String, dynamic>));
      }
    }

    return Medication(
      id: id,
      petId: json['petId'] ?? '',
      ownerId: json['ownerId'] ?? '',
      name: json['name'] ?? '',
      dosage: json['dosage'] ?? '',
      instructions: json['instructions'],
      frequency: MedicationFrequency.values[json['frequency'] ?? 0],
      doseTimes: doseTimes,
      startDate: _parseDateTime(json['startDate']),
      endDate: json['endDate'] != null ? _parseDateTime(json['endDate']) : null,
      totalDays: json['totalDays'],
      status: MedicationStatus.values[json['status'] ?? 0],
      trackDoses: json['trackDoses'] ?? false,
      doseHistory: doseHistory,
      remindersEnabled: json['remindersEnabled'] ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      prescribedByVetId: json['prescribedByVetId'],
      prescribedByVetName: json['prescribedByVetName'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'petId': petId,
      'ownerId': ownerId,
      'name': name,
      'dosage': dosage,
      'instructions': instructions,
      'frequency': frequency.index,
      'doseTimes': doseTimes
          .map((t) => {'hour': t.hour, 'minute': t.minute})
          .toList(),
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'totalDays': totalDays,
      'status': status.index,
      'trackDoses': trackDoses,
      'doseHistory': doseHistory.map((d) => d.toJson()).toList(),
      'remindersEnabled': remindersEnabled,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'prescribedByVetId': prescribedByVetId,
      'prescribedByVetName': prescribedByVetName,
    };
  }

  /// Copy with updated fields
  Medication copyWith({
    String? petId,
    String? ownerId,
    String? name,
    String? dosage,
    String? instructions,
    MedicationFrequency? frequency,
    List<TimeOfDay>? doseTimes,
    DateTime? startDate,
    DateTime? endDate,
    int? totalDays,
    MedicationStatus? status,
    bool? trackDoses,
    List<DoseLog>? doseHistory,
    bool? remindersEnabled,
    DateTime? updatedAt,
    String? prescribedByVetId,
    String? prescribedByVetName,
  }) {
    return Medication(
      id: id,
      petId: petId ?? this.petId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      instructions: instructions ?? this.instructions,
      frequency: frequency ?? this.frequency,
      doseTimes: doseTimes ?? this.doseTimes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      status: status ?? this.status,
      trackDoses: trackDoses ?? this.trackDoses,
      doseHistory: doseHistory ?? this.doseHistory,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      prescribedByVetId: prescribedByVetId ?? this.prescribedByVetId,
      prescribedByVetName: prescribedByVetName ?? this.prescribedByVetName,
    );
  }

  // ============ Computed Properties ============

  /// Whether this medication is currently active
  bool get isActive => status == MedicationStatus.active;

  /// Whether this medication is ongoing (no end date)
  bool get isOngoing => endDate == null && totalDays == null;

  /// Calculate end date based on totalDays if specified
  DateTime? get calculatedEndDate {
    if (endDate != null) return endDate;
    if (totalDays != null) {
      return startDate.add(Duration(days: totalDays! - 1));
    }
    return null;
  }

  /// Days remaining in the course (null if ongoing)
  int? get daysRemaining {
    final end = calculatedEndDate;
    if (end == null) return null;
    final remaining = end.difference(DateTime.now()).inDays + 1;
    return remaining < 0 ? 0 : remaining;
  }

  /// Current day in the course (e.g., "Day 3 of 7")
  int get currentDay {
    final daysSinceStart = DateTime.now().difference(startDate).inDays + 1;
    return daysSinceStart < 1 ? 1 : daysSinceStart;
  }

  /// Progress percentage (0.0 to 1.0, null if ongoing)
  /// Progress is based on doses taken vs total doses expected
  double? get progress {
    if (totalDays == null) return null;
    
    // For "as needed" medications, use time-based progress
    if (frequency == MedicationFrequency.asNeeded) {
      final daysPassed = DateTime.now().difference(startDate).inDays;
      if (daysPassed < 0) return 0.0;
      final progress = daysPassed / totalDays!;
      return progress > 1.0 ? 1.0 : progress;
    }
    
    // Calculate total expected doses based on frequency and duration
    final dosesPerDay = _getDosesPerDay();
    if (dosesPerDay == 0) return 0.0;
    
    final expectedDoses = totalDays! * dosesPerDay;
    final dosesTaken = doseHistory.where((d) => d.takenAt != null).length;
    
    if (expectedDoses == 0) return 0.0;
    
    final progress = dosesTaken / expectedDoses;
    return progress > 1.0 ? 1.0 : progress;
  }
  
  /// Helper to get doses per day based on frequency
  int _getDosesPerDay() {
    switch (frequency) {
      case MedicationFrequency.once:
        return 1;
      case MedicationFrequency.daily:
        return 1;
      case MedicationFrequency.twiceDaily:
        return 2;
      case MedicationFrequency.threeTimesDaily:
        return 3;
      case MedicationFrequency.weekly:
        return 1; // 1 dose on dose days
      case MedicationFrequency.asNeeded:
        return 0; // No expected doses - use time-based progress
    }
  }
  
  /// Total expected doses for the medication course
  int? get totalExpectedDoses {
    if (totalDays == null) return null;
    if (frequency == MedicationFrequency.asNeeded) return null;
    final dosesPerDay = _getDosesPerDay();
    if (dosesPerDay == 0) return null;
    return totalDays! * dosesPerDay;
  }
  
  /// Total doses taken
  int get totalDosesTaken => doseHistory.where((d) => d.takenAt != null).length;

  /// Get a human-readable frequency string
  String get frequencyDisplay {
    switch (frequency) {
      case MedicationFrequency.once:
        return 'One time';
      case MedicationFrequency.daily:
        return 'Once daily';
      case MedicationFrequency.twiceDaily:
        return 'Twice daily';
      case MedicationFrequency.threeTimesDaily:
        return '3 times daily';
      case MedicationFrequency.weekly:
        return 'Weekly';
      case MedicationFrequency.asNeeded:
        return 'As needed';
    }
  }

  /// Get next dose time for today (or null if all doses done/no more today)
  DateTime? get nextDoseToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final time in doseTimes) {
      final doseDateTime = DateTime(
        today.year,
        today.month,
        today.day,
        time.hour,
        time.minute,
      );
      if (doseDateTime.isAfter(now)) {
        return doseDateTime;
      }
    }
    return null;
  }

  /// Get the next scheduled dose datetime
  DateTime? get nextDose {
    if (status != MedicationStatus.active) return null;
    if (frequency == MedicationFrequency.asNeeded) return null;

    final now = DateTime.now();

    // Check if ended
    final end = calculatedEndDate;
    if (end != null && now.isAfter(end)) return null;

    // Find next dose time
    final today = DateTime(now.year, now.month, now.day);

    // Sort dose times
    final sortedTimes = List<TimeOfDay>.from(doseTimes)
      ..sort((a, b) {
        final aMinutes = a.hour * 60 + a.minute;
        final bMinutes = b.hour * 60 + b.minute;
        return aMinutes.compareTo(bMinutes);
      });

    // Check today's remaining doses
    for (final time in sortedTimes) {
      final doseDateTime = DateTime(
        today.year,
        today.month,
        today.day,
        time.hour,
        time.minute,
      );
      if (doseDateTime.isAfter(now)) {
        return doseDateTime;
      }
    }

    // Next dose is tomorrow (first dose time)
    if (sortedTimes.isNotEmpty) {
      final tomorrow = today.add(const Duration(days: 1));
      final firstTime = sortedTimes.first;
      return DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        firstTime.hour,
        firstTime.minute,
      );
    }

    return null;
  }

  /// Get doses taken today count
  int get dosesTakenToday {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return doseHistory.where((log) {
      return log.takenAt != null &&
          log.takenAt!.isAfter(todayStart) &&
          log.takenAt!.isBefore(todayEnd);
    }).length;
  }

  /// Get doses expected today
  int get dosesExpectedToday {
    switch (frequency) {
      case MedicationFrequency.once:
        return 1;
      case MedicationFrequency.daily:
        return 1;
      case MedicationFrequency.twiceDaily:
        return 2;
      case MedicationFrequency.threeTimesDaily:
        return 3;
      case MedicationFrequency.weekly:
        // Check if today is a dose day
        final daysSinceStart = DateTime.now().difference(startDate).inDays;
        return daysSinceStart % 7 == 0 ? 1 : 0;
      case MedicationFrequency.asNeeded:
        return 0;
    }
  }

  /// Whether all doses for today have been taken
  bool get allDosesTakenToday {
    // "As needed" medications have no daily limit
    if (frequency == MedicationFrequency.asNeeded) return false;
    // "Once" medications can only be taken once ever
    if (frequency == MedicationFrequency.once) return totalDosesTaken >= 1;
    return dosesTakenToday >= dosesExpectedToday;
  }

  /// Remaining doses that can be taken today
  int get dosesRemainingToday {
    if (frequency == MedicationFrequency.asNeeded) return 999; // No limit
    if (frequency == MedicationFrequency.once) return totalDosesTaken >= 1 ? 0 : 1;
    final remaining = dosesExpectedToday - dosesTakenToday;
    return remaining < 0 ? 0 : remaining;
  }

  /// Human-readable string for today's dose status
  String get todayDoseStatus {
    if (frequency == MedicationFrequency.asNeeded) {
      return dosesTakenToday > 0 
          ? '$dosesTakenToday dose${dosesTakenToday == 1 ? '' : 's'} taken today'
          : 'Take as needed';
    }
    if (frequency == MedicationFrequency.once) {
      return totalDosesTaken >= 1 ? 'Completed' : 'Not yet taken';
    }
    if (allDosesTakenToday) {
      return 'All doses taken today';
    }
    return '$dosesTakenToday of $dosesExpectedToday taken today';
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }
}
