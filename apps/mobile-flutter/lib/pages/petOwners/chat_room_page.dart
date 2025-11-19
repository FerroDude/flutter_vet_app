import 'dart:async';
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
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _initializeChatRoom();
    _setupTypingListener();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    context.read<ChatProvider>().leaveChatRoom();
    super.dispose();
  }

  void _setupTypingListener() {
    _messageController.addListener(() {
      final chatProvider = context.read<ChatProvider>();
      final text = _messageController.text;

      if (text.isNotEmpty) {
        // User is typing - set typing status to true
        chatProvider.setTypingStatus(true);

        // Reset the timer - will set typing to false after 3 seconds of no typing
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          chatProvider.setTypingStatus(false);
        });
      } else {
        // Text field is empty - stop typing status
        _typingTimer?.cancel();
        chatProvider.setTypingStatus(false);
      }
    });
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
              if (chatProvider.isOtherUserTyping && !isPendingAndPetOwner)
                _buildTypingIndicator(),
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
      reverse: true,
      padding: EdgeInsets.all(AppTheme.spacing4),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        // Since reverse: true, we need to reverse the index
        final reversedIndex = messages.length - 1 - index;
        final message = messages[reversedIndex];
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

  Widget _buildTypingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing4,
        vertical: AppTheme.spacing2,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacing3,
              vertical: AppTheme.spacing2,
            ),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius3),
              border: Border.all(color: context.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0),
                Gap(4.w),
                _TypingDot(delay: 200),
                Gap(4.w),
                _TypingDot(delay: 400),
              ],
            ),
          ),
        ],
      ),
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

    // With reverse: true, scroll to 0 to show the latest message (at bottom)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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

/// Animated typing dot widget
class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Delay the animation start
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 6.w,
        height: 6.w,
        decoration: BoxDecoration(
          color: context.textSecondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
