import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../main.dart';

/// Types of push notifications for navigation routing
enum PushNotificationType {
  // Appointment requests
  newAppointmentRequest,
  appointmentConfirmed,
  appointmentDenied,

  // Chat (for future use)
  newChatRequest,
  chatRequestAccepted,
  newChatMessage,

  // Medications (for future use)
  medicationReminder,

  // Generic
  generic,
}

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  // Note: This runs in its own isolate, so we can't access providers directly
  debugPrint('Background message received: ${message.messageId}');
}

/// Service for handling Firebase Cloud Messaging push notifications.
///
/// This service manages:
/// - FCM initialization and permissions
/// - Token management (get, refresh, save to Firestore)
/// - Foreground message handling
/// - Background message handling
/// - Notification tap handling for navigation
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) : _messaging = messaging,
       _firestore = firestore ?? FirebaseFirestore.instance;

  @visibleForTesting
  factory PushNotificationService.test({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) => PushNotificationService._internal(
    messaging: messaging,
    firestore: firestore,
  );

  FirebaseMessaging? _messaging;
  final FirebaseFirestore _firestore;

  FirebaseMessaging get _messagingClient =>
      _messaging ??= FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  String? _currentToken;
  bool _initialized = false;

  /// Get the current FCM token
  String? get currentToken => _currentToken;

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Check if notifications are currently authorized
  Future<bool> areNotificationsAuthorized() async {
    final settings = await _messagingClient.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Get current notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    return await _messagingClient.getNotificationSettings();
  }

  /// Request notification permissions (public method)
  Future<bool> requestPermissions() async {
    final settings = await _requestPermissions();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Check if user has notifications enabled (FCM token saved in Firestore)
  Future<bool> hasNotificationsEnabled(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data();
      return data?['fcmToken'] != null &&
          (data?['fcmToken'] as String).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking notification status: $e');
      return false;
    }
  }

  /// Enable notifications for user - request permission and save token
  Future<bool> enableNotifications(String userId) async {
    try {
      // Request permission if not already granted
      final authorized = await requestPermissions();
      if (!authorized) {
        debugPrint('Notification permission not granted');
        return false;
      }

      // Get token and save it
      await _getToken();
      if (_currentToken == null) {
        debugPrint('Could not get FCM token');
        return false;
      }

      await saveTokenForUser(userId);
      return true;
    } catch (e) {
      debugPrint('Error enabling notifications: $e');
      return false;
    }
  }

  /// Disable notifications for user - clear token from Firestore
  Future<bool> disableNotifications(String userId) async {
    try {
      await clearTokenForUser(userId);
      return true;
    } catch (e) {
      debugPrint('Error disabling notifications: $e');
      return false;
    }
  }

  /// Initialize the push notification service.
  /// Call this in main() after Firebase.initializeApp()
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Request permissions (required for iOS, optional prompt for Android 13+)
      await _requestPermissions();

      // Get initial token
      await _getToken();

      // Listen for token refresh
      _setupTokenRefreshListener();

      // Handle foreground messages
      _setupForegroundMessageHandler();

      // Handle notification taps (when app is opened from notification)
      _setupNotificationTapHandlers();

      _initialized = true;
      debugPrint('PushNotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing PushNotificationService: $e');
    }
  }

  /// Request notification permissions
  Future<NotificationSettings> _requestPermissions() async {
    final settings = await _messagingClient.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
      'Notification permission status: ${settings.authorizationStatus}',
    );
    return settings;
  }

  /// Get the current FCM token
  Future<String?> _getToken() async {
    try {
      // For iOS, ensure APNS token is available first
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _messagingClient.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('APNS token not yet available');
          // Token will be retrieved on refresh
          return null;
        }
      }

      _currentToken = await _messagingClient.getToken();
      debugPrint('FCM Token: $_currentToken');
      return _currentToken;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Set up listener for token refresh
  void _setupTokenRefreshListener() {
    _tokenRefreshSubscription = _messagingClient.onTokenRefresh.listen(
      (newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _currentToken = newToken;

        // Auto-save to Firestore if user is logged in
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          saveTokenForUser(userId);
        }
      },
      onError: (error) {
        debugPrint('Error on token refresh: $error');
      },
    );
  }

  /// Set up handler for foreground messages
  void _setupForegroundMessageHandler() {
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      debugPrint('Foreground message received: ${message.messageId}');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');

      // TODO: Show local notification or in-app banner
      // For now, we'll just log the message
      // In a full implementation, you might want to:
      // 1. Show a snackbar/toast
      // 2. Update a notification badge
      // 3. Refresh data in relevant providers
    });
  }

  /// Set up handlers for notification taps
  void _setupNotificationTapHandlers() {
    // Handle notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app was terminated
    _messagingClient.getInitialMessage().then((message) {
      if (message != null) {
        // Small delay to ensure app is fully initialized
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNotificationTap(message);
        });
      }
    });
  }

  /// Handle notification tap - navigate to appropriate screen
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');

    final data = message.data;
    final type = _parseNotificationType(data['type']);

    // Get the navigator context
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('No navigator context available for notification tap');
      return;
    }

    switch (type) {
      case PushNotificationType.newAppointmentRequest:
        // Navigate to appointment requests page (for receptionists)
        _navigateToAppointmentRequests(data);
        break;

      case PushNotificationType.appointmentConfirmed:
      case PushNotificationType.appointmentDenied:
        // Navigate to my appointments page (for pet owners)
        _navigateToMyAppointments(data);
        break;

      case PushNotificationType.newChatRequest:
      case PushNotificationType.chatRequestAccepted:
        // Navigate to chat list
        _navigateToChatList(data);
        break;

      case PushNotificationType.newChatMessage:
        // Navigate to specific chat room
        _navigateToChatRoom(data);
        break;

      case PushNotificationType.medicationReminder:
        // Navigate to medications
        _navigateToMedications(data);
        break;

      case PushNotificationType.generic:
        // Just open the app (already done)
        break;
    }
  }

  /// Parse notification type from string
  PushNotificationType _parseNotificationType(String? typeString) {
    if (typeString == null) return PushNotificationType.generic;

    switch (typeString) {
      case 'new_appointment_request':
        return PushNotificationType.newAppointmentRequest;
      case 'appointment_confirmed':
        return PushNotificationType.appointmentConfirmed;
      case 'appointment_denied':
        return PushNotificationType.appointmentDenied;
      case 'new_chat_request':
        return PushNotificationType.newChatRequest;
      case 'chat_request_accepted':
        return PushNotificationType.chatRequestAccepted;
      case 'new_chat_message':
        return PushNotificationType.newChatMessage;
      case 'medication_reminder':
        return PushNotificationType.medicationReminder;
      default:
        return PushNotificationType.generic;
    }
  }

  // Navigation methods - these will be implemented as we build the features
  void _navigateToAppointmentRequests(Map<String, dynamic> data) {
    // TODO: Implement navigation to appointment requests page
    debugPrint('Navigate to appointment requests: $data');
  }

  void _navigateToMyAppointments(Map<String, dynamic> data) {
    // TODO: Implement navigation to my appointments page
    debugPrint('Navigate to my appointments: $data');
  }

  void _navigateToChatList(Map<String, dynamic> data) {
    // TODO: Implement navigation to chat list
    debugPrint('Navigate to chat list: $data');
  }

  void _navigateToChatRoom(Map<String, dynamic> data) {
    // TODO: Implement navigation to specific chat room
    final chatRoomId = data['chatRoomId'];
    debugPrint('Navigate to chat room: $chatRoomId');
  }

  void _navigateToMedications(Map<String, dynamic> data) {
    // TODO: Implement navigation to medications
    debugPrint('Navigate to medications: $data');
  }

  /// Save the current FCM token to Firestore for the given user
  Future<void> saveTokenForUser(String userId) async {
    if (_currentToken == null) {
      // Try to get token first
      await _getToken();
    }

    if (_currentToken == null) {
      debugPrint('No FCM token available to save');
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': _currentToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM token saved for user: $userId');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Clear the FCM token for the given user (call on logout)
  Future<void> clearTokenForUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
      debugPrint('FCM token cleared for user: $userId');
    } catch (e) {
      debugPrint('Error clearing FCM token: $e');
    }
  }

  /// Delete the FCM token from the device (useful for complete logout)
  Future<void> deleteToken() async {
    try {
      await _messagingClient.deleteToken();
      _currentToken = null;
      debugPrint('FCM token deleted from device');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  /// Dispose of the service (cancel subscriptions)
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _initialized = false;
  }

  @visibleForTesting
  void setCurrentTokenForTesting(String? token) {
    _currentToken = token;
  }
}
