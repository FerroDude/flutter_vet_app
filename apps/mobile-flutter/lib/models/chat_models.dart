import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, appointment, medication }

enum MessageStatus { sent, delivered, read }

/// Status of a chat room lifecycle
enum ChatRoomStatus {
  /// Request created by pet owner, waiting for vet to accept
  pending,

  /// Active conversation between pet owner and a specific vet
  active,

  /// Conversation closed / archived (not used yet, reserved for future)
  closed,
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'pet_owner', 'vet', 'admin'
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final String? imageUrl;
  final String? appointmentId;
  final String? medicationId;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.type,
    required this.status,
    required this.timestamp,
    this.imageUrl,
    this.appointmentId,
    this.medicationId,
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String id) {
    return ChatMessage(
      id: id,
      chatId: json['chatId'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      senderRole: json['senderRole'],
      content: json['content'],
      type: MessageType.values[json['type']],
      status: MessageStatus.values[json['status']],
      timestamp: _parseDateTime(json['timestamp']),
      imageUrl: json['imageUrl'],
      appointmentId: json['appointmentId'],
      medicationId: json['medicationId'],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'content': content,
      'type': type.index,
      'status': status.index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'imageUrl': imageUrl,
      'appointmentId': appointmentId,
      'medicationId': medicationId,
      'metadata': metadata,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      return DateTime.parse(value);
    }
    throw ArgumentError('Invalid datetime value: $value');
  }

  ChatMessage copyWith({
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
    String? imageUrl,
    String? appointmentId,
    String? medicationId,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      appointmentId: appointmentId ?? this.appointmentId,
      medicationId: medicationId ?? this.medicationId,
      metadata: metadata ?? this.metadata,
    );
  }
}

class ChatRoom {
  final String id;
  final String clinicId;
  final String petOwnerId;
  final String petOwnerName;
  final String vetId;
  final String vetName;
  final List<String> petIds;
  final ChatMessage? lastMessage;
  final Map<String, int> unreadCounts; // userId -> unread count
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? topic; // Optional chat topic
  final ChatRoomStatus status;
  final String? requestDescription; // optional long description from pet owner

  const ChatRoom({
    required this.id,
    required this.clinicId,
    required this.petOwnerId,
    required this.petOwnerName,
    required this.vetId,
    required this.vetName,
    required this.petIds,
    this.lastMessage,
    required this.unreadCounts,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.topic,
    this.status = ChatRoomStatus.active,
    this.requestDescription,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json, String id) {
    final int rawStatus = json['status'] is int
        ? json['status'] as int
        : ChatRoomStatus.active.index;
    final safeStatus = (rawStatus >= 0 && rawStatus < ChatRoomStatus.values.length)
        ? ChatRoomStatus.values[rawStatus]
        : ChatRoomStatus.active;

    return ChatRoom(
      id: id,
      clinicId: json['clinicId'],
      petOwnerId: json['petOwnerId'],
      petOwnerName: json['petOwnerName'],
      vetId: json['vetId'],
      vetName: json['vetName'],
      petIds: List<String>.from(json['petIds'] ?? []),
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(
              json['lastMessage'] as Map<String, dynamic>,
              json['lastMessage']['id'] ?? '',
            )
          : null,
      unreadCounts: Map<String, int>.from(json['unreadCounts'] ?? {}),
      createdAt: ChatMessage._parseDateTime(json['createdAt']),
      updatedAt: ChatMessage._parseDateTime(json['updatedAt']),
      isActive: json['isActive'] ?? true,
      topic: json['topic'],
      status: safeStatus,
      requestDescription: json['requestDescription'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clinicId': clinicId,
      'petOwnerId': petOwnerId,
      'petOwnerName': petOwnerName,
      'vetId': vetId,
      'vetName': vetName,
      'petIds': petIds,
      'lastMessage': lastMessage?.toJson(),
      'unreadCounts': unreadCounts,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isActive': isActive,
      'topic': topic,
      'status': status.index,
      'requestDescription': requestDescription,
    };
  }

  ChatRoom copyWith({
    String? clinicId,
    String? petOwnerId,
    String? petOwnerName,
    String? vetId,
    String? vetName,
    List<String>? petIds,
    ChatMessage? lastMessage,
    Map<String, int>? unreadCounts,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? topic,
    ChatRoomStatus? status,
    String? requestDescription,
  }) {
    return ChatRoom(
      id: id,
      clinicId: clinicId ?? this.clinicId,
      petOwnerId: petOwnerId ?? this.petOwnerId,
      petOwnerName: petOwnerName ?? this.petOwnerName,
      vetId: vetId ?? this.vetId,
      vetName: vetName ?? this.vetName,
      petIds: petIds ?? this.petIds,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      topic: topic ?? this.topic,
      status: status ?? this.status,
      requestDescription: requestDescription ?? this.requestDescription,
    );
  }

  // Helper methods
  int getUnreadCount(String userId) => unreadCounts[userId] ?? 0;
  bool hasUnreadMessages(String userId) => getUnreadCount(userId) > 0;

  // Get the other participant in this one-on-one chat
  String getOtherParticipantId(String currentUserId) {
    return currentUserId == petOwnerId ? vetId : petOwnerId;
  }

  String getOtherParticipantName(String currentUserId) {
    return currentUserId == petOwnerId ? vetName : petOwnerName;
  }
}
