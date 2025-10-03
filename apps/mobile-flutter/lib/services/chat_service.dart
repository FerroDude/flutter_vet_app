import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

      // Create new chat room
      return await createChatRoom(
        clinicId: clinicId,
        petOwnerId: petOwnerId,
        petOwnerName: petOwnerName,
        vetId: vetId,
        vetName: vetName,
        petIds: petIds ?? [],
        topic: topic,
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
        updatedUnreadCounts[otherParticipantId] =
            (updatedUnreadCounts[otherParticipantId] ?? 0) + 1;

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
  Future<List<ChatMessage>> getMessages(
    String chatRoomId, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _getMessagesCollection(
        chatRoomId,
      ).orderBy('timestamp', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) => ChatMessage.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
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
  Stream<List<ChatMessage>> messagesStream(
    String chatRoomId, {
    int limit = 50,
  }) {
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
