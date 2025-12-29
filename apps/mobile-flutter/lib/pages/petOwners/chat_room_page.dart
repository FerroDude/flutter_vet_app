import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
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
  ChatProvider? _chatProvider;

  // Track if user has scrolled up from the bottom
  bool _showScrollToBottom = false;
  // Track message IDs that are UNSEEN (arrived while scrolled up)
  final Set<String> _unseenMessageIds = {};
  // Track message count when user was last at bottom
  int _messageCountAtBottom = 0;
  // Track message count to detect new messages
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Setup scroll listener for pagination and scroll-to-bottom button
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store reference to ChatProvider for safe disposal
    if (_chatProvider == null) {
      _chatProvider = context.read<ChatProvider>();
      // Initialize chat room after we have the provider reference
      _initializeChatRoom();
      _setupTypingListener();
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();

    // Save scroll position before disposing
    if (_scrollController.hasClients && _chatProvider != null) {
      _chatProvider!.saveScrollPosition(
        widget.chatRoom.id,
        _scrollController.position.pixels,
      );
    }

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // Use stored reference to ensure leaveChatRoom is always called
    _chatProvider?.leaveChatRoom();
    super.dispose();
  }

  /// Handle scroll to load more messages when reaching the top
  /// and show/hide scroll-to-bottom button
  void _onScroll() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final maxScroll = position.maxScrollExtent;
      final currentScroll = position.pixels;

      // Since we use reverse: true, position 0 is the bottom (newest messages)
      // Show scroll-to-bottom button when user scrolls up more than 300 pixels
      final shouldShowButton = currentScroll > 300;
      if (shouldShowButton != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = shouldShowButton;
        });
      }

      // When user reaches bottom, clear unseen and update baseline count
      if (currentScroll < 100) {
        _unseenMessageIds.clear();
        _messageCountAtBottom = _chatProvider?.currentMessages.length ?? 0;
      }

      // Load more when user scrolls within 200 pixels of the top (older messages)
      if (maxScroll - currentScroll < 200) {
        _chatProvider?.loadMoreMessages();
      }
    }
  }

  /// Scroll to the bottom of the chat (newest messages)
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // With reverse: true, 0 is the bottom (newest messages)
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _setupTypingListener() {
    _messageController.addListener(() {
      final chatProvider = _chatProvider;
      if (chatProvider == null) return;

      final text = _messageController.text;

      if (text.isNotEmpty) {
        // User is typing - set typing status to true
        chatProvider.setTypingStatus(true);

        // Reset the timer - will set typing to false after 3 seconds of no typing
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (_chatProvider != null) {
            _chatProvider!.setTypingStatus(false);
          }
        });
      } else {
        // Text field is empty - stop typing status
        _typingTimer?.cancel();
        chatProvider.setTypingStatus(false);
      }
    });
  }

  void _initializeChatRoom() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _chatProvider?.selectChatRoom(widget.chatRoom.id);

      // Initialize message counts - this is our baseline
      final count = _chatProvider?.currentMessages.length ?? 0;
      _messageCountAtBottom = count;
      _previousMessageCount = count;

      // Restore scroll position after messages are loaded
      _restoreScrollPosition();
    });
  }

  /// Restore scroll position if user previously scrolled in this chat
  void _restoreScrollPosition() {
    if (_chatProvider == null) return;

    final savedPosition = _chatProvider!.getSavedScrollPosition(
      widget.chatRoom.id,
    );
    if (savedPosition > 0 && _scrollController.hasClients) {
      // Use a small delay to ensure the list is built
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(savedPosition);
          // Update the scroll-to-bottom button state
          setState(() {
            _showScrollToBottom = savedPosition > 300;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final currentChatRoom = chatProvider.currentChatRoom ?? widget.chatRoom;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final isPetOwner = currentUserId == currentChatRoom.petOwnerId;
        final isPendingAndPetOwner =
            isPetOwner && currentChatRoom.status == ChatRoomStatus.pending;
        final titleText = isPetOwner
            ? (currentChatRoom.vetName.isNotEmpty
                  ? currentChatRoom.vetName
                  : 'Clinic')
            : currentChatRoom.petOwnerName;

        // Simple unseen tracking:
        // - When scrolled up and new messages arrive, add to unseen
        // - When at bottom, clear unseen and update baseline

        final messages = chatProvider.currentMessages;
        final currentCount = messages.length;
        final isAtBottom =
            !_scrollController.hasClients ||
            (_scrollController.hasClients &&
                _scrollController.position.pixels < 100);

        // Detect new messages arriving while scrolled up
        final hasNewMessages = currentCount > _previousMessageCount;
        final wasScrolledUp = _showScrollToBottom;

        if (isAtBottom) {
          // At bottom: clear unseen and update baseline
          _unseenMessageIds.clear();
          _messageCountAtBottom = currentCount;
        } else if (currentCount > _messageCountAtBottom) {
          // Scrolled up and we have NEW messages - add new ones from other user to unseen
          final newMessageCount = currentCount - _messageCountAtBottom;
          for (int i = currentCount - newMessageCount; i < currentCount; i++) {
            final msg = messages[i];
            if (msg.senderId != currentUserId &&
                !_unseenMessageIds.contains(msg.id)) {
              _unseenMessageIds.add(msg.id);
            }
          }
          // Update baseline so we don't re-add these
          _messageCountAtBottom = currentCount;
        }

        // If new messages arrived while scrolled up, maintain scroll position
        // by jumping back after the frame is rendered
        if (hasNewMessages && wasScrolledUp && _scrollController.hasClients) {
          final savedPosition = _scrollController.position.pixels;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _scrollController.hasClients &&
                _showScrollToBottom) {
              _scrollController.jumpTo(savedPosition);
            }
          });
        }

        _previousMessageCount = currentCount;
        final unseenCount = _unseenMessageIds.length;

        return Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titleText,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (currentChatRoom.topic != null)
                    Text(
                      currentChatRoom.topic!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      _buildMessagesList(
                        chatProvider,
                        isPendingAndPetOwner: isPendingAndPetOwner,
                      ),
                      // Scroll to bottom floating button with unread count
                      if (_showScrollToBottom)
                        Positioned(
                          right: AppTheme.spacing4,
                          bottom: AppTheme.spacing4,
                          child: _buildScrollToBottomButton(unseenCount),
                        ),
                    ],
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
    final isLoadingMore = chatProvider.isLoadingMoreMessages;
    final hasMore = chatProvider.hasMoreMessages;

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64.sp,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            Gap(AppTheme.spacing2),
            Text(
              isPendingAndPetOwner
                  ? 'Waiting for a vet to open the chat'
                  : 'No messages yet',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    // Extra item for loading indicator at the top (shown when there are more messages)
    final itemCount = messages.length + (hasMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.all(AppTheme.spacing4),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Since reverse: true, index 0 is the newest message (bottom)
        // The "load more" indicator should be at the highest index (oldest, top)
        if (hasMore && index == itemCount - 1) {
          return _buildLoadMoreIndicator(isLoadingMore);
        }

        // Adjust index for the extra loading item
        final messageIndex = hasMore ? index : index;
        // Since reverse: true, we need to reverse the index
        final reversedIndex = messages.length - 1 - messageIndex;

        if (reversedIndex < 0 || reversedIndex >= messages.length) {
          return const SizedBox.shrink();
        }

        final message = messages[reversedIndex];
        final isMe = message.senderId == currentUserId;

        // Remove from unseen when rendered on screen
        if (_unseenMessageIds.contains(message.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _unseenMessageIds.contains(message.id)) {
              setState(() {
                _unseenMessageIds.remove(message.id);
              });
            }
          });
        }

        return Padding(
          key: ValueKey(message.id),
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
                  color: isMe ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radius3),
                  boxShadow: isMe ? null : AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isMe ? Colors.white : AppTheme.primary,
                      ),
                    ),
                    Gap(AppTheme.spacing1),
                    // Row with timestamp and status icon
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimestamp(message.timestamp),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppTheme.neutral700,
                          ),
                        ),
                        // Only show status icon for sender's own messages
                        if (isMe) ...[
                          Gap(4.w),
                          _buildStatusIcon(message.status, isMe),
                        ],
                      ],
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

  /// Build loading indicator shown when loading older messages
  Widget _buildLoadMoreIndicator(bool isLoading) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: Center(
        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  Gap(AppTheme.spacing2),
                  Text(
                    'Loading older messages...',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              )
            : TextButton(
                onPressed: () => _chatProvider?.loadMoreMessages(),
                child: Text(
                  'Load older messages',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
      ),
    );
  }

  /// Build the floating scroll-to-bottom button (WhatsApp style)
  Widget _buildScrollToBottomButton(int unseenCount) {
    return GestureDetector(
      onTap: _scrollToBottom,
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacing3),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.keyboard_arrow_down,
              color: AppTheme.primary,
              size: 24.sp,
            ),
            // Show badge with unread message count if any
            if (unseenCount > 0)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  constraints: BoxConstraints(minWidth: 18.w, minHeight: 18.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      unseenCount > 99 ? '99+' : unseenCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the message status icon (sent/delivered/read)
  Widget _buildStatusIcon(MessageStatus status, bool isMe) {
    final Color iconColor = isMe
        ? Colors.white.withValues(alpha: 0.7)
        : AppTheme.neutral700;

    switch (status) {
      case MessageStatus.sent:
        // Single checkmark for sent
        return Icon(Icons.check, size: 14.sp, color: iconColor);
      case MessageStatus.delivered:
        // Double checkmark (gray) for delivered
        return Icon(Icons.done_all, size: 14.sp, color: iconColor);
      case MessageStatus.read:
        // Double checkmark (blue) for read
        return Icon(Icons.done_all, size: 14.sp, color: Colors.lightBlueAccent);
    }
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius3),
              boxShadow: AppTheme.cardShadow,
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
      margin: EdgeInsets.all(AppTheme.spacing3),
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20.sp,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          Gap(AppTheme.spacing2),
          Expanded(
            child: Text(
              'Waiting for a vet to open the chat. You can start messaging once your request is accepted.',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ChatProvider chatProvider) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius3),
                boxShadow: AppTheme.cardShadow,
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: AppTheme.primary, fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: AppTheme.neutral700.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing3,
                    vertical: AppTheme.spacing3,
                  ),
                ),
                maxLines: null,
              ),
            ),
          ),
          Gap(AppTheme.spacing2),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppTheme.cardShadow,
            ),
            child: IconButton(
              icon: Icon(Icons.send, color: AppTheme.primary),
              onPressed: () => _sendMessage(chatProvider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(ChatProvider chatProvider) async {
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

    // Scroll to bottom - messages will be marked as seen when rendered
    setState(() {
      _showScrollToBottom = false;
    });
    _scrollToBottom();
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

    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

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
          color: AppTheme.neutral700,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
