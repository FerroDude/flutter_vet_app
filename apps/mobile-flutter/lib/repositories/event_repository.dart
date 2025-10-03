import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../services/cache_service.dart';

class EventRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CacheService _cacheService;
  final String? _currentUserId;

  // Stream controllers for reactive updates
  final StreamController<List<CalendarEvent>> _eventsController =
      StreamController<List<CalendarEvent>>.broadcast();
  final StreamController<Map<String, int>> _countsController =
      StreamController<Map<String, int>>.broadcast();

  // Cache management
  List<CalendarEvent>? _cachedEvents;
  Map<String, int>? _cachedCounts;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidity = Duration(hours: 2);

  EventRepository(this._cacheService, this._currentUserId);

  String? get currentUserId => _currentUserId;

  // Events stream
  Stream<List<CalendarEvent>> get eventsStream => _eventsController.stream;

  // Counts stream
  Stream<Map<String, int>> get countsStream => _countsController.stream;

  // Initialize repository
  Future<void> initialize() async {
    if (_currentUserId == null) return;

    // Try to load from cache first
    final cachedEvents = await _cacheService.getCachedEvents(_currentUserId);
    if (cachedEvents != null) {
      _cachedEvents = cachedEvents;
      _eventsController.add(cachedEvents);
    }

    // Load cached counts
    final cachedCounts = await _cacheService.getCachedEventCounts(
      _currentUserId,
    );
    if (cachedCounts != null) {
      _cachedCounts = cachedCounts;
      _countsController.add(cachedCounts);
    }
  }

  // Get events with smart caching
  Future<List<CalendarEvent>> getEvents({
    EventType? type,
    String? petId,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    if (_currentUserId == null) return [];

    // Check if we can use cached data
    if (!forceRefresh &&
        _cachedEvents != null &&
        _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!) < _cacheValidity) {
      var filteredEvents = _cachedEvents!;

      // Apply filters
      if (type != null) {
        filteredEvents = filteredEvents
            .where((event) => event.type == type)
            .toList();
      }
      if (petId != null) {
        filteredEvents = filteredEvents
            .where((event) => event.petId == petId)
            .toList();
      }
      if (startDate != null) {
        filteredEvents = filteredEvents
            .where(
              (event) => event.dateTime.isAfter(
                startDate.subtract(const Duration(days: 1)),
              ),
            )
            .toList();
      }
      if (endDate != null) {
        filteredEvents = filteredEvents
            .where(
              (event) =>
                  event.dateTime.isBefore(endDate.add(const Duration(days: 1))),
            )
            .toList();
      }

      return filteredEvents;
    }

    // Fetch from Firestore
    try {
      final events = await _fetchEventsFromFirestore(
        type: type,
        petId: petId,
        startDate: startDate,
        endDate: endDate,
      );

      // Update cache
      if (type == null &&
          petId == null &&
          startDate == null &&
          endDate == null) {
        _cachedEvents = events;
        _lastCacheUpdate = DateTime.now();
        await _cacheService.cacheEvents(_currentUserId, events);
        _eventsController.add(events);
      }

      return events;
    } catch (e) {
      print('Error fetching events: $e');
      return _cachedEvents ?? [];
    }
  }

  // Optimized Firestore query
  Future<List<CalendarEvent>> _fetchEventsFromFirestore({
    EventType? type,
    String? petId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final collectionRef = _getEventsCollection();

    Query<Map<String, dynamic>> query = collectionRef;

    // Apply filters efficiently
    if (type != null) {
      query = query.where('type', isEqualTo: type.index);
    }

    if (petId != null) {
      query = query.where('petId', isEqualTo: petId);
    }

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

    // Order by date for consistent results
    query = query.orderBy('dateTime');

    // Limit results for performance
    query = query.limit(1000);

    final snapshot = await query.get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return CalendarEvent.fromJson(data);
    }).toList();
  }

  // Create event with offline support
  Future<String> createEvent(CalendarEvent event) async {
    print('DEBUG: EventRepository.createEvent called');
    print('DEBUG: Current user ID: $_currentUserId');

    if (_currentUserId == null) {
      print('DEBUG: User not authenticated, throwing exception');
      throw Exception('User not authenticated');
    }

    try {
      print('DEBUG: Getting events collection...');
      final collection = _getEventsCollection();
      print('DEBUG: Adding event to Firestore...');
      final docRef = await collection.add(event.toJson());
      print('DEBUG: Firestore document created with ID: ${docRef.id}');

      // Update local cache optimistically
      _cachedEvents?.add(event.copyWith(id: docRef.id));
      if (_cachedEvents != null) {
        _eventsController.add(List.from(_cachedEvents!));
      }

      // Invalidate counts cache
      _cachedCounts = null;

      print('DEBUG: EventRepository.createEvent completed successfully');
      return docRef.id;
    } catch (e) {
      print('DEBUG: Error in EventRepository.createEvent: $e');
      // Cache for offline sync
      await _cacheService.cacheEventForOffline(event.id, event);
      rethrow;
    }
  }

  // Update event with optimistic updates
  Future<void> updateEvent(String eventId, CalendarEvent event) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _getEventsCollection().doc(eventId).update(event.toJson());

      // Update local cache optimistically
      final index = _cachedEvents?.indexWhere((e) => e.id == eventId) ?? -1;
      if (index != -1 && _cachedEvents != null) {
        _cachedEvents![index] = event;
        _eventsController.add(List.from(_cachedEvents!));
      }

      // Invalidate counts cache
      _cachedCounts = null;
    } catch (e) {
      // Cache for offline sync
      await _cacheService.cacheEventForOffline(eventId, event);
      rethrow;
    }
  }

  // Delete event with optimistic updates
  Future<void> deleteEvent(String eventId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _getEventsCollection().doc(eventId).delete();

      // Update local cache optimistically
      _cachedEvents?.removeWhere((e) => e.id == eventId);
      if (_cachedEvents != null) {
        _eventsController.add(List.from(_cachedEvents!));
      }

      // Invalidate counts cache
      _cachedCounts = null;
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  // Mark medication as completed
  Future<void> markMedicationCompleted(
    String eventId,
    MedicationEvent event,
  ) async {
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

    await updateEvent(eventId, updatedEvent);
  }

  // Mark note as completed
  Future<void> markNoteCompleted(String eventId, NoteEvent event) async {
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

    await updateEvent(eventId, updatedEvent);
  }

  // Get event counts with caching
  Future<Map<String, int>> getEventCounts() async {
    if (_currentUserId == null) return {};

    // Use cached counts if available and valid
    if (_cachedCounts != null) {
      return _cachedCounts!;
    }

    try {
      final allEvents = await getEvents();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final weekFromNow = today.add(const Duration(days: 7));

      final counts = {
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

      // Cache counts
      _cachedCounts = counts;
      await _cacheService.cacheEventCounts(_currentUserId, counts);
      _countsController.add(counts);

      return counts;
    } catch (e) {
      print('Error getting event counts: $e');
      return {};
    }
  }

  // Get events for a specific date (optimized)
  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await getEvents(startDate: startOfDay, endDate: endOfDay);
  }

  // Get upcoming events with limit
  Future<List<CalendarEvent>> getUpcomingEvents({int limit = 20}) async {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));

    final events = await getEvents(startDate: now, endDate: nextWeek);
    events.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return events.take(limit).toList();
  }

  // Get overdue medications
  Future<List<MedicationEvent>> getOverdueMedications() async {
    final now = DateTime.now();
    final events = await getEvents(type: EventType.medication, endDate: now);

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
  }

  // Get events for specific pet
  Future<List<CalendarEvent>> getEventsForPet(String petId) async {
    return await getEvents(petId: petId);
  }

  // Get events grouped by date for calendar display
  Future<Map<DateTime, List<CalendarEvent>>> getEventsGroupedByDate({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final events = await getEvents(startDate: startDate, endDate: endDate);
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

  // Force refresh from server
  Future<void> refresh() async {
    if (_currentUserId == null) return;

    _cachedEvents = null;
    _cachedCounts = null;
    _lastCacheUpdate = null;

    await initialize();
  }

  // Sync offline events
  Future<void> syncOfflineEvents() async {
    if (_currentUserId == null) return;

    try {
      final offlineEvents = await _cacheService.getOfflineEvents();

      for (final entry in offlineEvents.entries) {
        try {
          await _getEventsCollection().doc(entry.key).set(entry.value.toJson());
          await _cacheService.removeOfflineEvent(entry.key);
        } catch (e) {
          print('Error syncing offline event ${entry.key}: $e');
        }
      }

      // Refresh cache after sync
      await refresh();
    } catch (e) {
      print('Error syncing offline events: $e');
    }
  }

  // Helper method to get events collection
  CollectionReference<Map<String, dynamic>> _getEventsCollection() {
    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('events');
  }

  // Helper method to calculate next dose
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

  // Cleanup
  void dispose() {
    _eventsController.close();
    _countsController.close();
  }
}
