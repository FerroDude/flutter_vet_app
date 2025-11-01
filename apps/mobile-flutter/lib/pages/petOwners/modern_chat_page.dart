import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import 'chat_room_page.dart';
import '../../main.dart' show SettingsPage, ProfilePage;

/// Clean, professional chat page
class ModernChatPage extends StatefulWidget {
  const ModernChatPage({super.key});

  @override
  State<ModernChatPage> createState() => _ModernChatPageState();
}

class _ModernChatPageState extends State<ModernChatPage> {
  @override
  void initState() {
    super.initState();
    _initializeChats();
  }

  void _initializeChats() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      final chatProvider = context.read<ChatProvider>();

      if (userProvider.isPetOwner) {
        if (userProvider.hasClinicConnection) {
          chatProvider.initializeChatRooms(
            petOwnerId: userProvider.currentUser?.id,
          );
        }
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
          backgroundColor: context.surfacePrimary,
          appBar: AppBar(
            title: Text('Messages'),
            backgroundColor: context.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Profile',
                icon: Icon(Icons.person_outline),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfilePage(injectedUserProvider: userProvider),
                    ),
                  );
                },
              ),
              if (userProvider.isPetOwner)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () =>
                        _startNewChat(context, userProvider, chatProvider),
                    icon: const Icon(Icons.add_comment_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _refreshChats(chatProvider, userProvider),
            color: context.primaryColor,
            child: _buildChatsList(chatProvider, userProvider),
          ),
        );
      },
    );
  }

  Widget _buildChatsList(ChatProvider chatProvider, UserProvider userProvider) {
    // Check if pet owner is not connected to a clinic
    if (userProvider.isPetOwner && !userProvider.hasClinicConnection) {
      return _buildNoClinicState(context);
    }

    if (chatProvider.isLoading) {
      return _buildLoadingState(context);
    }

    if (chatProvider.error != null) {
      return _buildErrorState(context, chatProvider, userProvider);
    }

    final chatRooms = chatProvider.chatRooms;

    if (chatRooms.isEmpty) {
      return _buildEmptyState(context, userProvider, chatProvider);
    }

    return ListView.separated(
      padding: EdgeInsets.all(AppTheme.spacing4),
      itemCount: chatRooms.length,
      separatorBuilder: (context, index) => SizedBox(height: AppTheme.spacing3),
      itemBuilder: (context, index) {
        return _buildModernChatCard(
          context: context,
          chatRoom: chatRooms[index],
          chatProvider: chatProvider,
          userProvider: userProvider,
          delay: index * 50,
        );
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: context.primaryColor),
          SizedBox(height: AppTheme.spacing4),
          Text(
            'Loading conversations...',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.secondaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNoClinicState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.primaryColor.withOpacity(0.1),
                  context.primaryColor.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medical_services_outlined,
              size: 40,
              color: context.primaryColor,
            ),
          ),
          SizedBox(height: AppTheme.spacing6),
          Text(
            'Connect to a Clinic',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
          SizedBox(height: AppTheme.spacing2),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
            child: Text(
              'You need to connect to a veterinary clinic to start conversations with your vet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: AppTheme.spacing6),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Go to Settings > Clinic Connection to connect to a clinic',
                  ),
                  backgroundColor: context.primaryColor,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: Icon(Icons.add),
            label: Text('Connect to Clinic'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacing6,
                vertical: AppTheme.spacing4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: AppTheme.errorRed),
          SizedBox(height: AppTheme.spacing4),
          Text(
            'Error loading chats',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
          SizedBox(height: AppTheme.spacing2),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
            child: Text(
              'Unable to connect to the chat service. Please check your internet connection and try again.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: AppTheme.spacing6),
          ElevatedButton.icon(
            onPressed: () => _refreshChats(chatProvider, userProvider),
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    UserProvider userProvider,
    ChatProvider chatProvider,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.primaryColor.withOpacity(0.1),
                  context.primaryColor.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: context.primaryColor,
            ),
          ),
          SizedBox(height: AppTheme.spacing6),
          Text(
            userProvider.isPetOwner
                ? 'No conversations yet'
                : 'No patient conversations',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
          SizedBox(height: AppTheme.spacing2),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
            child: Text(
              userProvider.isPetOwner
                  ? 'Start a conversation with your vet'
                  : 'Pet owners will appear here when they start conversations',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (userProvider.isPetOwner) ...[
            SizedBox(height: AppTheme.spacing6),
            ElevatedButton.icon(
              onPressed: () =>
                  _startNewChat(context, userProvider, chatProvider),
              icon: Icon(Icons.add_comment),
              label: Text('Start Conversation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing6,
                  vertical: AppTheme.spacing4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernChatCard({
    required BuildContext context,
    required ChatRoom chatRoom,
    required ChatProvider chatProvider,
    required UserProvider userProvider,
    required int delay,
  }) {
    final currentUserId = userProvider.currentUser?.id;
    final hasUnread = currentUserId != null
        ? chatRoom.hasUnreadMessages(currentUserId)
        : false;
    final unreadCount = currentUserId != null
        ? chatRoom.getUnreadCount(currentUserId)
        : 0;

    final color = context.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: hasUnread ? color.withOpacity(0.3) : context.borderLight,
          width: hasUnread ? 2 : 1,
        ),
        boxShadow: hasUnread
            ? [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          onTap: () => _openChatRoom(context, chatRoom, chatProvider),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Row(
              children: [
                // Avatar with badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        userProvider.isPetOwner
                            ? Icons.medical_services
                            : Icons.pets,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.surfaceSecondary,
                              width: 2,
                            ),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: TextStyle(
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
                SizedBox(width: AppTheme.spacing4),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProvider.isPetOwner
                            ? userProvider.connectedClinic?.name ?? 'Clinic'
                            : chatRoom.petOwnerName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: context.textColor,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chatRoom.topic != null) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.topic, size: 12, color: color),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                chatRoom.topic!,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (chatRoom.lastMessage != null) ...[
                        SizedBox(height: AppTheme.spacing1),
                        Text(
                          _getLastMessagePreview(chatRoom.lastMessage!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.secondaryTextColor,
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatMessageTime(chatRoom.lastMessage!.timestamp),
                          style: TextStyle(
                            color: context.secondaryTextColor.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: AppTheme.spacing2),
                Icon(
                  Icons.chevron_right,
                  color: context.secondaryTextColor,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
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
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7) return '${difference.inDays} days ago';
      return '${(difference.inDays / 7).floor()} weeks ago';
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
        SnackBar(
          content: Text('You need to be connected to a clinic to start a chat'),
          backgroundColor: AppTheme.accentAmber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _ModernNewChatDialog(
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

class _ModernNewChatDialog extends StatefulWidget {
  final UserProvider userProvider;
  final ChatProvider chatProvider;

  const _ModernNewChatDialog({
    required this.userProvider,
    required this.chatProvider,
  });

  @override
  State<_ModernNewChatDialog> createState() => _ModernNewChatDialogState();
}

class _ModernNewChatDialogState extends State<_ModernNewChatDialog> {
  final _topicController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacing6),
        decoration: BoxDecoration(
          color: context.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.spacing2),
                  decoration: BoxDecoration(
                    color: context.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(Icons.add_comment, color: context.primaryColor),
                ),
                SizedBox(width: AppTheme.spacing3),
                Text(
                  'Start New Conversation',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.textColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacing4),
            Container(
              padding: EdgeInsets.all(AppTheme.spacing3),
              decoration: BoxDecoration(
                color: context.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_hospital,
                    size: 16,
                    color: context.primaryColor,
                  ),
                  SizedBox(width: AppTheme.spacing2),
                  Text(
                    'Clinic: ${widget.userProvider.connectedClinic?.name}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppTheme.spacing4),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                labelText: 'Topic (Optional)',
                hintText: 'What would you like to discuss?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                prefixIcon: Icon(Icons.topic),
              ),
              maxLines: 2,
            ),
            SizedBox(height: AppTheme.spacing6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                SizedBox(width: AppTheme.spacing2),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createChat,
                  icon: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.send),
                  label: Text('Start Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
      throw Exception('Chat creation not yet implemented for one-on-one chats');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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

// Extension methods are already defined in app_theme.dart
