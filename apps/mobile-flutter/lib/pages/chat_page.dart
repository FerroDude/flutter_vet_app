import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../main.dart' show SettingsPage, ProfilePage;
import 'chat_room_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  @override
  void initState() {
    super.initState();
    _initializeChats();
  }

  void _initializeChats() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      final chatProvider = context.read<ChatProvider>();

      // Check if user has clinic connection before initializing
      if (userProvider.isPetOwner) {
        if (userProvider.hasClinicConnection) {
          chatProvider.initializeChatRooms(
            petOwnerId: userProvider.currentUser?.id,
          );
        }
        // Don't initialize if no clinic connection - will show appropriate message
      } else if (userProvider.isVet || userProvider.isClinicAdmin) {
        if (userProvider.connectedClinic?.id != null) {
          chatProvider.initializeChatRooms(
            clinicId: userProvider.connectedClinic?.id,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, UserProvider>(
      builder: (context, chatProvider, userProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Messages'),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),
              Consumer<UserProvider>(
                builder: (context, up, _) => IconButton(
                  tooltip: 'Profile',
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProfilePage(injectedUserProvider: up),
                      ),
                    );
                  },
                ),
              ),
              if (userProvider.isPetOwner)
                IconButton(
                  onPressed: () =>
                      _startNewChat(context, userProvider, chatProvider),
                  icon: const Icon(Icons.add_comment),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _refreshChats(chatProvider, userProvider),
            child: _buildChatsList(chatProvider, userProvider),
          ),
        );
      },
    );
  }

  Widget _buildChatsList(ChatProvider chatProvider, UserProvider userProvider) {
    // Check if pet owner is not connected to a clinic
    if (userProvider.isPetOwner && !userProvider.hasClinicConnection) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Connect to a Clinic',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'You need to connect to a veterinary clinic to start conversations with your vet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to clinic selection or settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Go to Settings > Clinic Connection to connect to a clinic',
                    ),
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Connect to Clinic'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (chatProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Error loading chats',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to connect to the chat service. Please check your internet connection and try again.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _refreshChats(chatProvider, userProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final chatRooms = chatProvider.chatRooms;

    if (chatRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              userProvider.isPetOwner
                  ? 'No conversations yet'
                  : 'No patient conversations',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              userProvider.isPetOwner
                  ? 'Start a conversation with your vet'
                  : 'Pet owners will appear here when they start conversations',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (userProvider.isPetOwner) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    _startNewChat(context, userProvider, chatProvider),
                icon: const Icon(Icons.add_comment),
                label: const Text('Start Conversation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: chatRooms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final chatRoom = chatRooms[index];
        return _buildChatRoomCard(chatRoom, chatProvider, userProvider);
      },
    );
  }

  Widget _buildChatRoomCard(
    ChatRoom chatRoom,
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) {
    final currentUserId = userProvider.currentUser?.id;
    final hasUnread = currentUserId != null
        ? chatRoom.hasUnreadMessages(currentUserId)
        : false;
    final unreadCount = currentUserId != null
        ? chatRoom.getUnreadCount(currentUserId)
        : 0;

    return Card(
      elevation: hasUnread ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasUnread
            ? BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3), width: 1)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              child: Icon(
                userProvider.isPetOwner ? Icons.medical_services : Icons.pets,
                color: AppTheme.primaryBlue,
              ),
            ),
            if (hasUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          userProvider.isPetOwner
              ? userProvider.connectedClinic?.name ?? 'Clinic'
              : chatRoom.petOwnerName,
          style: TextStyle(
            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chatRoom.topic != null) ...[
              const SizedBox(height: 4),
              Text(
                'Topic: ${chatRoom.topic}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
            if (chatRoom.lastMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                _getLastMessagePreview(chatRoom.lastMessage!),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _formatMessageTime(chatRoom.lastMessage!.timestamp),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openChatRoom(context, chatRoom, chatProvider),
      ),
    );
  }

  String _getLastMessagePreview(ChatMessage message) {
    switch (message.type) {
      case MessageType.text:
        return message.content;
      case MessageType.image:
        return '📷 Image';
      case MessageType.appointment:
        return '📅 Appointment';
      case MessageType.medication:
        return '💊 Medication';
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _refreshChats(
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) async {
    if (userProvider.isPetOwner) {
      if (userProvider.hasClinicConnection) {
        await chatProvider.initializeChatRooms(
          petOwnerId: userProvider.currentUser?.id,
        );
      }
    } else if (userProvider.isVet || userProvider.isClinicAdmin) {
      if (userProvider.connectedClinic?.id != null) {
        await chatProvider.initializeChatRooms(
          clinicId: userProvider.connectedClinic?.id,
        );
      }
    }
  }

  void _startNewChat(
    BuildContext context,
    UserProvider userProvider,
    ChatProvider chatProvider,
  ) {
    if (!userProvider.isPetOwner || !userProvider.hasClinicConnection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be connected to a clinic to start a chat'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _NewChatDialog(
        userProvider: userProvider,
        chatProvider: chatProvider,
      ),
    );
  }

  void _openChatRoom(
    BuildContext context,
    ChatRoom chatRoom,
    ChatProvider chatProvider,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatRoomPage(chatRoom: chatRoom)),
    );
  }
}

class _NewChatDialog extends StatefulWidget {
  final UserProvider userProvider;
  final ChatProvider chatProvider;

  const _NewChatDialog({
    required this.userProvider,
    required this.chatProvider,
  });

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final _topicController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start New Conversation'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clinic: ${widget.userProvider.connectedClinic?.name}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Topic (Optional)',
                hintText: 'What would you like to discuss?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createChat,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Start Chat'),
        ),
      ],
    );
  }

  Future<void> _createChat() async {
    setState(() => _isLoading = true);

    try {
      final user = widget.userProvider.currentUser;
      final clinic = widget.userProvider.connectedClinic;

      if (user == null || clinic == null) {
        throw Exception('User or clinic information not available');
      }

      // TODO: Update to handle one-on-one chat creation with vet selection
      // This needs vetId and vetName to create one-on-one chats
      throw Exception('Chat creation not yet implemented for one-on-one chats');
      // final chatRoomId = await widget.chatProvider.createOrFindOneOnOneChat(
      //   clinicId: clinic.id,
      //   petOwnerId: user.id,
      //   petOwnerName: user.displayName,
      //   vetId: 'SELECTED_VET_ID', // Need vet selection UI
      //   vetName: 'SELECTED_VET_NAME', // Need vet selection UI
      //   petIds: [], // TODO: Get user's pet IDs
      //   topic: _topicController.text.trim().isEmpty
      //       ? null
      //       : _topicController.text.trim(),
      // );

      // TODO: Handle successful chat creation when implemented
      // if (chatRoomId != null && mounted) {
      //   Navigator.pop(context);
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text('Chat started successfully'),
      //       backgroundColor: Colors.green,
      //     ),
      //   );
      // }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
