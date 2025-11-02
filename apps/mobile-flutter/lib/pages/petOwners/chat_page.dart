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
          backgroundColor: context.background,
          appBar: AppBar(
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
        message: 'No conversations yet. Start chatting with your vet!',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppTheme.spacing4),
      itemCount: chatRooms.length,
      itemBuilder: (context, index) {
        final chatRoom = chatRooms[index];
        return Padding(
          padding: EdgeInsets.only(bottom: AppTheme.spacing2),
          child: _buildChatCard(chatRoom, userProvider),
        );
      },
    );
  }

  Widget _buildChatCard(ChatRoom chatRoom, UserProvider userProvider) {
    final displayName = _getDisplayName(chatRoom, userProvider);
    final lastMessage = chatRoom.lastMessage?.content ?? 'No messages yet';
    final currentUserId = userProvider.currentUser?.id ?? '';
    final hasUnread = (chatRoom.unreadCounts[currentUserId] ?? 0) > 0;
    final unreadCount = chatRoom.unreadCounts[currentUserId] ?? 0;

    return GFCard(
      elevation: 0,
      color: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        side: BorderSide(color: context.border),
      ),
      content: GFListTile(
        avatar: GFAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.1),
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
          lastMessage,
          style: TextStyle(fontSize: 13.sp, color: context.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoomPage(chatRoom: chatRoom),
            ),
          );
        },
      ),
    );
  }

  String _getDisplayName(ChatRoom chatRoom, UserProvider userProvider) {
    if (userProvider.isPetOwner) {
      return chatRoom.vetName;
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
        );
      }
    }
  }
}
