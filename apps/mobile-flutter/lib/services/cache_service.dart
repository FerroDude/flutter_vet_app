import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event_model.dart';

class CacheService {
  static const String _eventsKey = 'cached_events';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _userIdKey = 'current_user_id';
  static const Duration _cacheValidity = Duration(hours: 2);

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Cache events with user ID - temporarily disabled due to Timestamp serialization issues
  Future<void> cacheEvents(String userId, List<CalendarEvent> events) async {
    // missing: Fix Timestamp serialization in event models before re-enabling caching
    // Caching is disabled to prevent serialization errors
    return;
  }

  // Get cached events
  Future<List<CalendarEvent>?> getCachedEvents(String userId) async {
    try {
      final cachedData = _prefs.getString(_eventsKey);
      if (cachedData == null) return null;

      final decoded = jsonDecode(cachedData);
      if (decoded['userId'] != userId) return null;

      final timestamp = decoded['timestamp'];
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheValidity.inMilliseconds) return null;

      final eventsJson = decoded['events'] as List;
      return eventsJson.map((json) => CalendarEvent.fromJson(json)).toList();
    } catch (e) {
      developer.log('Error reading cached events: $e', name: 'CacheService');
      return null;
    }
  }

  // Check if cache is valid
  Future<bool> isCacheValid(String userId) async {
    try {
      final cachedData = _prefs.getString(_eventsKey);
      if (cachedData == null) return false;

      final decoded = jsonDecode(cachedData);
      if (decoded['userId'] != userId) return false;

      final timestamp = decoded['timestamp'];
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      return cacheAge <= _cacheValidity.inMilliseconds;
    } catch (e) {
      return false;
    }
  }

  // Get last sync timestamp
  DateTime? getLastSyncTime() {
    final timestamp = _prefs.getInt(_lastSyncKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // Clear cache
  Future<void> clearCache() async {
    await _prefs.remove(_eventsKey);
    await _prefs.remove(_lastSyncKey);
    await _prefs.remove(_userIdKey);
  }

  // Get cached user ID
  String? getCachedUserId() {
    return _prefs.getString(_userIdKey);
  }

  // Cache event counts for dashboard
  Future<void> cacheEventCounts(String userId, Map<String, int> counts) async {
    try {
      final cacheData = {
        'userId': userId,
        'counts': counts,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await _prefs.setString('event_counts', jsonEncode(cacheData));
    } catch (e) {
      developer.log('Error caching event counts: $e', name: 'CacheService');
    }
  }

  Future<Map<String, int>?> getCachedEventCounts(String userId) async {
    try {
      final cachedData = _prefs.getString('event_counts');
      if (cachedData == null) return null;

      final decoded = jsonDecode(cachedData);
      if (decoded['userId'] != userId) return null;

      final timestamp = decoded['timestamp'];
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > _cacheValidity.inMilliseconds) return null;

      return Map<String, int>.from(decoded['counts']);
    } catch (e) {
      developer.log(
        'Error reading cached event counts: $e',
        name: 'CacheService',
      );
      return null;
    }
  }

  // Cache individual event for offline editing
  Future<void> cacheEventForOffline(String eventId, CalendarEvent event) async {
    try {
      final offlineEvents = _prefs.getString('offline_events') ?? '{}';
      final decoded = jsonDecode(offlineEvents) as Map<String, dynamic>;
      decoded[eventId] = event.toJson();
      await _prefs.setString('offline_events', jsonEncode(decoded));
    } catch (e) {
      developer.log(
        'Error caching event for offline: $e',
        name: 'CacheService',
      );
    }
  }

  // Get offline events
  Future<Map<String, CalendarEvent>> getOfflineEvents() async {
    try {
      final offlineEvents = _prefs.getString('offline_events') ?? '{}';
      final decoded = jsonDecode(offlineEvents) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, CalendarEvent.fromJson(value)),
      );
    } catch (e) {
      developer.log('Error reading offline events: $e', name: 'CacheService');
      return {};
    }
  }

  // Remove offline event after sync
  Future<void> removeOfflineEvent(String eventId) async {
    try {
      final offlineEvents = _prefs.getString('offline_events') ?? '{}';
      final decoded = jsonDecode(offlineEvents) as Map<String, dynamic>;
      decoded.remove(eventId);
      await _prefs.setString('offline_events', jsonEncode(decoded));
    } catch (e) {
      developer.log('Error removing offline event: $e', name: 'CacheService');
    }
  }

  // Clear all offline events
  Future<void> clearOfflineEvents() async {
    await _prefs.remove('offline_events');
  }
}
