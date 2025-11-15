import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:getwidget/getwidget.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../shared/widgets/app_components.dart';
import 'chat_room_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';

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
            vetId: userProvider.isVet ? userProvider.currentUser?.id : null,
            isAdmin: userProvider.isClinicAdmin,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, UserProvider>(
      builder: (context, chatProvider, userProvider, child) {
        final hasPendingRequest = userProvider.isPetOwner &&
            chatProvider.chatRooms
                .any((room) => room.status == ChatRoomStatus.pending);

        return Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            title: Text(
              'Chat',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SettingsPage(injectedUserProvider: userProvider),
                    ),
                  );
                },
                tooltip: 'Settings',
              ),
              IconButton(
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
                tooltip: 'Profile',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _refreshChats(chatProvider, userProvider),
            child: _buildChatsList(chatProvider, userProvider),
          ),
          floatingActionButton: userProvider.isPetOwner &&
                  userProvider.hasClinicConnection &&
                  !hasPendingRequest
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      _showNewChatRequestDialog(chatProvider, userProvider),
                  backgroundColor: AppTheme.neutral800,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('New chat'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildChatsList(ChatProvider chatProvider, UserProvider userProvider) {
    if (userProvider.isPetOwner && !userProvider.hasClinicConnection) {
      return AppEmptyState(
        icon: Icons.medical_services_outlined,
        message:
            'Connect to a veterinary clinic to start conversations with your vet.',
        actionLabel: 'Learn More',
        onAction: () {},
      );
    }

    if (chatProvider.isLoading) {
      return Center(child: GFLoader(type: GFLoaderType.circle));
    }

    if (chatProvider.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        message: chatProvider.error!,
        actionLabel: 'Try Again',
        onAction: () => _refreshChats(chatProvider, userProvider),
      );
    }

    final chatRooms = chatProvider.chatRooms;

    if (chatRooms.isEmpty) {
      return AppEmptyState(
        icon: Icons.chat_bubble_outline,
        message: userProvider.isPetOwner
            ? 'No conversations yet. Create a chat request to talk with your clinic.'
            : 'No conversations yet.',
      );
    }

    // For vets/admins, also show pending requests
    final pendingRequests = userProvider.isVet || userProvider.isClinicAdmin
        ? chatProvider.pendingRequests
        : const <ChatRoom>[];

    return ListView(
      padding: EdgeInsets.all(AppTheme.spacing4),
      children: [
        if (pendingRequests.isNotEmpty &&
            (userProvider.isVet || userProvider.isClinicAdmin)) ...[
          Text(
            'Chat requests',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: AppTheme.spacing2),
          ...pendingRequests.map(
            (room) => Padding(
              padding: EdgeInsets.only(bottom: AppTheme.spacing2),
              child: _buildRequestCard(room, userProvider, chatProvider),
            ),
          ),
          SizedBox(height: AppTheme.spacing4),
        ],
        Text(
          'Conversations',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        SizedBox(height: AppTheme.spacing2),
        ...chatRooms.map(
          (chatRoom) => Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacing2),
            child: _buildChatCard(chatRoom, userProvider, chatProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildChatCard(
    ChatRoom chatRoom,
    UserProvider userProvider,
    ChatProvider chatProvider,
  ) {
    final displayName = _getDisplayName(chatRoom, userProvider);
    final lastMessage = chatRoom.lastMessage?.content ?? 'No messages yet';
    final currentUserId = userProvider.currentUser?.id ?? '';
    final hasUnread = (chatRoom.unreadCounts[currentUserId] ?? 0) > 0;
    final unreadCount = chatRoom.unreadCounts[currentUserId] ?? 0;

    // For pet owners, show a clear indicator when this is just a chat request
    String subtitle;
    if (userProvider.isPetOwner &&
        chatRoom.status == ChatRoomStatus.pending) {
      final clinicName = userProvider.connectedClinic?.name ?? 'clinic';
      subtitle = 'Chat request to $clinicName • Waiting for vet';
    } else {
      subtitle = lastMessage;
    }

    return GFCard(
      elevation: 0,
      color: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        side: BorderSide(color: context.border),
      ),
      content: GFListTile(
        avatar: GFAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          size: GFSize.LARGE,
          child: Text(
            displayName[0].toUpperCase(),
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 18.sp,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                  color: context.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasUnread)
              GFBadge(
                text: unreadCount.toString(),
                color: AppTheme.primary,
                size: GFSize.SMALL,
              ),
          ],
        ),
        subTitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13.sp, color: context.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider.value(
                value: chatProvider,
                child: ChatRoomPage(chatRoom: chatRoom),
              ),
            ),
          );
        },
        icon: userProvider.isPetOwner &&
                chatRoom.status == ChatRoomStatus.pending
            ? TextButton(
                onPressed: () =>
                    _confirmCancelRequest(chatRoom, chatProvider),
                child: const Text('Cancel'),
              )
            : null,
      ),
    );
  }

  Future<void> _confirmCancelRequest(
    ChatRoom chatRoom,
    ChatProvider chatProvider,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel chat request'),
          content: const Text(
            'Do you want to cancel this chat request? '
            'You can create a new one afterwards if needed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel request'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final success = await chatProvider.deleteChatRequest(chatRoom.id);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat request cancelled'),
          ),
        );
      } else if (chatProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.error!),
          ),
        );
      }
    }
  }

  String _getDisplayName(ChatRoom chatRoom, UserProvider userProvider) {
    if (userProvider.isPetOwner) {
      // For pending requests, there might not be a vet yet
      if (chatRoom.status == ChatRoomStatus.pending) {
        return userProvider.connectedClinic?.name ?? 'Clinic';
      }
      return chatRoom.vetName.isNotEmpty
          ? chatRoom.vetName
          : (userProvider.connectedClinic?.name ?? 'Clinic');
    } else {
      return chatRoom.petOwnerName;
    }
  }

  Future<void> _refreshChats(
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) async {
    if (userProvider.isPetOwner) {
      await chatProvider.initializeChatRooms(
        petOwnerId: userProvider.currentUser?.id,
      );
    } else if (userProvider.isVet || userProvider.isClinicAdmin) {
      if (userProvider.connectedClinic?.id != null) {
        await chatProvider.initializeChatRooms(
          clinicId: userProvider.connectedClinic?.id,
          vetId: userProvider.isVet ? userProvider.currentUser?.id : null,
          isAdmin: userProvider.isClinicAdmin,
        );
      }
    }
  }

  Future<void> _showNewChatRequestDialog(
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New chat request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Follow-up about Bella',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Describe the reason for this chat',
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  // simple validation
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final clinicId = userProvider.connectedClinic?.id;
      final petOwnerId = userProvider.currentUser?.id;
      final petOwnerName =
          userProvider.currentUser?.displayName ?? 'Pet Owner';

      if (clinicId == null || petOwnerId == null) return;

      final chatId = await chatProvider.createChatRequest(
        clinicId: clinicId,
        petOwnerId: petOwnerId,
        petOwnerName: petOwnerName,
        title: titleController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      );

      if (!mounted) return;

      if (chatId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat request sent to clinic'),
          ),
        );
      } else if (chatProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.error!),
          ),
        );
      }
    }
  }

  Widget _buildRequestCard(
    ChatRoom chatRoom,
    UserProvider userProvider,
    ChatProvider chatProvider,
  ) {
    final petOwnerName = chatRoom.petOwnerName;
    final title = chatRoom.topic ?? 'Chat request';
    final description = chatRoom.requestDescription ?? 'No description';

    return GFCard(
      elevation: 0,
      color: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        side: BorderSide(color: context.border),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'From: $petOwnerName',
            style: TextStyle(
              fontSize: 12.sp,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13.sp,
              color: context.textSecondary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  final vetId = userProvider.currentUser?.id;
                  final vetName =
                      userProvider.currentUser?.displayName ?? 'Vet';
                  if (vetId == null) return;

                  final success = await chatProvider.acceptChatRequest(
                    chatRoomId: chatRoom.id,
                    vetId: vetId,
                    vetName: vetName,
                  );

                  if (!mounted) return;

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chat request accepted'),
                      ),
                    );
                  } else if (chatProvider.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(chatProvider.error!),
                      ),
                    );
                  }
                },
                child: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
