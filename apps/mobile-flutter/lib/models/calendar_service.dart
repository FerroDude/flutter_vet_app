import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'event_model.dart';

class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _eventsCollection {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(userId).collection('events');
  }

  // Create a new event
  Future<String> createEvent(CalendarEvent event) async {
    try {
      final docRef = await _eventsCollection.add(event.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  // Get all events for current user
  Stream<List<CalendarEvent>> getEvents({
    EventType? type,
    String? petId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query<Map<String, dynamic>> query = _eventsCollection;

    // Filter by type if specified
    if (type != null) {
      query = query.where('type', isEqualTo: type.index);
    }

    // Filter by pet if specified
    if (petId != null) {
      query = query.where('petId', isEqualTo: petId);
    }

    // Filter by date range if specified
    if (startDate != null) {
      query = query.where(
        'dateTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'dateTime',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    // Order by date
    query = query.orderBy('dateTime');

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID to data
        return CalendarEvent.fromJson(data);
      }).toList();
    });
  }

  // Get events for a specific date
  Stream<List<CalendarEvent>> getEventsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getEvents(startDate: startOfDay, endDate: endOfDay);
  }

  // Get upcoming events (next 7 days)
  Stream<List<CalendarEvent>> getUpcomingEvents() {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));

    return getEvents(startDate: now, endDate: nextWeek);
  }

  // Get overdue medication events
  Stream<List<MedicationEvent>> getOverdueMedications() {
    final now = DateTime.now();

    return getEvents(type: EventType.medication, endDate: now).map((events) {
      return events
          .where((event) {
            if (event is MedicationEvent) {
              return !event.isCompleted &&
                  (event.nextDose == null || event.nextDose!.isBefore(now));
            }
            return false;
          })
          .cast<MedicationEvent>()
          .toList();
    });
  }

  // Update an event
  Future<void> updateEvent(String eventId, CalendarEvent event) async {
    try {
      await _eventsCollection.doc(eventId).update(event.toJson());
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  // Mark medication as completed
  Future<void> markMedicationCompleted(
    String eventId,
    MedicationEvent event,
  ) async {
    try {
      final now = DateTime.now();
      final updatedEvent = MedicationEvent(
        id: event.id,
        title: event.title,
        description: event.description,
        dateTime: event.dateTime,
        petId: event.petId,
        userId: event.userId,
        isRecurring: event.isRecurring,
        recurrencePattern: event.recurrencePattern,
        recurrenceInterval: event.recurrenceInterval,
        endDate: event.endDate,
        createdAt: event.createdAt,
        updatedAt: now,
        medicationName: event.medicationName,
        dosage: event.dosage,
        frequency: event.frequency,
        customIntervalMinutes: event.customIntervalMinutes,
        isCompleted: true,
        lastTaken: now,
        nextDose: _calculateNextDose(event),
        remainingDoses: event.remainingDoses != null
            ? event.remainingDoses! - 1
            : null,
        instructions: event.instructions,
        requiresNotification: event.requiresNotification,
      );

      await _eventsCollection.doc(eventId).update(updatedEvent.toJson());
    } catch (e) {
      throw Exception('Failed to mark medication as completed: $e');
    }
  }

  // Mark note as completed
  Future<void> markNoteCompleted(String eventId, NoteEvent event) async {
    try {
      final now = DateTime.now();
      final updatedEvent = NoteEvent(
        id: event.id,
        title: event.title,
        description: event.description,
        dateTime: event.dateTime,
        petId: event.petId,
        userId: event.userId,
        isRecurring: event.isRecurring,
        recurrencePattern: event.recurrencePattern,
        recurrenceInterval: event.recurrenceInterval,
        endDate: event.endDate,
        createdAt: event.createdAt,
        updatedAt: now,
        category: event.category,
        priority: event.priority,
        isCompleted: true,
        tags: event.tags,
        reminderDateTime: event.reminderDateTime,
      );

      await _eventsCollection.doc(eventId).update(updatedEvent.toJson());
    } catch (e) {
      throw Exception('Failed to mark note as completed: $e');
    }
  }

  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _eventsCollection.doc(eventId).delete();
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }

  // Get events grouped by date for calendar display
  Future<Map<DateTime, List<CalendarEvent>>> getEventsGroupedByDate({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final events = await getEvents(
      startDate: startDate,
      endDate: endDate,
    ).first;

    final Map<DateTime, List<CalendarEvent>> groupedEvents = {};

    for (final event in events) {
      final date = DateTime(
        event.dateTime.year,
        event.dateTime.month,
        event.dateTime.day,
      );

      if (groupedEvents[date] == null) {
        groupedEvents[date] = [];
      }
      groupedEvents[date]!.add(event);
    }

    return groupedEvents;
  }

  // Helper method to calculate next dose for recurring medications
  DateTime? _calculateNextDose(MedicationEvent event) {
    if (!event.isRecurring) return null;

    final now = DateTime.now();

    switch (event.frequency) {
      case 'daily':
        return now.add(Duration(days: event.recurrenceInterval ?? 1));
      case 'weekly':
        return now.add(Duration(days: (event.recurrenceInterval ?? 1) * 7));
      case 'monthly':
        return DateTime(
          now.year,
          now.month + (event.recurrenceInterval ?? 1),
          now.day,
          now.hour,
          now.minute,
        );
      case 'custom':
        if (event.customIntervalMinutes != null) {
          return now.add(Duration(minutes: event.customIntervalMinutes!));
        }
        return null;
      default:
        return null;
    }
  }

  // Get events for a specific pet
  Stream<List<CalendarEvent>> getEventsForPet(String petId) {
    return getEvents(petId: petId);
  }

  // Get event counts for dashboard
  Future<Map<String, int>> getEventCounts() async {
    final allEvents = await getEvents().first;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekFromNow = today.add(const Duration(days: 7));

    return {
      'today': allEvents.where((event) {
        final eventDate = DateTime(
          event.dateTime.year,
          event.dateTime.month,
          event.dateTime.day,
        );
        return eventDate.isAtSameMomentAs(today);
      }).length,
      'tomorrow': allEvents.where((event) {
        final eventDate = DateTime(
          event.dateTime.year,
          event.dateTime.month,
          event.dateTime.day,
        );
        return eventDate.isAtSameMomentAs(tomorrow);
      }).length,
      'thisWeek': allEvents.where((event) {
        final eventDate = DateTime(
          event.dateTime.year,
          event.dateTime.month,
          event.dateTime.day,
        );
        return eventDate.isAfter(today) && eventDate.isBefore(weekFromNow);
      }).length,
      'total': allEvents.length,
    };
  }
}
