import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ChatRoom> _chatRooms = [];
  ChatRoom? _currentChatRoom;
  List<ChatMessage> _currentMessages = [];
  List<ChatRoom> _pendingRequests = [];
  bool _isLoading = false;
  String? _error;
  int _totalUnreadCount = 0;
  bool _otherUserIsTyping = false;

  // Streams
  Stream<List<ChatRoom>>? _chatRoomsStream;
  Stream<List<ChatMessage>>? _messagesStream;
  Stream<List<ChatRoom>>? _pendingRequestsStream;
  StreamSubscription<bool>? _typingStatusSubscription;

  ChatProvider(this._chatService);

  // Getters
  List<ChatRoom> get chatRooms => _chatRooms;
  ChatRoom? get currentChatRoom => _currentChatRoom;
  List<ChatMessage> get currentMessages => _currentMessages;
  List<ChatRoom> get pendingRequests => _pendingRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalUnreadCount => _totalUnreadCount;
  bool get isOtherUserTyping => _otherUserIsTyping;

  // Stream getters
  Stream<List<ChatRoom>>? get chatRoomsStream => _chatRoomsStream;
  Stream<List<ChatMessage>>? get messagesStream => _messagesStream;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// CHAT ROOM MANAGEMENT ///

  // Initialize chat rooms for current user
  Future<void> initializeChatRooms({
    String? clinicId,
    String? petOwnerId,
    String? vetId,
    bool isAdmin = false,
  }) async {
    try {
      // Clear any previous errors before starting a fresh initialization
      _setError(null);
      _setLoading(true);

      if (isAdmin && clinicId != null) {
        // Initialize for clinic admin - see all clinic chats and requests
        _chatRoomsStream = _chatService.clinicChatRoomsStream(clinicId);
        _pendingRequestsStream = _chatService.clinicChatRequestsStream(
          clinicId,
        );
        _chatRooms = await _chatService.getClinicChatRooms(clinicId);
        _pendingRequests = await _chatService.getClinicChatRequests(clinicId);
      } else if (vetId != null && clinicId != null) {
        // Initialize for vet - see own chats + clinic pending requests
        _chatRoomsStream = _chatService.vetChatRoomsStream(vetId);
        _pendingRequestsStream = _chatService.clinicChatRequestsStream(
          clinicId,
        );
        _chatRooms = await _chatService.getVetChatRooms(vetId);
        _pendingRequests = await _chatService.getClinicChatRequests(clinicId);
      } else if (petOwnerId != null) {
        // Initialize for pet owner
        _chatRoomsStream = _chatService.petOwnerChatRoomsStream(petOwnerId);
        _chatRooms = await _chatService.getPetOwnerChatRooms(petOwnerId);
      }

      // Update total unread count
      await _updateTotalUnreadCount();

      _setLoading(false);

      // Listen to streams if available
      if (_chatRoomsStream != null) {
        _chatRoomsStream!.listen(updateChatRoomsFromStream);
      }
      if (_pendingRequestsStream != null) {
        _pendingRequestsStream!.listen(updatePendingRequestsFromStream);
      }
    } catch (e) {
      _setError('Failed to initialize chat rooms: $e');
      _setLoading(false);
    }
  }

  // Create or find one-on-one chat room
  Future<String?> createOrFindOneOnOneChat({
    required String clinicId,
    required String petOwnerId,
    required String petOwnerName,
    required String vetId,
    required String vetName,
    required List<String> petIds,
    String? topic,
  }) async {
    try {
      _setLoading(true);

      final chatRoomId = await _chatService.findOrCreateOneOnOneChat(
        clinicId: clinicId,
        petOwnerId: petOwnerId,
        petOwnerName: petOwnerName,
        vetId: vetId,
        vetName: vetName,
        petIds: petIds,
        topic: topic,
      );

      // Refresh chat rooms
      await _refreshChatRooms();

      _setLoading(false);
      return chatRoomId;
    } catch (e) {
      _setError('Failed to create chat room: $e');
      _setLoading(false);
      return null;
    }
  }

  // Select a chat room
  Future<void> selectChatRoom(String chatRoomId) async {
    try {
      _setLoading(true);

      // Get chat room details
      _currentChatRoom = await _chatService.getChatRoom(chatRoomId);

      if (_currentChatRoom != null) {
        // Initialize message stream
        _messagesStream = _chatService.messagesStream(chatRoomId);
        _currentMessages = await _chatService.getMessages(chatRoomId);

        // Listen for real-time message updates
        _messagesStream!.listen(updateMessagesFromStream);

        // Listen to typing status of the other user
        _listenToTypingStatus();

        // Mark messages as read
        await _chatService.markMessagesAsRead(chatRoomId);

        // Update total unread count
        await _updateTotalUnreadCount();
      }

      _setLoading(false);
    } catch (e) {
      _setError('Failed to select chat room: $e');
      _setLoading(false);
    }
  }

  // Leave current chat room
  void leaveChatRoom() {
    // Clean up typing status
    if (_currentChatRoom != null) {
      setTypingStatus(false);
    }

    // Cancel typing status subscription
    _typingStatusSubscription?.cancel();
    _typingStatusSubscription = null;
    _otherUserIsTyping = false;

    _currentChatRoom = null;
    _currentMessages = [];
    _messagesStream = null;
    notifyListeners();
  }

  /// MESSAGE MANAGEMENT ///

  // Send a text message
  Future<bool> sendTextMessage(String content) async {
    if (_currentChatRoom == null || content.trim().isEmpty) return false;
    final trimmed = content.trim();

    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Optimistically add message to current list so it appears immediately
      final now = DateTime.now();
      final optimisticMessage = ChatMessage(
        id: 'local_${now.millisecondsSinceEpoch}',
        chatId: _currentChatRoom!.id,
        senderId: user.uid,
        senderName: user.displayName ?? 'User',
        senderRole: _getUserRole(),
        content: trimmed,
        type: MessageType.text,
        status: MessageStatus.sent,
        timestamp: now,
      );

      // Messages are ordered oldest-first, so append at the end
      _currentMessages = [..._currentMessages, optimisticMessage];
      notifyListeners();

      await _chatService.sendMessage(
        chatRoomId: _currentChatRoom!.id,
        content: trimmed,
        senderName: user.displayName ?? 'User',
        senderRole: _getUserRole(),
      );

      // When Firestore sends the updated messages via the stream,
      // updateMessagesFromStream will replace this optimistic list
      // with the authoritative one, avoiding duplicates.
      return true;
    } catch (e) {
      // Remove the optimistic message if sending fails
      _currentMessages = _currentMessages
          .where((m) => !m.id.startsWith('local_'))
          .toList();
      notifyListeners();

      _setError('Failed to send message: $e');
      return false;
    }
  }

  // Send an appointment message
  Future<bool> sendAppointmentMessage({
    required String appointmentId,
    required String appointmentDetails,
  }) async {
    if (_currentChatRoom == null) return false;

    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _chatService.sendMessage(
        chatRoomId: _currentChatRoom!.id,
        content: 'Shared an appointment: $appointmentDetails',
        senderName: user.displayName ?? 'User',
        senderRole: _getUserRole(),
        type: MessageType.appointment,
        appointmentId: appointmentId,
      );

      return true;
    } catch (e) {
      _setError('Failed to send appointment message: $e');
      return false;
    }
  }

  // Send a medication message
  Future<bool> sendMedicationMessage({
    required String medicationId,
    required String medicationDetails,
  }) async {
    if (_currentChatRoom == null) return false;

    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _chatService.sendMessage(
        chatRoomId: _currentChatRoom!.id,
        content: 'Shared medication info: $medicationDetails',
        senderName: user.displayName ?? 'User',
        senderRole: _getUserRole(),
        type: MessageType.medication,
        medicationId: medicationId,
      );

      return true;
    } catch (e) {
      _setError('Failed to send medication message: $e');
      return false;
    }
  }

  /// VET MANAGEMENT ///

  /// Create a new chat request (pet owner -> clinic)
  Future<String?> createChatRequest({
    required String clinicId,
    required String petOwnerId,
    required String petOwnerName,
    required String title,
    String? description,
    List<String>? petIds,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Ensure there is at most one pending request per pet owner (per clinic)
      final existingRequest = await _chatService.getPendingRequestForPetOwner(
        clinicId: clinicId,
        petOwnerId: petOwnerId,
      );

      if (existingRequest != null) {
        _setLoading(false);
        _setError(
          'You already have a pending chat request. '
          'Please cancel it before creating a new one.',
        );
        return null;
      }

      final chatRoomId = await _chatService.createChatRequest(
        clinicId: clinicId,
        petOwnerId: petOwnerId,
        petOwnerName: petOwnerName,
        title: title,
        description: description,
        petIds: petIds,
      );

      _setLoading(false);
      return chatRoomId;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create chat request: $e');
      return null;
    }
  }

  /// Pet owner cancels an existing pending chat request.
  Future<bool> deleteChatRequest(String chatRoomId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _chatService.deleteChatRequest(chatRoomId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to delete chat request: $e');
      return false;
    }
  }

  /// Vet accepts a pending chat request and becomes the assigned vet
  Future<bool> acceptChatRequest({
    required String chatRoomId,
    required String vetId,
    required String vetName,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      await _chatService.acceptChatRequest(
        chatRoomId: chatRoomId,
        vetId: vetId,
        vetName: vetName,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to accept chat request: $e');
      return false;
    }
  }

  /// Delete/close a chat room (removes for both vet and pet owner)
  Future<bool> deleteChatRoom(String chatRoomId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _chatService.deleteChatRoom(chatRoomId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to delete chat room: $e');
      return false;
    }
  }

  /// TYPING STATUS METHODS ///

  /// Update typing status for current user
  Future<void> setTypingStatus(bool isTyping) async {
    if (_currentChatRoom == null) return;

    try {
      await _chatService.updateTypingStatus(_currentChatRoom!.id, isTyping);
    } catch (e) {
      developer.log('Failed to set typing status: $e', name: 'ChatProvider');
    }
  }

  /// Listen to typing status of the other participant
  void _listenToTypingStatus() {
    if (_currentChatRoom == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    // Get the other participant's ID
    final otherUserId = _currentChatRoom!.getOtherParticipantId(user.uid);
    if (otherUserId.isEmpty) {
      return; // No other user yet (e.g., pending request)
    }

    // Cancel any existing subscription
    _typingStatusSubscription?.cancel();

    // Listen to the other user's typing status
    _typingStatusSubscription = _chatService
        .typingStatusStream(_currentChatRoom!.id, otherUserId)
        .listen((isTyping) {
          if (_otherUserIsTyping != isTyping) {
            _otherUserIsTyping = isTyping;
            notifyListeners();
          }
        });
  }

  /// UTILITY METHODS ///

  // Update total unread count
  Future<void> _updateTotalUnreadCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final newCount = await _chatService.getTotalUnreadCount(user.uid);
      if (_totalUnreadCount != newCount) {
        _totalUnreadCount = newCount;
        notifyListeners();
      }
    } catch (e) {
      developer.log(
        'Failed to update total unread count: $e',
        name: 'ChatProvider',
      );
    }
  }

  // Refresh chat rooms
  Future<void> _refreshChatRooms() async {
    try {
      // This will be called by the stream, but we can force refresh if needed
      notifyListeners();
    } catch (e) {
      developer.log('Failed to refresh chat rooms: $e', name: 'ChatProvider');
    }
  }

  // Get user role for current user
  String _getUserRole() {
    // This should be determined based on user's actual role
    // For now, return a default value
    return 'pet_owner'; // missing:  Get from UserProvider
  }

  // Update chat rooms from stream
  void updateChatRoomsFromStream(List<ChatRoom> chatRooms) {
    _chatRooms = chatRooms;
    _updateTotalUnreadCount();
    notifyListeners();
  }

  // Update messages from stream
  void updateMessagesFromStream(List<ChatMessage> messages) {
    _currentMessages = messages;
    notifyListeners();
  }

  // Update pending requests from stream
  void updatePendingRequestsFromStream(List<ChatRoom> requests) {
    _pendingRequests = requests;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get unread count for specific chat room
  int getUnreadCount(String chatRoomId) {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final chatRoom = _chatRooms.firstWhere(
      (room) => room.id == chatRoomId,
      orElse: () => _chatRooms.first,
    );

    return chatRoom.getUnreadCount(user.uid);
  }

  // Check if user has unread messages in specific chat
  bool hasUnreadMessages(String chatRoomId) {
    return getUnreadCount(chatRoomId) > 0;
  }
}
