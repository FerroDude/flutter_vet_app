import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ChatRoom> _chatRooms = [];
  ChatRoom? _currentChatRoom;
  List<ChatMessage> _currentMessages = [];
  bool _isLoading = false;
  String? _error;
  int _totalUnreadCount = 0;

  // Streams
  Stream<List<ChatRoom>>? _chatRoomsStream;
  Stream<List<ChatMessage>>? _messagesStream;

  ChatProvider(this._chatService);

  // Getters
  List<ChatRoom> get chatRooms => _chatRooms;
  ChatRoom? get currentChatRoom => _currentChatRoom;
  List<ChatMessage> get currentMessages => _currentMessages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalUnreadCount => _totalUnreadCount;

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
      _setLoading(true);

      if (isAdmin && clinicId != null) {
        // Initialize for clinic admin - see all clinic chats
        _chatRoomsStream = _chatService.clinicChatRoomsStream(clinicId);
        _chatRooms = await _chatService.getClinicChatRooms(clinicId);
      } else if (vetId != null) {
        // Initialize for vet - see only their own chats
        _chatRoomsStream = _chatService.vetChatRoomsStream(vetId);
        _chatRooms = await _chatService.getVetChatRooms(vetId);
      } else if (petOwnerId != null) {
        // Initialize for pet owner
        _chatRoomsStream = _chatService.petOwnerChatRoomsStream(petOwnerId);
        _chatRooms = await _chatService.getPetOwnerChatRooms(petOwnerId);
      }

      // Update total unread count
      await _updateTotalUnreadCount();

      _setLoading(false);
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
    _currentChatRoom = null;
    _currentMessages = [];
    _messagesStream = null;
    notifyListeners();
  }

  /// MESSAGE MANAGEMENT ///

  // Send a text message
  Future<bool> sendTextMessage(String content) async {
    if (_currentChatRoom == null || content.trim().isEmpty) return false;

    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _chatService.sendMessage(
        chatRoomId: _currentChatRoom!.id,
        content: content.trim(),
        senderName: user.displayName ?? 'User',
        senderRole: _getUserRole(),
      );

      return true;
    } catch (e) {
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
      print('Failed to update total unread count: $e');
    }
  }

  // Refresh chat rooms
  Future<void> _refreshChatRooms() async {
    try {
      // This will be called by the stream, but we can force refresh if needed
      notifyListeners();
    } catch (e) {
      print('Failed to refresh chat rooms: $e');
    }
  }

  // Get user role for current user
  String _getUserRole() {
    // This should be determined based on user's actual role
    // For now, return a default value
    return 'pet_owner'; // TODO: Get from UserProvider
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
