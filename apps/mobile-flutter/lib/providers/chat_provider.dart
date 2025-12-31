import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:image_picker/image_picker.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/media_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;
  final MediaService _mediaService = MediaService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ChatRoom> _chatRooms = [];
  ChatRoom? _currentChatRoom;
  List<ChatMessage> _currentMessages = [];
  List<ChatRoom> _pendingRequests = [];
  bool _isLoading = false;
  String? _error;
  int _totalUnreadCount = 0;
  bool _otherUserIsTyping = false;
  
  // Media upload state
  bool _isUploadingMedia = false;
  double _uploadProgress = 0.0;
  
  // Voice recording state
  bool _isRecording = false;
  int _recordingDuration = 0;

  // Pagination state
  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;

  // Scroll position cache per chat room (for restoring scroll position)
  final Map<String, double> _scrollPositions = {};

  // UI freeze state - prevents new messages from triggering rebuilds while user reads
  bool _uiFrozen = false;
  List<ChatMessage>? _frozenMessages; // Snapshot of messages when frozen
  Set<String> _frozenMessageIds = {}; // IDs of messages when frozen
  Set<String> _newMessageIds = {}; // IDs of NEW messages that arrived while frozen

  // Track active chat room ID to prevent race conditions with stream callbacks
  String? _activeChatRoomId;

  // Streams
  Stream<List<ChatRoom>>? _chatRoomsStream;
  Stream<List<ChatMessage>>? _messagesStream;
  Stream<List<ChatRoom>>? _pendingRequestsStream;
  StreamSubscription<List<ChatMessage>>? _messagesStreamSubscription;
  StreamSubscription<bool>? _typingStatusSubscription;

  ChatProvider(this._chatService);

  // Getters
  List<ChatRoom> get chatRooms => _chatRooms;
  ChatRoom? get currentChatRoom => _currentChatRoom;
  // currentMessages getter is defined below with freeze-aware logic
  List<ChatRoom> get pendingRequests => _pendingRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalUnreadCount => _totalUnreadCount;
  bool get isOtherUserTyping => _otherUserIsTyping;
  bool get isLoadingMoreMessages => _isLoadingMoreMessages;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get isUiFrozen => _uiFrozen;
  bool get isUploadingMedia => _isUploadingMedia;
  double get uploadProgress => _uploadProgress;
  MediaService get mediaService => _mediaService;
  bool get isRecording => _isRecording;
  int get recordingDuration => _recordingDuration;
  
  /// Returns the count of new messages that arrived while UI is frozen
  int get pendingMessageCount {
    if (!_uiFrozen) return 0;
    return _newMessageIds.length;
  }
  
  /// Returns frozen messages when frozen, otherwise current messages
  List<ChatMessage> get currentMessages {
    if (_uiFrozen && _frozenMessages != null) {
      return _frozenMessages!;
    }
    return _currentMessages;
  }

  // Stream getters
  Stream<List<ChatRoom>>? get chatRoomsStream => _chatRoomsStream;
  Stream<List<ChatMessage>>? get messagesStream => _messagesStream;

  /// SCROLL POSITION PERSISTENCE ///

  /// Save scroll position for a chat room
  void saveScrollPosition(String chatRoomId, double position) {
    _scrollPositions[chatRoomId] = position;
  }

  /// Get saved scroll position for a chat room (returns 0 if not saved)
  double getSavedScrollPosition(String chatRoomId) {
    return _scrollPositions[chatRoomId] ?? 0.0;
  }

  /// Clear saved scroll position for a chat room
  void clearScrollPosition(String chatRoomId) {
    _scrollPositions.remove(chatRoomId);
  }

  /// UI FREEZE - Prevents message updates from triggering rebuilds while user reads ///

  /// Freeze UI updates - snapshot current messages and ignore new ones
  void freezeUI() {
    if (_uiFrozen) return;
    
    _uiFrozen = true;
    _frozenMessages = List.from(_currentMessages); // Snapshot current state
    _frozenMessageIds = _currentMessages.map((m) => m.id).toSet(); // Track IDs
    _newMessageIds = {}; // Reset new message tracking
  }

  /// Unfreeze UI and show any pending messages
  void unfreezeUI() {
    if (!_uiFrozen) return;
    
    _uiFrozen = false;
    _frozenMessages = null;
    _frozenMessageIds = {};
    _newMessageIds = {};
    
    // Always trigger rebuild to show current state
    notifyListeners();
  }

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

      // Mark any pending messages as delivered when chat rooms initialize
      await markAllMessagesAsDeliveredOnSync();
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
      developer.log('selectChatRoom called: $chatRoomId', name: 'ChatProvider');

      // Get chat room details
      _currentChatRoom = await _chatService.getChatRoom(chatRoomId);

      if (_currentChatRoom != null) {
        // Set active chat room ID FIRST to enable read receipts
        _activeChatRoomId = chatRoomId;
        developer.log(
          '_activeChatRoomId set to: $chatRoomId',
          name: 'ChatProvider',
        );

        // Cancel any existing messages subscription before creating a new one
        _messagesStreamSubscription?.cancel();

        // Initialize message stream
        _messagesStream = _chatService.messagesStream(chatRoomId);
        _currentMessages = await _chatService.getMessages(chatRoomId);

        // Reset pagination state for new chat
        _hasMoreMessages = true;
        _isLoadingMoreMessages = false;

        // Listen for real-time message updates and store the subscription
        _messagesStreamSubscription = _messagesStream!.listen(
          updateMessagesFromStream,
        );

        // Listen to typing status of the other user
        _listenToTypingStatus();

        // Mark messages as read
        await _chatService.markMessagesAsRead(chatRoomId);

        //Update individual message statuses to 'read'
        await _chatService.markMessagesAsReadStatus(chatRoomId);

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
    developer.log(
      'leaveChatRoom called. Previous _activeChatRoomId: $_activeChatRoomId',
      name: 'ChatProvider',
    );

    // Clear active chat room ID FIRST to prevent any race conditions
    // with stream callbacks that might still fire
    _activeChatRoomId = null;
    developer.log('_activeChatRoomId cleared to null', name: 'ChatProvider');

    // Clean up typing status
    if (_currentChatRoom != null) {
      setTypingStatus(false);
    }

    // Cancel messages stream subscription - pause first to stop events immediately
    _messagesStreamSubscription?.pause();
    _messagesStreamSubscription?.cancel();
    _messagesStreamSubscription = null;
    developer.log(
      'Messages stream subscription cancelled',
      name: 'ChatProvider',
    );

    // Cancel typing status subscription
    _typingStatusSubscription?.pause();
    _typingStatusSubscription?.cancel();
    _typingStatusSubscription = null;
    _otherUserIsTyping = false;

    _currentChatRoom = null;
    _currentMessages = [];
    _messagesStream = null;
    notifyListeners();
  }

  /// MESSAGE MANAGEMENT ///

  // Send a text message with optional reply metadata
  Future<bool> sendTextMessage(String content, {Map<String, dynamic>? metadata}) async {
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
        metadata: metadata,
      );

      // Messages are ordered oldest-first, so append at the end
      _currentMessages = [..._currentMessages, optimisticMessage];
      notifyListeners();

      await _chatService.sendMessage(
        chatRoomId: _currentChatRoom!.id,
        content: trimmed,
        senderName: user.displayName ?? 'User',
        senderRole: _getUserRole(),
        metadata: metadata,
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

  /// MEDIA MESSAGE METHODS ///

  /// Pick and send an image from gallery
  Future<bool> pickAndSendImageFromGallery() async {
    return _pickAndSendImage(ImageSource.gallery);
  }

  /// Pick and send an image from camera
  Future<bool> pickAndSendImageFromCamera() async {
    return _pickAndSendImage(ImageSource.camera);
  }

  /// Pick and send a video from gallery
  Future<bool> pickAndSendVideoFromGallery() async {
    return _pickAndSendVideo(ImageSource.gallery);
  }

  /// Pick and send a video from camera
  Future<bool> pickAndSendVideoFromCamera() async {
    return _pickAndSendVideo(ImageSource.camera);
  }

  /// Pick and send files
  Future<bool> pickAndSendFiles() async {
    if (_currentChatRoom == null) return false;

    try {
      final files = await _mediaService.pickFiles();
      if (files.isEmpty) return false;

      for (final file in files) {
        await _sendMediaFile(file);
      }
      return true;
    } catch (e) {
      _setError('Failed to send files: $e');
      return false;
    }
  }

  /// Internal method to pick and send an image
  Future<bool> _pickAndSendImage(ImageSource source) async {
    if (_currentChatRoom == null) return false;

    try {
      final file = await _mediaService.pickImage(source: source);
      if (file == null) return false;

      return await _sendMediaFile(file);
    } catch (e) {
      _setError('Failed to send image: $e');
      return false;
    }
  }

  /// Internal method to pick and send a video
  Future<bool> _pickAndSendVideo(ImageSource source) async {
    if (_currentChatRoom == null) return false;

    try {
      final file = await _mediaService.pickVideo(source: source);
      if (file == null) return false;

      return await _sendMediaFile(file);
    } catch (e) {
      // Extract clean error message without "Exception:" prefix
      final errorMessage = e.toString()
          .replaceAll('Exception: ', '')
          .replaceAll('Failed to pick video: ', '');
      _setError(errorMessage);
      return false;
    }
  }

  /// Send a media file (image, video, or document)
  Future<bool> _sendMediaFile(File file) async {
    if (_currentChatRoom == null) return false;

    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      _isUploadingMedia = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // Upload the file
      final result = await _mediaService.uploadMedia(
        file: file,
        chatRoomId: _currentChatRoom!.id,
        senderId: user.uid,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );

      // Determine message type and content
      MessageType messageType;
      String content;
      switch (result.mediaType) {
        case MediaType.image:
          messageType = MessageType.image;
          content = '📷 Photo';
          break;
        case MediaType.video:
          messageType = MessageType.video;
          content = '🎬 Video';
          break;
        case MediaType.file:
          messageType = MessageType.file;
          content = '📎 ${result.fileName}';
          break;
        case MediaType.voice:
          messageType = MessageType.voice;
          content = '🎤 Voice message';
          break;
      }

      // Send the message with media info
      await _chatService.sendMessage(
        chatRoomId: _currentChatRoom!.id,
        content: content,
        senderName: user.displayName ?? 'User',
        senderRole: _getUserRole(),
        type: messageType,
        mediaUrl: result.mediaUrl,
        thumbnailUrl: result.thumbnailUrl,
        fileName: result.fileName,
        fileSize: result.fileSize,
        mimeType: result.mimeType,
        audioDuration: result.audioDuration,
      );

      _isUploadingMedia = false;
      _uploadProgress = 0.0;
      notifyListeners();

      return true;
    } catch (e) {
      _isUploadingMedia = false;
      _uploadProgress = 0.0;
      notifyListeners();

      _setError('Failed to send media: $e');
      return false;
    }
  }

  /// VOICE RECORDING METHODS ///

  /// Start voice recording
  Future<bool> startVoiceRecording() async {
    if (_currentChatRoom == null) return false;
    if (_isRecording) return false;

    try {
      final started = await _mediaService.startRecording();
      if (started) {
        _isRecording = true;
        _recordingDuration = 0;
        notifyListeners();
        
        // Start duration timer
        _startRecordingTimer();
      }
      return started;
    } catch (e) {
      _setError('Failed to start recording: $e');
      return false;
    }
  }

  /// Timer to update recording duration
  void _startRecordingTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isRecording) return false;
      
      _recordingDuration = _mediaService.getRecordingDuration();
      notifyListeners();
      
      // Auto-stop at max duration
      if (_recordingDuration >= MediaConfig.maxVoiceDuration) {
        await stopAndSendVoiceRecording();
        return false;
      }
      
      return true;
    });
  }

  /// Stop recording and send voice message
  Future<bool> stopAndSendVoiceRecording() async {
    if (_currentChatRoom == null) return false;
    if (!_isRecording) return false;

    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      _isRecording = false;
      notifyListeners();

      final result = await _mediaService.stopRecording();
      if (result == null) {
        _setError('Failed to stop recording');
        return false;
      }

      // Don't send if too short (less than 1 second)
      if (result.durationSeconds < 1) {
        await result.file.delete();
        return false;
      }

      _isUploadingMedia = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // Upload the voice message
      final uploadResult = await _mediaService.uploadVoiceMessage(
        file: result.file,
        durationSeconds: result.durationSeconds,
        chatRoomId: _currentChatRoom!.id,
        senderId: user.uid,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );

      // Send the message
      await _chatService.sendMessage(
        chatRoomId: _currentChatRoom!.id,
        content: '🎤 Voice message',
        senderName: user.displayName ?? 'User',
        senderRole: _getUserRole(),
        type: MessageType.voice,
        mediaUrl: uploadResult.mediaUrl,
        fileName: uploadResult.fileName,
        fileSize: uploadResult.fileSize,
        mimeType: uploadResult.mimeType,
        audioDuration: uploadResult.audioDuration,
      );

      // Clean up temp file
      await result.file.delete();

      _isUploadingMedia = false;
      _uploadProgress = 0.0;
      _recordingDuration = 0;
      notifyListeners();

      return true;
    } catch (e) {
      _isRecording = false;
      _isUploadingMedia = false;
      _uploadProgress = 0.0;
      _recordingDuration = 0;
      notifyListeners();

      _setError('Failed to send voice message: $e');
      return false;
    }
  }

  /// Cancel voice recording
  Future<void> cancelVoiceRecording() async {
    if (!_isRecording) return;

    _isRecording = false;
    _recordingDuration = 0;
    notifyListeners();

    await _mediaService.cancelRecording();
  }

  /// Load older messages for pagination (when user scrolls up)
  Future<void> loadMoreMessages() async {
    if (_currentChatRoom == null) return;
    if (_isLoadingMoreMessages) return;
    if (!_hasMoreMessages) return;
    if (_currentMessages.isEmpty) return;

    try {
      _isLoadingMoreMessages = true;
      notifyListeners();

      // Get the oldest message timestamp (first in chronologically sorted list)
      final oldestMessage = _currentMessages.first;
      final beforeTimestamp = oldestMessage.timestamp;


      final result = await _chatService.getOlderMessages(
        _currentChatRoom!.id,
        beforeTimestamp: beforeTimestamp,
      );

      if (result.messages.isNotEmpty) {
        // Prepend older messages to the beginning of the list
        _currentMessages = [...result.messages, ..._currentMessages];
        
        // If UI is frozen, also update frozen messages (for pagination while scrolled up)
        if (_uiFrozen && _frozenMessages != null) {
          _frozenMessages = [...result.messages, ..._frozenMessages!];
          // Add these IDs to frozen set so they're not counted as "new"
          for (final msg in result.messages) {
            _frozenMessageIds.add(msg.id);
          }
        }
      }

      _hasMoreMessages = result.hasMore;


      _isLoadingMoreMessages = false;
      notifyListeners();
    } catch (e) {
      developer.log('Failed to load more messages: $e', name: 'ChatProvider');
      _isLoadingMoreMessages = false;
      notifyListeners();
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

  /// REACTION METHODS ///

  /// Toggle a reaction on a message (add or remove)
  Future<bool> toggleReaction(String messageId, String emoji) async {
    if (_currentChatRoom == null) return false;

    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _chatService.toggleReaction(
        chatRoomId: _currentChatRoom!.id,
        messageId: messageId,
        emoji: emoji,
        userName: user.displayName ?? 'User',
      );

      return true;
    } catch (e) {
      developer.log('Failed to toggle reaction: $e', name: 'ChatProvider');
      return false;
    }
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

    // Mark messages as delivered for all chats when they arrive on this device
    // This ensures "delivered" status (✓✓ gray) appears when recipient's device
    // receives the message, not just when they open the specific chat
    _markNewMessagesAsDelivered(chatRooms);
  }

  /// Mark messages as delivered for chat rooms that have new unread messages
  /// This is called when the chat list updates with new messages
  Future<void> _markNewMessagesAsDelivered(List<ChatRoom> chatRooms) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    for (final chatRoom in chatRooms) {
      // Check if there are unread messages in this chat (messages from other user)
      final unreadCount = chatRoom.getUnreadCount(currentUserId);
      if (unreadCount > 0) {
        // Mark these messages as delivered
        try {
          await _chatService.markMessagesAsDelivered(chatRoom.id);
        } catch (e) {
          developer.log(
            'Failed to mark messages as delivered for chat ${chatRoom.id}: $e',
            name: 'ChatProvider',
          );
        }
      }
    }
  }

  // Update messages from stream
  void updateMessagesFromStream(List<ChatMessage> messages) {
    developer.log(
      'updateMessagesFromStream called. _activeChatRoomId: $_activeChatRoomId, message count: ${messages.length}, frozen: $_uiFrozen',
      name: 'ChatProvider',
    );
    
    // Always update the internal messages list
    _currentMessages = messages;

    // Only process status updates if chat is currently active
    if (_activeChatRoomId != null) {
      // STEP 1: Mark incoming messages as DELIVERED first
      _maybeMarkMessagesAsDelivered(messages);

      // STEP 2: Then mark as READ (existing behavior)
      _maybeMarkMessagesAsRead(messages);
    } else {
      developer.log(
        'Skipping message status updates - chat not active',
        name: 'ChatProvider',
      );
    }

    // If UI is frozen, track NEW messages by checking IDs we haven't seen
    if (_uiFrozen) {
      final currentUserId = _auth.currentUser?.uid;
      for (final msg in messages) {
        // Only count messages from OTHER user that weren't in frozen set
        if (!_frozenMessageIds.contains(msg.id) && 
            msg.senderId != currentUserId) {
          _newMessageIds.add(msg.id);
        }
      }
    }

    // Always notify - but currentMessages getter returns frozen snapshot when frozen
    notifyListeners();
  }

  /// Mark messages from other user as 'delivered' when they arrive on this device
  Future<void> _maybeMarkMessagesAsDelivered(List<ChatMessage> messages) async {
    final activeChatId = _activeChatRoomId;
    if (activeChatId == null) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Check if there are any messages from OTHER user still in 'sent' status
    final hasUndeliveredFromOther = messages.any(
      (msg) =>
          msg.senderId != currentUserId && msg.status == MessageStatus.sent,
    );

    if (!hasUndeliveredFromOther) return;

    // Double-check active chat hasn't changed
    if (_activeChatRoomId != activeChatId) return;

    developer.log(
      'MARKING MESSAGES AS DELIVERED for chat: $activeChatId',
      name: 'ChatProvider',
    );

    try {
      await _chatService.markMessagesAsDelivered(activeChatId);
    } catch (e) {
      developer.log(
        'Failed to mark messages as delivered: $e',
        name: 'ChatProvider',
      );
    }
  }

  /// Check if there are unread messages from the other user and mark them as read
  Future<void> _maybeMarkMessagesAsRead(List<ChatMessage> messages) async {
    // Use _activeChatRoomId for the check - it's cleared immediately when leaving
    final activeChatId = _activeChatRoomId;
    developer.log(
      '_maybeMarkMessagesAsRead called. activeChatId: $activeChatId',
      name: 'ChatProvider',
    );
    if (activeChatId == null) {
      developer.log('Skipping - activeChatId is null', name: 'ChatProvider');
      return;
    }

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Check if there are any unread messages from the OTHER user
    // Messages can be in 'sent' or 'delivered' status - both need to be marked as read
    final hasUnreadFromOther = messages.any(
      (msg) =>
          msg.senderId != currentUserId &&
          (msg.status == MessageStatus.sent ||
              msg.status == MessageStatus.delivered),
    );

    // Only call Firestore if there are actually messages to mark as read
    if (!hasUnreadFromOther) {
      developer.log(
        'Skipping - no unread messages from other',
        name: 'ChatProvider',
      );
      return;
    }

    // Double-check the active chat hasn't changed during async operations
    if (_activeChatRoomId != activeChatId) {
      developer.log(
        'Skipping - activeChatId changed during execution',
        name: 'ChatProvider',
      );
      return;
    }

    developer.log(
      'MARKING MESSAGES AS READ for chat: $activeChatId',
      name: 'ChatProvider',
    );

    try {
      // This updates message statuses in Firestore
      await _chatService.markMessagesAsReadStatus(activeChatId);
      // Also update the unread count on the chat room
      await _chatService.markMessagesAsRead(activeChatId);
    } catch (e) {
      developer.log(
        'Failed to mark new messages as read: $e',
        name: 'ChatProvider',
      );
    }
  }

  // Update pending requests from stream
  void updatePendingRequestsFromStream(List<ChatRoom> requests) {
    _pendingRequests = requests;
    notifyListeners();
  }

  /// Called when app comes to foreground or user logs in
  /// Marks all undelivered messages across all chats as 'delivered'
  Future<void> markAllMessagesAsDeliveredOnSync() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Mark delivered for all active chat rooms
      for (final chatRoom in _chatRooms) {
        await _chatService.markMessagesAsDelivered(chatRoom.id);
      }

      developer.log(
        'Marked messages as delivered across ${_chatRooms.length} chats',
        name: 'ChatProvider',
      );
    } catch (e) {
      developer.log(
        'Failed to mark messages as delivered on sync: $e',
        name: 'ChatProvider',
      );
    }
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
