import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import '../models/chat_models.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final rtdb.FirebaseDatabase _database = rtdb.FirebaseDatabase.instance;

  // Collection references
  CollectionReference get _chatRoomsCollection =>
      _firestore.collection('chatRooms');

  CollectionReference _getMessagesCollection(String chatRoomId) {
    return _chatRoomsCollection.doc(chatRoomId).collection('messages');
  }

  /// CHAT ROOM MANAGEMENT ///

  // Create a new one-on-one chat room between pet owner and vet
  Future<String> createChatRoom({
    required String clinicId,
    required String petOwnerId,
    required String petOwnerName,
    required String vetId,
    required String vetName,
    required List<String> petIds,
    String? topic,
    ChatRoomStatus status = ChatRoomStatus.active,
    String? requestDescription,
  }) async {
    try {
      final now = DateTime.now();
      final chatRoom = ChatRoom(
        id: '', // Will be set by Firestore
        clinicId: clinicId,
        petOwnerId: petOwnerId,
        petOwnerName: petOwnerName,
        vetId: vetId,
        vetName: vetName,
        petIds: petIds,
        unreadCounts: {},
        createdAt: now,
        updatedAt: now,
        topic: topic,
        status: status,
        requestDescription: requestDescription,
      );

      final docRef = await _chatRoomsCollection.add(chatRoom.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create chat room: $e');
    }
  }

  // Find or create a one-on-one chat between pet owner and vet
  Future<String> findOrCreateOneOnOneChat({
    required String clinicId,
    required String petOwnerId,
    required String petOwnerName,
    required String vetId,
    required String vetName,
    List<String>? petIds,
    String? topic,
  }) async {
    try {
      // Check if a chat already exists between this pet owner and vet
      final existingChat = await _chatRoomsCollection
          .where('clinicId', isEqualTo: clinicId)
          .where('petOwnerId', isEqualTo: petOwnerId)
          .where('vetId', isEqualTo: vetId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (existingChat.docs.isNotEmpty) {
        return existingChat.docs.first.id;
      }

      // Create new chat room (immediately active)
      return await createChatRoom(
        clinicId: clinicId,
        petOwnerId: petOwnerId,
        petOwnerName: petOwnerName,
        vetId: vetId,
        vetName: vetName,
        petIds: petIds ?? [],
        topic: topic,
        status: ChatRoomStatus.active,
      );
    } catch (e) {
      throw Exception('Failed to find or create chat: $e');
    }
  }

  // Get chat rooms for a vet
  Future<List<ChatRoom>> getVetChatRooms(String vetId) async {
    try {
      final snapshot = await _chatRoomsCollection
          .where('vetId', isEqualTo: vetId)
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) =>
                ChatRoom.fromJson(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get vet chat rooms: $e');
    }
  }

  // Get chat rooms for a clinic (for admins)
  Future<List<ChatRoom>> getClinicChatRooms(String clinicId) async {
    try {
      final snapshot = await _chatRoomsCollection
          .where('clinicId', isEqualTo: clinicId)
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) =>
                ChatRoom.fromJson(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get clinic chat rooms: $e');
    }
  }

  // Get chat rooms for a pet owner
  Future<List<ChatRoom>> getPetOwnerChatRooms(String petOwnerId) async {
    try {
      final snapshot = await _chatRoomsCollection
          .where('petOwnerId', isEqualTo: petOwnerId)
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) =>
                ChatRoom.fromJson(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get pet owner chat rooms: $e');
    }
  }

  /// Get an existing pending chat request for a given pet owner + clinic, if any.
  ///
  /// We intentionally avoid `orderBy` here so this works without a composite index.
  Future<ChatRoom?> getPendingRequestForPetOwner({
    required String clinicId,
    required String petOwnerId,
  }) async {
    try {
      final snapshot = await _chatRoomsCollection
          .where('clinicId', isEqualTo: clinicId)
          .where('petOwnerId', isEqualTo: petOwnerId)
          .where('isActive', isEqualTo: true)
          .where('status', isEqualTo: ChatRoomStatus.pending.index)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return ChatRoom.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      throw Exception('Failed to check existing chat request: $e');
    }
  }

  /// Get pending chat requests for a clinic (status == pending)
  Future<List<ChatRoom>> getClinicChatRequests(String clinicId) async {
    try {
      final snapshot = await _chatRoomsCollection
          .where('clinicId', isEqualTo: clinicId)
          .where('isActive', isEqualTo: true)
          .where('status', isEqualTo: ChatRoomStatus.pending.index)
          .get();

      final rooms = snapshot.docs
          .map(
            (doc) =>
                ChatRoom.fromJson(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

      // Sort newest requests first on the client to avoid needing a composite index
      rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rooms;
    } catch (e) {
      throw Exception('Failed to get clinic chat requests: $e');
    }
  }

  Stream<List<ChatRoom>> clinicChatRequestsStream(String clinicId) {
    return _chatRoomsCollection
        .where('clinicId', isEqualTo: clinicId)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: ChatRoomStatus.pending.index)
        .snapshots()
        .map((snap) {
          final rooms = snap.docs
              .map(
                (doc) => ChatRoom.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();

          rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rooms;
        });
  }

  /// Create a new chat request from a pet owner to a clinic (no vet assigned yet)
  Future<String> createChatRequest({
    required String clinicId,
    required String petOwnerId,
    required String petOwnerName,
    required String title,
    String? description,
    List<String>? petIds,
  }) async {
    try {
      // For requests, vet is not yet assigned; store empty ids/names.
      return await createChatRoom(
        clinicId: clinicId,
        petOwnerId: petOwnerId,
        petOwnerName: petOwnerName,
        vetId: '',
        vetName: '',
        petIds: petIds ?? [],
        topic: title,
        status: ChatRoomStatus.pending,
        requestDescription: description,
      );
    } catch (e) {
      throw Exception('Failed to create chat request: $e');
    }
  }

  /// Vet accepts a pending chat request and becomes the assigned vet
  Future<void> acceptChatRequest({
    required String chatRoomId,
    required String vetId,
    required String vetName,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final roomRef = _chatRoomsCollection.doc(chatRoomId);
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) {
          throw Exception('Chat room no longer exists');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final currentStatusIndex =
            (data['status'] ?? ChatRoomStatus.active.index) as int;

        if (currentStatusIndex != ChatRoomStatus.pending.index) {
          // Someone else already accepted or room is active; do nothing.
          throw Exception('Chat request already accepted or closed');
        }

        transaction.update(roomRef, {
          'vetId': vetId,
          'vetName': vetName,
          'status': ChatRoomStatus.active.index,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to accept chat request: $e');
    }
  }

  /// Delete a pending chat request (pet owner cancels before a vet accepts).
  Future<void> deleteChatRequest(String chatRoomId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final roomRef = _chatRoomsCollection.doc(chatRoomId);
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) {
          throw Exception('Chat room no longer exists');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final currentStatusIndex =
            (data['status'] ?? ChatRoomStatus.active.index) as int;

        if (currentStatusIndex != ChatRoomStatus.pending.index) {
          throw Exception('Only pending chat requests can be deleted');
        }

        transaction.delete(roomRef);
      });
    } catch (e) {
      throw Exception('Failed to delete chat request: $e');
    }
  }

  /// Delete/close a chat room completely (removes for both participants)
  /// This sets isActive to false rather than deleting, preserving data
  Future<void> deleteChatRoom(String chatRoomId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final roomRef = _chatRoomsCollection.doc(chatRoomId);
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) {
          throw Exception('Chat room no longer exists');
        }

        // Set isActive to false to "soft delete" the chat room
        // This removes it from both participants' chat lists
        transaction.update(roomRef, {
          'isActive': false,
          'status': ChatRoomStatus.closed.index,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to delete chat room: $e');
    }
  }

  // Get a specific chat room
  Future<ChatRoom?> getChatRoom(String chatRoomId) async {
    try {
      final doc = await _chatRoomsCollection.doc(chatRoomId).get();
      if (doc.exists) {
        return ChatRoom.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get chat room: $e');
    }
  }

  /// MESSAGE MANAGEMENT ///

  // Send a text message
  Future<void> sendMessage({
    required String chatRoomId,
    required String content,
    required String senderName,
    required String senderRole,
    MessageType type = MessageType.text,
    String? imageUrl,
    String? appointmentId,
    String? medicationId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final message = ChatMessage(
        id: '', // Will be set by Firestore
        chatId: chatRoomId,
        senderId: currentUser.uid,
        senderName: senderName,
        senderRole: senderRole,
        content: content,
        type: type,
        status: MessageStatus.sent,
        timestamp: now,
        imageUrl: imageUrl,
        appointmentId: appointmentId,
        medicationId: medicationId,
        metadata: metadata,
      );

      final batch = _firestore.batch();

      // Add message
      final messageRef = _getMessagesCollection(chatRoomId).doc();
      batch.set(messageRef, message.toJson());

      // Update chat room with last message and unread counts
      final chatRoomRef = _chatRoomsCollection.doc(chatRoomId);

      // Get current chat room to update unread counts
      final chatRoom = await getChatRoom(chatRoomId);
      if (chatRoom != null) {
        final updatedUnreadCounts = Map<String, int>.from(
          chatRoom.unreadCounts,
        );

        // Increment unread count for the other participant
        final otherParticipantId = chatRoom.getOtherParticipantId(
          currentUser.uid,
        );
        // Firestore does not allow empty field names; skip if we don't yet
        // have a valid other participant (e.g. pending chat request without vet)
        if (otherParticipantId.isNotEmpty) {
          updatedUnreadCounts[otherParticipantId] =
              (updatedUnreadCounts[otherParticipantId] ?? 0) + 1;
        }

        batch.update(chatRoomRef, {
          'lastMessage': message.toJson(),
          'unreadCounts': updatedUnreadCounts,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get messages for a chat room
  // Returns messages in chronological order (oldest first for display)
  Future<List<ChatMessage>> getMessages(
    String chatRoomId, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      // Query newest messages first to get the most recent ones
      Query query = _getMessagesCollection(
        chatRoomId,
      ).orderBy('timestamp', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      // Reverse to get chronological order (oldest first) for display
      return snapshot.docs
          .map(
            (doc) => ChatMessage.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList()
          .reversed
          .toList();
    } catch (e) {
      throw Exception('Failed to get messages: $e');
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatRoomRef = _chatRoomsCollection.doc(chatRoomId);

      await chatRoomRef.update({'unreadCounts.${currentUser.uid}': 0});
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  /// Mark individual messages from other users as 'read' status
  Future<void> markMessagesAsReadStatus(String chatRoomId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get messages from other users that are still 'sent' status
      final messagesSnapshot = await _getMessagesCollection(
        chatRoomId,
      ).where('senderId', isNotEqualTo: currentUser.uid).get();

      if (messagesSnapshot.docs.isEmpty) return;

      // Filter to only messages with 'sent' status and batch update them
      final batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in messagesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final statusIndex = data['status'] as int? ?? 0;

        // Only update if status is 'sent' (index 0)
        if (statusIndex == MessageStatus.sent.index) {
          batch.update(doc.reference, {
            'status': MessageStatus.read.index,
            'readAt': FieldValue.serverTimestamp(),
          });
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      // Log but don't throw - read receipts are not critical
      // ignore: avoid_print
      print('Failed to update message read status: $e');
    }
  }

  /// STREAMS FOR REAL-TIME UPDATES ///

  // Stream chat rooms for a vet
  Stream<List<ChatRoom>> vetChatRoomsStream(String vetId) {
    return _chatRoomsCollection
        .where('vetId', isEqualTo: vetId)
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ChatRoom.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  // Stream chat rooms for a clinic
  Stream<List<ChatRoom>> clinicChatRoomsStream(String clinicId) {
    return _chatRoomsCollection
        .where('clinicId', isEqualTo: clinicId)
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ChatRoom.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  // Stream chat rooms for a pet owner
  Stream<List<ChatRoom>> petOwnerChatRoomsStream(String petOwnerId) {
    return _chatRoomsCollection
        .where('petOwnerId', isEqualTo: petOwnerId)
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ChatRoom.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  // Stream messages for a chat room
  // Returns messages in chronological order (oldest first for display)
  Stream<List<ChatMessage>> messagesStream(
    String chatRoomId, {
    int limit = 50,
  }) {
    // Query newest messages first to get the most recent ones
    return _getMessagesCollection(chatRoomId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ChatMessage.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList()
              .reversed  // Reverse to get chronological order for display
              .toList(),
        );
  }

  // Stream a specific chat room
  Stream<ChatRoom?> chatRoomStream(String chatRoomId) {
    return _chatRoomsCollection.doc(chatRoomId).snapshots().map((doc) {
      if (doc.exists) {
        return ChatRoom.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  /// TYPING STATUS METHODS (using Firebase Realtime Database) ///

  /// Update typing status for current user in a chat room
  /// Sets typing status with timestamp in /typing/{chatRoomId}/{userId}
  Future<void> updateTypingStatus(String chatRoomId, bool isTyping) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final typingRef = _database.ref('typing/$chatRoomId/${currentUser.uid}');

      if (isTyping) {
        await typingRef.set({
          'isTyping': true,
          'timestamp': rtdb.ServerValue.timestamp,
        });
      } else {
        // Remove typing status when user stops typing
        await typingRef.remove();
      }
    } catch (e) {
      // Silently fail for typing indicators - not critical
      // ignore: avoid_print
      print('Failed to update typing status: $e');
    }
  }

  /// Stream typing status for another user in a chat room
  /// Returns a stream that emits true when the other user is typing
  /// Auto-expires after 3 seconds of inactivity
  Stream<bool> typingStatusStream(String chatRoomId, String otherUserId) {
    final typingRef = _database.ref('typing/$chatRoomId/$otherUserId');

    return typingRef.onValue.map((event) {
      if (!event.snapshot.exists) return false;

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return false;

      final isTyping = data['isTyping'] as bool? ?? false;
      final timestamp = data['timestamp'] as int? ?? 0;

      if (!isTyping) return false;

      // Check if typing status is stale (older than 3 seconds)
      final now = DateTime.now().millisecondsSinceEpoch;
      final age = now - timestamp;
      final isStale = age > 3000; // 3 seconds

      return isTyping && !isStale;
    });
  }

  /// UTILITY METHODS ///

  // Get unread message count for user across all chats
  Future<int> getTotalUnreadCount(String userId) async {
    try {
      // Get chats where user is either pet owner or vet
      final petOwnerSnapshot = await _chatRoomsCollection
          .where('petOwnerId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final vetSnapshot = await _chatRoomsCollection
          .where('vetId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final allDocs = [...petOwnerSnapshot.docs, ...vetSnapshot.docs];

      int totalUnread = 0;
      for (final doc in allDocs) {
        final chatRoom = ChatRoom.fromJson(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        totalUnread += chatRoom.getUnreadCount(userId);
      }

      return totalUnread;
    } catch (e) {
      throw Exception('Failed to get total unread count: $e');
    }
  }
}
