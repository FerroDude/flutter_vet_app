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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final remaining = endDay.difference(today).inDays + 1;
    return remaining < 0 ? 0 : remaining;
  }

  /// Current day in the course (e.g., "Day 3 of 7")
  /// Returns 0 if not started yet, 1 on start day, etc.
  int get currentDay {
    if (!hasStarted) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final daysSinceStart = today.difference(start).inDays + 1;
    return daysSinceStart < 1 ? 1 : daysSinceStart;
  }

  /// Progress percentage (0.0 to 1.0, null if ongoing)
  /// Progress is based on doses taken vs total doses expected
  double? get progress {
    if (totalDays == null) return null;
    
    // Return 0.0 if medication hasn't started
    if (!hasStarted) return 0.0;
    
    // For "as needed" medications, use time-based progress
    if (frequency == MedicationFrequency.asNeeded) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final daysPassed = today.difference(start).inDays;
      if (daysPassed < 0) return 0.0;
      final progress = daysPassed / totalDays!;
      return progress > 1.0 ? 1.0 : progress;
    }
    
    // Calculate total expected doses based on frequency and duration
    final expectedDoses = totalExpectedDoses;
    if (expectedDoses == null || expectedDoses == 0) return 0.0;
    
    final dosesTaken = doseHistory.where((d) => d.takenAt != null).length;
    
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
    if (frequency == MedicationFrequency.once) return 1;
    
    // For weekly, it's one dose per week (every 7 days)
    if (frequency == MedicationFrequency.weekly) {
      // Number of weeks + 1 for the starting day
      return (totalDays! / 7).ceil();
    }
    
    final dosesPerDay = _getDosesPerDay();
    if (dosesPerDay == 0) return null;
    return totalDays! * dosesPerDay;
  }
  
  /// Total doses taken
  int get totalDosesTaken => doseHistory.where((d) => d.takenAt != null).length;
  
  /// Total doses that SHOULD have been taken from startDate to today (or endDate if passed)
  int? get totalExpectedDosesToDate {
    if (!hasStarted) return 0;
    if (frequency == MedicationFrequency.asNeeded) return null;
    if (frequency == MedicationFrequency.once) return 1;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = calculatedEndDate;
    
    // Cap at end date if medication has ended
    final effectiveEndDate = (end != null && today.isAfter(DateTime(end.year, end.month, end.day))) 
        ? DateTime(end.year, end.month, end.day) 
        : today;
    
    final daysActive = effectiveEndDate.difference(start).inDays + 1;
    if (daysActive <= 0) return 0;
    
    if (frequency == MedicationFrequency.weekly) {
      return (daysActive / 7).ceil();
    }
    
    return daysActive * _getDosesPerDay();
  }

  /// Number of doses missed (expected to date - actually taken)
  int get missedDoses {
    final expected = totalExpectedDosesToDate;
    if (expected == null) return 0;
    return (expected - totalDosesTaken).clamp(0, expected);
  }

  /// Whether the user is behind schedule (has missed doses)
  bool get isBehindSchedule => missedDoses > 0;

  /// Adherence rate (0.0 to 1.0) - percentage of expected doses actually taken
  double? get adherenceRate {
    final expected = totalExpectedDosesToDate;
    if (expected == null || expected == 0) return null;
    return (totalDosesTaken / expected).clamp(0.0, 1.0);
  }

  /// Whether the medication course ended but not all doses were taken
  bool get endedIncomplete {
    if (!hasEnded) return false;
    final expected = totalExpectedDoses;
    if (expected == null) return false;
    return totalDosesTaken < expected;
  }
  
  /// Check if this medication can be extended
  bool get canBeExtended {
    // Can extend if it's active with an end date, or if it's completed/ended
    if (status == MedicationStatus.discontinued) return false;
    if (frequency == MedicationFrequency.once) return false; // One-time meds can't be extended
    return totalDays != null || hasEnded || status == MedicationStatus.completed;
  }
  
  /// Create a copy of this medication with extended duration
  /// Can extend from today (if ended) or from current end date (if still active)
  Medication extendBy({required int additionalDays}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Calculate new total days
    int newTotalDays;
    
    if (hasEnded) {
      // Medication already ended - extend from today
      final newEndDate = today.add(Duration(days: additionalDays - 1));
      // Calculate new total days from original start to new end
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      newTotalDays = newEndDate.difference(start).inDays + 1;
    } else {
      // Still active - extend from current end date
      newTotalDays = (totalDays ?? 0) + additionalDays;
    }
    
    return copyWith(
      totalDays: newTotalDays,
      status: MedicationStatus.active, // Reactivate if was completed
      updatedAt: now,
    );
  }

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
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);

    // Check if ended
    final end = calculatedEndDate;
    if (end != null && now.isAfter(end)) return null;

    // Sort dose times
    final sortedTimes = List<TimeOfDay>.from(doseTimes)
      ..sort((a, b) {
        final aMinutes = a.hour * 60 + a.minute;
        final bMinutes = b.hour * 60 + b.minute;
        return aMinutes.compareTo(bMinutes);
      });

    if (sortedTimes.isEmpty) return null;
    final firstTime = sortedTimes.first;
    final endDay = end != null ? DateTime(end.year, end.month, end.day) : null;

    // If medication hasn't started yet, return first dose on start day
    if (!hasStarted) {
      return DateTime(
        startDay.year,
        startDay.month,
        startDay.day,
        firstTime.hour,
        firstTime.minute,
      );
    }

    // One-time medication - if already taken, no next dose
    if (frequency == MedicationFrequency.once) {
      if (totalDosesTaken >= 1) return null;
      // Not taken yet - return today or next possible time
      for (final time in sortedTimes) {
        final doseDateTime = DateTime(today.year, today.month, today.day, time.hour, time.minute);
        if (doseDateTime.isAfter(now)) {
          return doseDateTime;
        }
      }
      // If all times today have passed, return tomorrow
      final tomorrow = today.add(const Duration(days: 1));
      if (endDay != null && tomorrow.isAfter(endDay)) return null;
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, firstTime.hour, firstTime.minute);
    }

    // Weekly medication - find next dose day based on weekly schedule
    if (frequency == MedicationFrequency.weekly) {
      // Weekly meds are taken every 7 days starting from startDate
      final daysSinceStart = today.difference(startDay).inDays;
      final daysUntilNextDose = (7 - (daysSinceStart % 7)) % 7;
      
      // Check if today is a dose day
      if (daysUntilNextDose == 0 || daysSinceStart % 7 == 0) {
        // Today is a dose day - check if dose is already taken today
        if (!allDosesTakenToday) {
          // Still have doses to take today - find next time
          for (final time in sortedTimes) {
            final doseDateTime = DateTime(today.year, today.month, today.day, time.hour, time.minute);
            if (doseDateTime.isAfter(now)) {
              return doseDateTime;
            }
          }
        }
        // All doses taken today or times passed - next dose is in 7 days
        final nextDoseDay = today.add(const Duration(days: 7));
        if (endDay != null && nextDoseDay.isAfter(endDay)) return null;
        return DateTime(nextDoseDay.year, nextDoseDay.month, nextDoseDay.day, firstTime.hour, firstTime.minute);
      } else {
        // Not a dose day - calculate next dose day
        final nextDoseDay = today.add(Duration(days: daysUntilNextDose));
        if (endDay != null && nextDoseDay.isAfter(endDay)) return null;
        return DateTime(nextDoseDay.year, nextDoseDay.month, nextDoseDay.day, firstTime.hour, firstTime.minute);
      }
    }

    // Daily, twice daily, three times daily - check today's remaining doses
    if (isTodayInActivePeriod && !allDosesTakenToday) {
      for (final time in sortedTimes) {
        final doseDateTime = DateTime(today.year, today.month, today.day, time.hour, time.minute);
        if (doseDateTime.isAfter(now)) {
          return doseDateTime;
        }
      }
    }

    // Next dose is tomorrow (first dose time)
    final tomorrow = today.add(const Duration(days: 1));
    if (endDay != null && tomorrow.isAfter(endDay)) return null;
    
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, firstTime.hour, firstTime.minute);
  }

  /// Human-readable description of when the next dose is
  String? get nextDoseDescription {
    final next = nextDose;
    if (next == null) return null;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextDay = DateTime(next.year, next.month, next.day);
    
    final daysUntil = nextDay.difference(today).inDays;
    
    if (daysUntil == 0) {
      // Today - show time
      final hour = next.hour;
      final minute = next.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final displayMinute = minute.toString().padLeft(2, '0');
      return 'Next: Today at $displayHour:$displayMinute $period';
    } else if (daysUntil == 1) {
      return 'Next: Tomorrow';
    } else {
      return 'Next: In $daysUntil days';
    }
  }

  /// Whether the medication has started (startDate is today or in the past)
  bool get hasStarted {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return !start.isAfter(today);
  }

  /// Whether the medication has ended (endDate is in the past)
  bool get hasEnded {
    final end = calculatedEndDate;
    if (end == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return today.isAfter(endDay);
  }

  /// Whether today is within the active period (between start and end dates)
  bool get isTodayInActivePeriod {
    if (!hasStarted) return false;
    if (hasEnded) return false;
    return true;
  }

  /// Check if a specific date is within the medication's active period
  bool isDateInActivePeriod(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = calculatedEndDate;
    final endDay = end != null ? DateTime(end.year, end.month, end.day) : null;
    
    if (day.isBefore(start)) return false;
    if (endDay != null && day.isAfter(endDay)) return false;
    return true;
  }

  /// Check if a dose is scheduled for a specific date
  /// Returns true if the medication is active on that date and has a scheduled dose
  bool isDoseScheduledOnDate(DateTime date) {
    if (status != MedicationStatus.active) return false;
    if (!isDateInActivePeriod(date)) return false;
    if (frequency == MedicationFrequency.asNeeded) return false;
    if (frequency == MedicationFrequency.once) {
      // One-time medication - only scheduled on start date if not taken
      final day = DateTime(date.year, date.month, date.day);
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      return day == start && totalDosesTaken < 1;
    }
    
    // Weekly medications - only on specific days
    if (frequency == MedicationFrequency.weekly) {
      final day = DateTime(date.year, date.month, date.day);
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final daysSinceStart = day.difference(start).inDays;
      return daysSinceStart >= 0 && daysSinceStart % 7 == 0;
    }
    
    // Daily, twice daily, three times daily - every day in active period
    return true;
  }

  /// Get doses expected on a specific date
  int dosesExpectedOnDate(DateTime date) {
    if (!isDoseScheduledOnDate(date)) return 0;
    
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
        return 1;
      case MedicationFrequency.asNeeded:
        return 0;
    }
  }

  /// Get doses taken on a specific date
  int dosesTakenOnDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return doseHistory.where((log) {
      return log.takenAt != null &&
          log.takenAt!.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
          log.takenAt!.isBefore(dayEnd);
    }).length;
  }

  /// Days until medication starts (0 if already started)
  int get daysUntilStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (!start.isAfter(today)) return 0;
    return start.difference(today).inDays;
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

  /// Get doses expected today (0 if today is outside active period)
  int get dosesExpectedToday {
    // No doses expected if medication hasn't started or has ended
    if (!isTodayInActivePeriod) return 0;
    
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
        // Check if today is a dose day (every 7 days from start)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final daysSinceStart = today.difference(start).inDays;
        return daysSinceStart % 7 == 0 ? 1 : 0;
      case MedicationFrequency.asNeeded:
        return 0;
    }
  }

  /// Whether all doses for today have been taken
  bool get allDosesTakenToday {
    // If not in active period, there are no doses to take
    if (!isTodayInActivePeriod) return true;
    // "As needed" medications have no daily limit
    if (frequency == MedicationFrequency.asNeeded) return false;
    // "Once" medications can only be taken once ever
    if (frequency == MedicationFrequency.once) return totalDosesTaken >= 1;
    // Weekly - check if today is even a dose day
    if (dosesExpectedToday == 0) return true;
    return dosesTakenToday >= dosesExpectedToday;
  }

  /// Remaining doses that can be taken today
  int get dosesRemainingToday {
    // No doses remaining if not in active period
    if (!isTodayInActivePeriod) return 0;
    if (frequency == MedicationFrequency.asNeeded) return 999; // No limit
    if (frequency == MedicationFrequency.once) return totalDosesTaken >= 1 ? 0 : 1;
    final remaining = dosesExpectedToday - dosesTakenToday;
    return remaining < 0 ? 0 : remaining;
  }

  /// Human-readable string for today's dose status
  String get todayDoseStatus {
    // Handle medications that haven't started yet
    if (!hasStarted) {
      final days = daysUntilStart;
      if (days == 1) return 'Starts tomorrow';
      return 'Starts in $days days';
    }
    
    // Handle medications that have ended
    if (hasEnded) {
      if (endedIncomplete) {
        return 'Course ended • $missedDoses missed';
      }
      return 'Course completed';
    }
    
    if (frequency == MedicationFrequency.asNeeded) {
      return dosesTakenToday > 0 
          ? '$dosesTakenToday dose${dosesTakenToday == 1 ? '' : 's'} taken today'
          : 'Take as needed';
    }
    if (frequency == MedicationFrequency.once) {
      return totalDosesTaken >= 1 ? 'Completed' : 'Not yet taken';
    }
    // Weekly - check if today is a dose day
    if (frequency == MedicationFrequency.weekly && dosesExpectedToday == 0) {
      return 'No dose today';
    }
    if (allDosesTakenToday) {
      // Check if behind schedule even though today is done
      if (isBehindSchedule) {
        return 'Done today • $missedDoses missed overall';
      }
      return 'All doses taken today';
    }
    
    // Active medication with doses remaining
    final remaining = dosesExpectedToday - dosesTakenToday;
    if (isBehindSchedule) {
      return '$missedDoses missed • $remaining due today';
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
