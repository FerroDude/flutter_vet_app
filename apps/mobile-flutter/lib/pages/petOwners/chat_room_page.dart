import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:getwidget/getwidget.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';

class ChatRoomPage extends StatefulWidget {
  final ChatRoom chatRoom;

  const ChatRoomPage({super.key, required this.chatRoom});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeChatRoom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    context.read<ChatProvider>().leaveChatRoom();
    super.dispose();
  }

  void _initializeChatRoom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().selectChatRoom(widget.chatRoom.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final currentChatRoom =
            chatProvider.currentChatRoom ?? widget.chatRoom;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final isPetOwner = currentUserId == currentChatRoom.petOwnerId;
        final isPendingAndPetOwner =
            isPetOwner && currentChatRoom.status == ChatRoomStatus.pending;
        final titleText = isPetOwner
            ? (currentChatRoom.vetName.isNotEmpty
                ? currentChatRoom.vetName
                : 'Clinic')
            : currentChatRoom.petOwnerName;

        return Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (currentChatRoom.topic != null)
                  Text(
                    currentChatRoom.topic!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: _buildMessagesList(
                  chatProvider,
                  isPendingAndPetOwner: isPendingAndPetOwner,
                ),
              ),
              if (isPendingAndPetOwner)
                _buildPendingNotice()
              else
                _buildMessageInput(chatProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessagesList(
    ChatProvider chatProvider, {
    required bool isPendingAndPetOwner,
  }) {
    final messages = chatProvider.currentMessages;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64.sp,
              color: context.textSecondary,
            ),
            Gap(AppTheme.spacing2),
            Text(
              isPendingAndPetOwner
                  ? 'Waiting for a vet to open the chat'
                  : 'No messages yet',
              style: TextStyle(fontSize: 14.sp, color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(AppTheme.spacing4),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.senderId == currentUserId;

        return Padding(
          padding: EdgeInsets.only(bottom: AppTheme.spacing2),
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: 250.w),
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing3,
                  vertical: AppTheme.spacing2,
                ),
                decoration: BoxDecoration(
                  color: isMe ? AppTheme.primary : context.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius3),
                  border: isMe ? null : Border.all(color: context.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isMe ? Colors.white : context.textPrimary,
                      ),
                    ),
                    Gap(AppTheme.spacing1),
                    Text(
                      _formatTimestamp(message.timestamp),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingNotice() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20.sp,
            color: context.textSecondary,
          ),
          Gap(AppTheme.spacing2),
          Expanded(
            child: Text(
              'Waiting for a vet to open the chat. You can start messaging once your request is accepted.',
              style: TextStyle(
                fontSize: 13.sp,
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(
    ChatProvider chatProvider,
  ) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GFTextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius3),
                  borderSide: BorderSide(color: context.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius3),
                  borderSide: BorderSide(color: context.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius3),
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing3,
                  vertical: AppTheme.spacing2,
                ),
              ),
              maxLines: null,
            ),
          ),
          Gap(AppTheme.spacing2),
          GFIconButton(
            icon: Icon(Icons.send, color: Colors.white),
            color: AppTheme.primary,
            type: GFButtonType.solid,
            shape: GFIconButtonShape.circle,
            onPressed: () => _sendMessage(chatProvider),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(
    ChatProvider chatProvider,
  ) async {
    final chatRoom = chatProvider.currentChatRoom ?? widget.chatRoom;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isPetOwner = currentUserId == chatRoom.petOwnerId;

    // Extra safety: prevent sending messages while the request is still pending
    if (isPetOwner && chatRoom.status == ChatRoomStatus.pending) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Waiting for a vet to open the chat. You can start messaging once your request is accepted.',
            ),
          ),
        );
      }
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    await chatProvider.sendTextMessage(text);

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (diff.inDays < 7) {
      return DateFormat('E h:mm a').format(timestamp);
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }
}
