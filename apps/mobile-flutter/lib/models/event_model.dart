import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum EventType { appointment, medication, note }

abstract class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final EventType type;
  final String? petId;
  final String userId;
  final String? seriesId;
  final bool isRecurring;
  final String? recurrencePattern; // daily, weekly, monthly
  final int? recurrenceInterval;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.type,
    this.petId,
    required this.userId,
    this.seriesId,
    this.isRecurring = false,
    this.recurrencePattern,
    this.recurrenceInterval,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson();
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final type = EventType.values[json['type']];
    switch (type) {
      case EventType.appointment:
        return AppointmentEvent.fromJson(json);
      case EventType.medication:
        return MedicationEvent.fromJson(json);
      case EventType.note:
        return NoteEvent.fromJson(json);
    }
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? petId,
    String? userId,
    String? seriesId,
    bool? isRecurring,
    String? recurrencePattern,
    int? recurrenceInterval,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  });

  static String generateId() => const Uuid().v4();
}

class AppointmentEvent extends CalendarEvent {
  final String? vetName;
  final String? location;
  final String? appointmentType; // checkup, vaccination, surgery, etc.
  final bool isConfirmed;
  final String? contactInfo;

  AppointmentEvent({
    required super.id,
    required super.title,
    required super.description,
    required super.dateTime,
    super.petId,
    required super.userId,
    super.seriesId,
    super.isRecurring,
    super.recurrencePattern,
    super.recurrenceInterval,
    super.endDate,
    required super.createdAt,
    required super.updatedAt,
    this.vetName,
    this.location,
    this.appointmentType,
    this.isConfirmed = false,
    this.contactInfo,
  }) : super(type: EventType.appointment);

  factory AppointmentEvent.fromJson(Map<String, dynamic> json) {
    return AppointmentEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dateTime: _parseDateTime(json['dateTime']),
      petId: json['petId'],
      userId: json['userId'],
      seriesId: json['seriesId'],
      isRecurring: json['isRecurring'] ?? false,
      recurrencePattern: json['recurrencePattern'],
      recurrenceInterval: json['recurrenceInterval'],
      endDate: json['endDate'] != null ? _parseDateTime(json['endDate']) : null,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      vetName: json['vetName'],
      location: json['location'],
      appointmentType: json['appointmentType'],
      isConfirmed: json['isConfirmed'] ?? false,
      contactInfo: json['contactInfo'],
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

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'type': type.index,
      'petId': petId,
      'userId': userId,
      'seriesId': seriesId,
      'isRecurring': isRecurring,
      'recurrencePattern': recurrencePattern,
      'recurrenceInterval': recurrenceInterval,
      'endDate': endDate?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'vetName': vetName,
      'location': location,
      'appointmentType': appointmentType,
      'isConfirmed': isConfirmed,
      'contactInfo': contactInfo,
    };
  }

  @override
  AppointmentEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? petId,
    String? userId,
    String? seriesId,
    bool? isRecurring,
    String? recurrencePattern,
    int? recurrenceInterval,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? vetName,
    String? location,
    String? appointmentType,
    bool? isConfirmed,
    String? contactInfo,
  }) {
    return AppointmentEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      petId: petId ?? this.petId,
      userId: userId ?? this.userId,
      seriesId: seriesId ?? this.seriesId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vetName: vetName ?? this.vetName,
      location: location ?? this.location,
      appointmentType: appointmentType ?? this.appointmentType,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      contactInfo: contactInfo ?? this.contactInfo,
    );
  }
}

class MedicationEvent extends CalendarEvent {
  final String medicationName;
  final String dosage;
  final String frequency; // once, daily, weekly, monthly, custom
  final int? customIntervalMinutes;
  final bool isCompleted;
  final DateTime? lastTaken;
  final DateTime? nextDose;
  final int? remainingDoses;
  final String? instructions;
  final bool requiresNotification;

  MedicationEvent({
    required super.id,
    required super.title,
    required super.description,
    required super.dateTime,
    super.petId,
    required super.userId,
    super.seriesId,
    super.isRecurring,
    super.recurrencePattern,
    super.recurrenceInterval,
    super.endDate,
    required super.createdAt,
    required super.updatedAt,
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    this.customIntervalMinutes,
    this.isCompleted = false,
    this.lastTaken,
    this.nextDose,
    this.remainingDoses,
    this.instructions,
    this.requiresNotification = true,
  }) : super(type: EventType.medication);

  factory MedicationEvent.fromJson(Map<String, dynamic> json) {
    return MedicationEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dateTime: AppointmentEvent._parseDateTime(json['dateTime']),
      petId: json['petId'],
      userId: json['userId'],
      seriesId: json['seriesId'],
      isRecurring: json['isRecurring'] ?? false,
      recurrencePattern: json['recurrencePattern'],
      recurrenceInterval: json['recurrenceInterval'],
      endDate: json['endDate'] != null
          ? AppointmentEvent._parseDateTime(json['endDate'])
          : null,
      createdAt: AppointmentEvent._parseDateTime(json['createdAt']),
      updatedAt: AppointmentEvent._parseDateTime(json['updatedAt']),
      medicationName: json['medicationName'],
      dosage: json['dosage'],
      frequency: json['frequency'],
      customIntervalMinutes: json['customIntervalMinutes'],
      isCompleted: json['isCompleted'] ?? false,
      lastTaken: json['lastTaken'] != null
          ? AppointmentEvent._parseDateTime(json['lastTaken'])
          : null,
      nextDose: json['nextDose'] != null
          ? AppointmentEvent._parseDateTime(json['nextDose'])
          : null,
      remainingDoses: json['remainingDoses'],
      instructions: json['instructions'],
      requiresNotification: json['requiresNotification'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'type': type.index,
      'petId': petId,
      'userId': userId,
      'seriesId': seriesId,
      'isRecurring': isRecurring,
      'recurrencePattern': recurrencePattern,
      'recurrenceInterval': recurrenceInterval,
      'endDate': endDate?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'medicationName': medicationName,
      'dosage': dosage,
      'frequency': frequency,
      'customIntervalMinutes': customIntervalMinutes,
      'isCompleted': isCompleted,
      'lastTaken': lastTaken?.millisecondsSinceEpoch,
      'nextDose': nextDose?.millisecondsSinceEpoch,
      'remainingDoses': remainingDoses,
      'instructions': instructions,
      'requiresNotification': requiresNotification,
    };
  }

  @override
  MedicationEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? petId,
    String? userId,
    String? seriesId,
    bool? isRecurring,
    String? recurrencePattern,
    int? recurrenceInterval,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? medicationName,
    String? dosage,
    String? frequency,
    int? customIntervalMinutes,
    bool? isCompleted,
    DateTime? lastTaken,
    DateTime? nextDose,
    int? remainingDoses,
    String? instructions,
    bool? requiresNotification,
  }) {
    return MedicationEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      petId: petId ?? this.petId,
      userId: userId ?? this.userId,
      seriesId: seriesId ?? this.seriesId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      medicationName: medicationName ?? this.medicationName,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      customIntervalMinutes:
          customIntervalMinutes ?? this.customIntervalMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      lastTaken: lastTaken ?? this.lastTaken,
      nextDose: nextDose ?? this.nextDose,
      remainingDoses: remainingDoses ?? this.remainingDoses,
      instructions: instructions ?? this.instructions,
      requiresNotification: requiresNotification ?? this.requiresNotification,
    );
  }
}

class NoteEvent extends CalendarEvent {
  final String? category;
  final int priority; // 1-5, 1 being lowest, 5 being highest
  final bool isCompleted;
  final List<String>? tags;
  final DateTime? reminderDateTime;

  NoteEvent({
    required super.id,
    required super.title,
    required super.description,
    required super.dateTime,
    super.petId,
    required super.userId,
    super.seriesId,
    super.isRecurring,
    super.recurrencePattern,
    super.recurrenceInterval,
    super.endDate,
    required super.createdAt,
    required super.updatedAt,
    this.category,
    this.priority = 3,
    this.isCompleted = false,
    this.tags,
    this.reminderDateTime,
  }) : super(type: EventType.note);

  factory NoteEvent.fromJson(Map<String, dynamic> json) {
    return NoteEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dateTime: AppointmentEvent._parseDateTime(json['dateTime']),
      petId: json['petId'],
      userId: json['userId'],
      seriesId: json['seriesId'],
      isRecurring: json['isRecurring'] ?? false,
      recurrencePattern: json['recurrencePattern'],
      recurrenceInterval: json['recurrenceInterval'],
      endDate: json['endDate'] != null
          ? AppointmentEvent._parseDateTime(json['endDate'])
          : null,
      createdAt: AppointmentEvent._parseDateTime(json['createdAt']),
      updatedAt: AppointmentEvent._parseDateTime(json['updatedAt']),
      category: json['category'],
      priority: json['priority'] ?? 3,
      isCompleted: json['isCompleted'] ?? false,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      reminderDateTime: json['reminderDateTime'] != null
          ? AppointmentEvent._parseDateTime(json['reminderDateTime'])
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'type': type.index,
      'petId': petId,
      'userId': userId,
      'seriesId': seriesId,
      'isRecurring': isRecurring,
      'recurrencePattern': recurrencePattern,
      'recurrenceInterval': recurrenceInterval,
      'endDate': endDate?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'category': category,
      'priority': priority,
      'isCompleted': isCompleted,
      'tags': tags,
      'reminderDateTime': reminderDateTime?.millisecondsSinceEpoch,
    };
  }

  @override
  NoteEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? petId,
    String? userId,
    String? seriesId,
    bool? isRecurring,
    String? recurrencePattern,
    int? recurrenceInterval,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? category,
    int? priority,
    bool? isCompleted,
    List<String>? tags,
    DateTime? reminderDateTime,
  }) {
    return NoteEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      petId: petId ?? this.petId,
      userId: userId ?? this.userId,
      seriesId: seriesId ?? this.seriesId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      tags: tags ?? this.tags,
      reminderDateTime: reminderDateTime ?? this.reminderDateTime,
    );
  }
}
