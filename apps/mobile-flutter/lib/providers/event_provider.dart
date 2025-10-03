import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/event_model.dart';
import '../repositories/event_repository.dart';

import '../models/notification_service.dart';

class EventProvider extends ChangeNotifier {
  final EventRepository _repository;
  final NotificationService _notificationService;

  // State management
  List<CalendarEvent> _events = [];
  Map<String, int> _eventCounts = {};
  bool _isLoading = false;
  bool _isOnline = true;
  String? _error;

  // Stream subscriptions
  StreamSubscription<List<CalendarEvent>>? _eventsSubscription;
  StreamSubscription<Map<String, int>>? _countsSubscription;

  // Getters
  List<CalendarEvent> get events => _events;
  Map<String, int> get eventCounts => _eventCounts;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  String? get error => _error;
  String? get currentUserId => _repository.currentUserId;

  // Filtered events getters
  List<CalendarEvent> get appointments =>
      _events.where((event) => event.type == EventType.appointment).toList();

  List<CalendarEvent> get medications =>
      _events.where((event) => event.type == EventType.medication).toList();

  List<CalendarEvent> get notes =>
      _events.where((event) => event.type == EventType.note).toList();

  List<CalendarEvent> get upcomingEvents {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));

    return _events
        .where(
          (event) =>
              event.dateTime.isAfter(now) && event.dateTime.isBefore(nextWeek),
        )
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<MedicationEvent> get overdueMedications {
    final now = DateTime.now();
    return _events
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

  EventProvider(this._repository, this._notificationService) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _repository.initialize();
    _setupStreams();
    await loadEvents();
    await loadEventCounts();
  }

  void _setupStreams() {
    // Listen to repository events stream
    _eventsSubscription = _repository.eventsStream.listen((events) {
      _events = events;
      notifyListeners();
    });

    // Listen to repository counts stream
    _countsSubscription = _repository.countsStream.listen((counts) {
      _eventCounts = counts;
      notifyListeners();
    });
  }

  // Load events with caching
  Future<void> loadEvents({
    EventType? type,
    String? petId,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final events = await _repository.getEvents(
        type: type,
        petId: petId,
        startDate: startDate,
        endDate: endDate,
        forceRefresh: forceRefresh,
      );

      if (type == null &&
          petId == null &&
          startDate == null &&
          endDate == null) {
        _events = events;
      }

      // Schedule notifications for new events
      if (forceRefresh) {
        await _notificationService.rescheduleAllNotifications(events);
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load event counts
  Future<void> loadEventCounts() async {
    try {
      final counts = await _repository.getEventCounts();
      _eventCounts = counts;
      notifyListeners();
    } catch (e) {
      print('Error loading event counts: $e');
    }
  }

  // Create event with optimistic updates
  Future<String?> createEvent(CalendarEvent event) async {
    try {
      print('DEBUG: EventProvider.createEvent called');
      print('DEBUG: Event type: ${event.type}');
      print('DEBUG: Event data: ${event.toJson()}');

      final eventId = await _repository.createEvent(event);
      print('DEBUG: Repository returned eventId: $eventId');

      // Schedule notification
      if (event is MedicationEvent && event.requiresNotification) {
        await _notificationService.scheduleMedicationNotification(event);
      } else {
        await _notificationService.scheduleEventNotification(event);
      }

      print('DEBUG: Event created successfully with ID: $eventId');
      return eventId;
    } catch (e) {
      print('Error creating event: $e');
      // Reload events to sync state
      await loadEvents(forceRefresh: true);
      return null;
    }
  }

  // Update event
  Future<bool> updateEvent(String eventId, CalendarEvent event) async {
    try {
      await _repository.updateEvent(eventId, event);

      // Update notification
      await _notificationService.cancelNotification(eventId);
      if (event is MedicationEvent && event.requiresNotification) {
        await _notificationService.scheduleMedicationNotification(event);
      } else {
        await _notificationService.scheduleEventNotification(event);
      }

      return true;
    } catch (e) {
      print('Error updating event: $e');
      // Reload events to sync state
      await loadEvents(forceRefresh: true);
      return false;
    }
  }

  // Delete event
  Future<bool> deleteEvent(String eventId) async {
    try {
      await _repository.deleteEvent(eventId);

      // Cancel notification
      await _notificationService.cancelNotification(eventId);

      return true;
    } catch (e) {
      print('Error deleting event: $e');
      // Reload events to sync state
      await loadEvents(forceRefresh: true);
      return false;
    }
  }

  // Mark medication as completed
  Future<bool> markMedicationCompleted(
    String eventId,
    MedicationEvent event,
  ) async {
    try {
      await _repository.markMedicationCompleted(eventId, event);

      // Handle recurring medication
      if (event.isRecurring && event.nextDose != null) {
        final nextMedication = MedicationEvent(
          id: CalendarEvent.generateId(),
          title: event.title,
          description: event.description,
          dateTime: event.nextDose!,
          petId: event.petId,
          userId: event.userId,
          isRecurring: event.isRecurring,
          recurrencePattern: event.recurrencePattern,
          recurrenceInterval: event.recurrenceInterval,
          endDate: event.endDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          medicationName: event.medicationName,
          dosage: event.dosage,
          frequency: event.frequency,
          customIntervalMinutes: event.customIntervalMinutes,
          isCompleted: false,
          instructions: event.instructions,
          requiresNotification: event.requiresNotification,
        );

        await _repository.createEvent(nextMedication);

        if (nextMedication.requiresNotification) {
          await _notificationService.scheduleMedicationNotification(
            nextMedication,
          );
        }
      }

      return true;
    } catch (e) {
      print('Error marking medication completed: $e');
      return false;
    }
  }

  // Mark note as completed
  Future<bool> markNoteCompleted(String eventId, NoteEvent event) async {
    try {
      await _repository.markNoteCompleted(eventId, event);
      return true;
    } catch (e) {
      print('Error marking note completed: $e');
      return false;
    }
  }

  // Get events for specific date
  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    return await _repository.getEventsForDate(date);
  }

  // Get events grouped by date (for calendar display)
  Future<Map<DateTime, List<CalendarEvent>>> getEventsGroupedByDate({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _repository.getEventsGroupedByDate(
      startDate: startDate,
      endDate: endDate,
    );
  }

  // Get events for specific pet
  Future<List<CalendarEvent>> getEventsForPet(String petId) async {
    return await _repository.getEventsForPet(petId);
  }

  // Refresh data from server
  Future<void> refresh() async {
    await loadEvents(forceRefresh: true);
    await loadEventCounts();
  }

  // Sync offline events
  Future<void> syncOfflineEvents() async {
    try {
      await _repository.syncOfflineEvents();
      await refresh();
    } catch (e) {
      print('Error syncing offline events: $e');
    }
  }

  // Set network status
  void setNetworkStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      notifyListeners();

      // Sync offline events when coming back online
      if (isOnline) {
        syncOfflineEvents();
      }
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get events by type with caching
  List<CalendarEvent> getEventsByType(EventType type) {
    return _events.where((event) => event.type == type).toList();
  }

  // Get today's events
  List<CalendarEvent> get getTodaysEvents {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _events
        .where(
          (event) =>
              event.dateTime.isAfter(
                startOfDay.subtract(const Duration(seconds: 1)),
              ) &&
              event.dateTime.isBefore(endOfDay),
        )
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // Get this week's events
  List<CalendarEvent> get getThisWeeksEvents {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    return _events
        .where(
          (event) =>
              event.dateTime.isAfter(
                startOfWeek.subtract(const Duration(seconds: 1)),
              ) &&
              event.dateTime.isBefore(endOfWeek),
        )
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // Search events
  List<CalendarEvent> searchEvents(String query) {
    if (query.isEmpty) return _events;

    final lowercaseQuery = query.toLowerCase();
    return _events.where((event) {
      return event.title.toLowerCase().contains(lowercaseQuery) ||
          event.description.toLowerCase().contains(lowercaseQuery) ||
          (event is AppointmentEvent &&
              (event.vetName?.toLowerCase().contains(lowercaseQuery) ??
                  false)) ||
          (event is MedicationEvent &&
              event.medicationName.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  // Get events count by pet
  Map<String, int> getEventsCountByPet() {
    final counts = <String, int>{};
    for (final event in _events) {
      if (event.petId != null) {
        counts[event.petId!] = (counts[event.petId!] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _countsSubscription?.cancel();
    super.dispose();
  }
}
