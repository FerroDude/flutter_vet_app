import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import '../../services/media_service.dart';
import '../../services/media_cache_service.dart';
import '../../theme/app_theme.dart';
import '../../shared/widgets/chat_widgets.dart';

class ChatRoomPage extends StatefulWidget {
  final ChatRoom chatRoom;

  const ChatRoomPage({super.key, required this.chatRoom});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _typingTimer;
  ChatProvider? _chatProvider;

  // Track if user has scrolled up from the bottom (for showing scroll button)
  bool _showScrollToBottom = false;

  // Reply state
  ReplyData? _replyingTo;

  // Search state
  bool _isSearching = false;
  String _searchQuery = '';
  List<String> _searchMatchIds = [];
  int _currentSearchIndex = 0;

  // Highlight state (for scrolling to replied message)
  String? _highlightedMessageId;

  // Message keys for precise scrolling
  final Map<String, GlobalKey> _messageKeys = {};

  // Reaction picker state
  OverlayEntry? _reactionOverlay;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Listen to text changes to switch between mic and send button
    _messageController.addListener(() {
      setState(() {}); // Rebuild to show correct button
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chatProvider == null) {
      _chatProvider = context.read<ChatProvider>();
      _initializeChatRoom();
      _setupTypingListener();
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _searchController.dispose();
    _reactionOverlay?.remove();

    // Save scroll position before disposing
    if (_scrollController.hasClients && _chatProvider != null) {
      _chatProvider!.saveScrollPosition(
        widget.chatRoom.id,
        _scrollController.position.pixels,
      );
    }

    // Unfreeze UI when leaving chat
    _chatProvider?.unfreezeUI();

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _chatProvider?.leaveChatRoom();
    super.dispose();
  }

  /// Handle scroll events for pagination and scroll-to-bottom button
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final currentScroll = position.pixels;
    final maxScroll = position.maxScrollExtent;

    // With reverse: true, position 0 is bottom (newest), maxScroll is top (oldest)
    // Show button when user scrolls up more than 300 pixels from bottom
    final shouldShowButton = currentScroll > 300;

    if (shouldShowButton && !_showScrollToBottom) {
      // User scrolled up - freeze UI to prevent message bumping
      _chatProvider?.freezeUI();
      setState(() => _showScrollToBottom = true);
    } else if (!shouldShowButton && _showScrollToBottom) {
      // User scrolled back to bottom - unfreeze to show new messages
      _chatProvider?.unfreezeUI();
      setState(() => _showScrollToBottom = false);
    }

    // Load more when near the top (high scroll offset with reverse: true)
    if (maxScroll - currentScroll < 200) {
      _chatProvider?.loadMoreMessages();
    }
  }

  /// Scroll to the bottom of the chat (newest messages)
  void _scrollToBottom() {
    // Unfreeze to show any pending messages
    _chatProvider?.unfreezeUI();
    setState(() => _showScrollToBottom = false);

    // With reverse: true, position 0 is the bottom (newest messages)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0, // With reverse: true, 0 is the bottom
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

    // Use a small delay to ensure the list is built
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;

      if (savedPosition > 0) {
        // Restore saved position
        _scrollController.jumpTo(savedPosition);
        // With reverse: true, higher scroll offset means scrolled up (away from newest)
        final isScrolledUp = savedPosition > 300;
        if (isScrolledUp) {
          _chatProvider?.freezeUI();
        }
        setState(() => _showScrollToBottom = isScrolledUp);
      }
      // With reverse: true, position 0 is already at bottom (newest), no need to scroll
    });
  }

  // ==================== REPLY METHODS ====================

  void _startReply(ChatMessage message) {
    HapticFeedback.lightImpact();
    setState(() {
      _replyingTo = ReplyData.fromMessage(message);
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  // ==================== SEARCH METHODS ====================

  void _toggleSearch(List<ChatMessage> messages) {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _closeSearch();
      }
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchMatchIds = [];
      _currentSearchIndex = 0;
      _searchController.clear();
      _highlightedMessageId = null;
    });
  }

  void _performSearch(String query, List<ChatMessage> messages) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _searchMatchIds = [];
        _currentSearchIndex = 0;
        return;
      }

      _searchMatchIds = messages
          .where((m) => m.content.toLowerCase().contains(_searchQuery))
          .map((m) => m.id)
          .toList();
      _currentSearchIndex = _searchMatchIds.isNotEmpty ? 0 : 0;

      if (_searchMatchIds.isNotEmpty) {
        _scrollToMessage(_searchMatchIds[_currentSearchIndex], messages);
      }
    });
  }

  void _navigateSearch(int direction, List<ChatMessage> messages) {
    if (_searchMatchIds.isEmpty) return;

    setState(() {
      _currentSearchIndex =
          (_currentSearchIndex + direction) % _searchMatchIds.length;
      if (_currentSearchIndex < 0) {
        _currentSearchIndex = _searchMatchIds.length - 1;
      }
      _scrollToMessage(_searchMatchIds[_currentSearchIndex], messages);
    });
  }

  void _scrollToMessage(String messageId, List<ChatMessage> messages) {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    // Get the GlobalKey for this message
    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      // Use ensureVisible for precise scrolling
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.3, // Position message 30% from top of viewport
      );
    } else {
      // Fallback: estimate scroll position if key not available
      final reversedIndex = messages.length - 1 - index;
      final estimatedOffset = reversedIndex * 100.0;
      _scrollController.animateTo(
        estimatedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Highlight the message briefly
    setState(() {
      _highlightedMessageId = messageId;
    });

    // Clear highlight after animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  // ==================== REACTION METHODS ====================

  void _showReactionPicker(
    BuildContext context,
    ChatMessage message,
    Offset position,
  ) {
    _reactionOverlay?.remove();
    HapticFeedback.mediumImpact();

    _reactionOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx - 100,
        top: position.dy - 60,
        child: Material(
          color: Colors.transparent,
          child: EmojiReactionPicker(
            onEmojiSelected: (emoji) {
              _addReaction(message.id, emoji);
              _reactionOverlay?.remove();
              _reactionOverlay = null;
            },
            onClose: () {
              _reactionOverlay?.remove();
              _reactionOverlay = null;
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_reactionOverlay!);

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _reactionOverlay?.remove();
      _reactionOverlay = null;
    });
  }

  void _addReaction(String messageId, String emoji) {
    _chatProvider?.toggleReaction(messageId, emoji);
  }

  // ==================== REPLY SCROLL ====================

  void _scrollToRepliedMessage(String messageId, List<ChatMessage> messages) {
    _scrollToMessage(messageId, messages);
  }

  // ==================== HELPER METHODS ====================

  /// Extract reactions from message metadata
  List<ReactionData> _getReactions(ChatMessage message) {
    final metadata = message.metadata;
    if (metadata == null) return [];

    final reactions = metadata['reactions'] as List<dynamic>?;
    if (reactions == null) return [];

    return reactions
        .map((r) => ReactionData.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Check if message has a reply
  ReplyData? _getReplyData(ChatMessage message) {
    final metadata = message.metadata;
    if (metadata == null) return null;
    if (metadata['replyToId'] == null) return null;

    return ReplyData.fromJson(metadata);
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

        // Get messages from provider (provider handles freezing internally)
        final messages = chatProvider.currentMessages;

        // Count of pending messages (arrived while UI was frozen)
        final pendingCount = chatProvider.pendingMessageCount;

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
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _toggleSearch(messages),
                  tooltip: 'Search messages',
                ),
              ],
            ),
            body: Column(
              children: [
                // Search bar
                if (_isSearching)
                  ChatSearchBar(
                    controller: _searchController,
                    onClose: _closeSearch,
                    onChanged: (query) => _performSearch(query, messages),
                    matchCount: _searchMatchIds.length,
                    currentMatch: _searchMatchIds.isEmpty
                        ? 0
                        : _currentSearchIndex + 1,
                    onPrevious: () => _navigateSearch(-1, messages),
                    onNext: () => _navigateSearch(1, messages),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      _buildMessagesList(
                        chatProvider,
                        isPendingAndPetOwner: isPendingAndPetOwner,
                        messages: messages,
                      ),
                      // Scroll to bottom floating button with pending message count
                      if (_showScrollToBottom)
                        Positioned(
                          right: AppTheme.spacing4,
                          bottom: AppTheme.spacing4,
                          child: _buildScrollToBottomButton(pendingCount),
                        ),
                    ],
                  ),
                ),
                if (chatProvider.isOtherUserTyping && !isPendingAndPetOwner)
                  _buildTypingIndicator(),
                // Reply preview
                if (_replyingTo != null && !isPendingAndPetOwner)
                  ReplyPreview(
                    replyData: _replyingTo!,
                    onCancel: _cancelReply,
                    isMe: true,
                  ),
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
    required List<ChatMessage> messages,
  }) {
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

    // With reverse: true, index 0 is newest (bottom), highest index is oldest (top)
    // Add 1 for loading indicator at the top (highest index) if there are more
    final itemCount = messages.length + (hasMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Newest at bottom, oldest at top - standard chat pattern
      padding: EdgeInsets.all(AppTheme.spacing4),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Loading indicator at the highest index (top of reversed list)
        if (hasMore && index == itemCount - 1) {
          return _buildLoadMoreIndicator(isLoadingMore);
        }

        // With reverse: true, we need to reverse the message index
        // index 0 = newest message (bottom) = messages[length-1]
        // index n = older message = messages[length-1-n]
        final messageIndex = messages.length - 1 - index;

        if (messageIndex < 0 || messageIndex >= messages.length) {
          return const SizedBox.shrink();
        }

        final message = messages[messageIndex];
        final isMe = message.senderId == currentUserId;

        // Determine if this is the first message in a sequence from this sender
        // (i.e., the previous message was from a different user or this is the first message)
        final isFirstInSequence =
            messageIndex == 0 ||
            messages[messageIndex - 1].senderId != message.senderId;

        // Get reply and reactions data
        final replyData = _getReplyData(message);
        final reactions = _getReactions(message);
        final shouldHighlight = _highlightedMessageId == message.id;

        // Create/get GlobalKey for this message (for precise scrolling)
        _messageKeys.putIfAbsent(message.id, () => GlobalKey());

        return Container(
          key: _messageKeys[message.id],
          child: MessageHighlight(
            shouldHighlight: shouldHighlight,
            child: SwipeableMessage(
              isMe: isMe,
              onSwipeReply: () => _startReply(message),
              child: GestureDetector(
                // Only allow reactions on OTHER people's messages, not your own
                onLongPressStart: isMe
                    ? null
                    : (details) {
                        _showReactionPicker(
                          context,
                          message,
                          details.globalPosition,
                        );
                      },
                onDoubleTap: isMe
                    ? null
                    : () {
                        // Quick react with ❤️
                        _addReaction(message.id, '❤️');
                      },
                child: Padding(
                  padding: EdgeInsets.only(
                    // Less space between same-person messages, more between different users
                    bottom: isFirstInSequence ? 2.w : 4.w,
                    top: isFirstInSequence && messageIndex > 0 ? 12.w : 0,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      // Add bottom padding when reactions exist to make room
                      bottom: reactions.isNotEmpty ? 14.h : 0,
                    ),
                    child: Row(
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment:
                          CrossAxisAlignment.start, // Align to top
                      children: [
                        // Bubble tail for received messages (left side, top)
                        // Always reserve space for alignment consistency
                        if (!isMe)
                          isFirstInSequence
                              ? CustomPaint(
                                  painter: _BubbleTailPainter(
                                    color: Colors.white,
                                    isMe: false,
                                  ),
                                  size: Size(12.w, 16.w),
                                )
                              : SizedBox(width: 12.w),
                        // Stack wraps just the bubble so reactions position correctly
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: 250.w,
                                minWidth: 140.w,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing3,
                                vertical: AppTheme.spacing2,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? AppTheme.primary : Colors.white,
                                borderRadius: BorderRadius.only(
                                  // Hide top corner where tail attaches (radius 0)
                                  topLeft: Radius.circular(
                                    !isMe && isFirstInSequence
                                        ? 0
                                        : AppTheme.radius3,
                                  ),
                                  topRight: Radius.circular(
                                    isMe && isFirstInSequence
                                        ? 0
                                        : AppTheme.radius3,
                                  ),
                                  bottomLeft: Radius.circular(AppTheme.radius3),
                                  bottomRight: Radius.circular(
                                    AppTheme.radius3,
                                  ),
                                ),
                                boxShadow: isMe ? null : AppTheme.cardShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Reply bubble if this is a reply
                                  if (replyData != null)
                                    ReplyBubble(
                                      replyData: replyData,
                                      isMe: isMe,
                                      onTap: () => _scrollToRepliedMessage(
                                        replyData.messageId,
                                        messages,
                                      ),
                                    ),
                                  // Build content based on message type
                                  _buildMessageContent(message, isMe),
                                  // Link preview for text messages with URLs
                                  if (message.type == MessageType.text &&
                                      UrlUtils.hasUrl(message.content))
                                    LinkPreviewWidget(
                                      url: UrlUtils.extractUrls(
                                        message.content,
                                      ).first,
                                      isMe: isMe,
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
                                              ? Colors.white.withValues(
                                                  alpha: 0.7,
                                                )
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
                            // Reactions positioned at bottom-right corner of bubble
                            if (reactions.isNotEmpty)
                              Positioned(
                                bottom: -12.h,
                                right: 4.w,
                                child: ReactionsDisplay(
                                  reactions: reactions,
                                  currentUserId: currentUserId ?? '',
                                  onReactionTap: (emoji) =>
                                      _addReaction(message.id, emoji),
                                  isMe: isMe,
                                ),
                              ),
                          ],
                        ),
                        // Bubble tail for sent messages (right side, top)
                        // Always reserve space for alignment consistency
                        if (isMe)
                          isFirstInSequence
                              ? CustomPaint(
                                  painter: _BubbleTailPainter(
                                    color: AppTheme.primary,
                                    isMe: true,
                                  ),
                                  size: Size(12.w, 16.w),
                                )
                              : SizedBox(width: 12.w),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build message content based on type
  Widget _buildMessageContent(ChatMessage message, bool isMe) {
    switch (message.type) {
      case MessageType.image:
        return _buildImageMessage(message, isMe);
      case MessageType.video:
        return _buildVideoMessage(message, isMe);
      case MessageType.file:
        return _buildFileMessage(message, isMe);
      case MessageType.voice:
        return _VoiceMessagePlayer(message: message, isMe: isMe);
      default:
        // Text message
        return Text(
          message.content,
          style: TextStyle(
            fontSize: 14.sp,
            color: isMe ? Colors.white : AppTheme.primary,
          ),
        );
    }
  }

  /// Build image message bubble
  Widget _buildImageMessage(ChatMessage message, bool isMe) {
    final imageUrl = message.mediaUrl ?? message.thumbnailUrl;
    if (imageUrl == null) {
      return Text(
        message.content,
        style: TextStyle(
          fontSize: 14.sp,
          color: isMe ? Colors.white : AppTheme.primary,
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showFullScreenImage(imageUrl, message.fileName),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius2),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 200.w, maxHeight: 250.w),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 150.w,
              height: 150.w,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.neutral700.withValues(alpha: 0.1),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isMe ? Colors.white : AppTheme.primary,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 150.w,
              height: 100.w,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.neutral700.withValues(alpha: 0.1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    color: isMe ? Colors.white : AppTheme.neutral700,
                    size: 32.sp,
                  ),
                  Gap(AppTheme.spacing1),
                  Text(
                    'Failed to load',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppTheme.neutral700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build video message bubble
  Widget _buildVideoMessage(ChatMessage message, bool isMe) {
    return _VideoMessageBubble(
      message: message,
      isMe: isMe,
      onTap: () {
        if (message.mediaUrl != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _FullScreenVideoPlayer(
                videoUrl: message.mediaUrl!,
                fileName: message.fileName,
              ),
            ),
          );
        }
      },
    );
  }

  /// Build file message bubble
  Widget _buildFileMessage(ChatMessage message, bool isMe) {
    return GestureDetector(
      onTap: () => _openMediaFile(message),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacing2),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.15)
              : AppTheme.neutral700.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radius2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacing2),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
              child: Text(
                MediaService.getFileIcon(message.mimeType),
                style: TextStyle(fontSize: 24.sp),
              ),
            ),
            Gap(AppTheme.spacing2),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.fileName ?? 'File',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: isMe ? Colors.white : AppTheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (message.fileSize != null)
                    Text(
                      MediaService.formatFileSize(message.fileSize!),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppTheme.neutral700,
                      ),
                    ),
                ],
              ),
            ),
            Gap(AppTheme.spacing2),
            Icon(
              Icons.download,
              color: isMe ? Colors.white : AppTheme.primary,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  /// Show full screen image viewer
  void _showFullScreenImage(String imageUrl, String? fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _FullScreenImageViewer(imageUrl: imageUrl, fileName: fileName),
      ),
    );
  }

  /// Open media file (video or document)
  Future<void> _openMediaFile(ChatMessage message) async {
    if (message.mediaUrl == null) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16.w,
                height: 16.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              Gap(AppTheme.spacing2),
              const Text('Opening file...'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Download file to temp directory
      final tempDir = await getTemporaryDirectory();
      final fileName = message.fileName ?? 'file_${message.id}';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      // Check if file already exists
      if (!await file.exists()) {
        // Download the file
        final response = await http.get(Uri.parse(message.mediaUrl!));
        await file.writeAsBytes(response.bodyBytes);
      }

      // Open the file
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open file: $e')));
      }
    }
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
            // Show badge only when there are new unread messages
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
    final isRecording = chatProvider.isRecording;
    final isBusy = chatProvider.isUploadingMedia || isRecording;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upload progress indicator
        if (chatProvider.isUploadingMedia)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacing4,
              vertical: AppTheme.spacing2,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: chatProvider.uploadProgress,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Gap(AppTheme.spacing2),
                Text(
                  'Uploading... ${(chatProvider.uploadProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        // Voice recording UI
        if (isRecording)
          _buildVoiceRecordingUI(chatProvider)
        else
          Container(
            padding: EdgeInsets.all(AppTheme.spacing3),
            child: Row(
              children: [
                // Attachment button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.attach_file, color: AppTheme.primary),
                    onPressed: isBusy
                        ? null
                        : () => _showAttachmentOptions(chatProvider),
                  ),
                ),
                Gap(AppTheme.spacing2),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radius3),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 14.sp,
                      ),
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
                // Send or Mic button (show mic when text is empty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: _messageController.text.trim().isEmpty
                      ? GestureDetector(
                          onLongPressStart: (_) =>
                              _startVoiceRecording(chatProvider),
                          child: IconButton(
                            icon: Icon(Icons.mic, color: AppTheme.primary),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Hold to record a voice message',
                                  ),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.send, color: AppTheme.primary),
                          onPressed: isBusy
                              ? null
                              : () => _sendMessage(chatProvider),
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Build voice recording UI
  Widget _buildVoiceRecordingUI(ChatProvider chatProvider) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      child: Row(
        children: [
          // Cancel button
          GestureDetector(
            onTap: () => chatProvider.cancelVoiceRecording(),
            child: Container(
              padding: EdgeInsets.all(AppTheme.spacing3),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, color: Colors.red, size: 24.sp),
            ),
          ),
          Gap(AppTheme.spacing3),
          // Recording indicator and duration
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacing4,
                vertical: AppTheme.spacing3,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius3),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  // Pulsing red dot
                  _PulsingDot(),
                  Gap(AppTheme.spacing2),
                  Text(
                    'Recording',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    MediaService.formatDuration(chatProvider.recordingDuration),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.neutral700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Gap(AppTheme.spacing3),
          // Send button
          GestureDetector(
            onTap: () => chatProvider.stopAndSendVoiceRecording(),
            child: Container(
              padding: EdgeInsets.all(AppTheme.spacing3),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Icon(Icons.send, color: Colors.white, size: 24.sp),
            ),
          ),
        ],
      ),
    );
  }

  /// Start voice recording with permission handling
  Future<void> _startVoiceRecording(ChatProvider chatProvider) async {
    // First check microphone permission status
    final status = await Permission.microphone.status;

    if (status.isPermanentlyDenied) {
      // Show dialog to guide user to settings
      if (mounted) {
        _showPermissionDeniedDialog(
          title: 'Microphone Access Required',
          message:
              'Voice messages require microphone access. Please enable it in your device settings.',
        );
      }
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final success = await chatProvider.startVoiceRecording();
    if (!success && mounted) {
      // Check if it was a permission issue
      final newStatus = await Permission.microphone.status;
      if (newStatus.isDenied || newStatus.isPermanentlyDenied) {
        _showPermissionDeniedDialog(
          title: 'Microphone Access Required',
          message:
              'Voice messages require microphone access. Please allow microphone access to record voice messages.',
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Could not start recording. Please try again.'),
          ),
        );
      }
    }
  }

  /// Show permission denied dialog with option to open settings
  void _showPermissionDeniedDialog({
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Show attachment options bottom sheet
  void _showAttachmentOptions(ChatProvider chatProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radius4),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40.w,
                  height: 4.w,
                  decoration: BoxDecoration(
                    color: AppTheme.neutral700.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                ),
                Gap(AppTheme.spacing4),
                Text(
                  'Share Media',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
                Gap(AppTheme.spacing4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      color: Colors.purple,
                      onTap: () async {
                        Navigator.pop(context);
                        await chatProvider.pickAndSendImageFromGallery();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.camera_alt,
                      label: 'Photo',
                      color: Colors.blue,
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        // Check camera permission
                        final cameraStatus = await Permission.camera.status;
                        if (cameraStatus.isPermanentlyDenied) {
                          navigator.pop();
                          if (mounted) {
                            _showPermissionDeniedDialog(
                              title: 'Camera Access Required',
                              message:
                                  'Taking photos requires camera access. Please enable it in your device settings.',
                            );
                          }
                          return;
                        }
                        navigator.pop();
                        await chatProvider.pickAndSendImageFromCamera();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.videocam,
                      label: 'Video',
                      color: Colors.red,
                      onTap: () async {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        final success = await chatProvider
                            .pickAndSendVideoFromGallery();
                        if (!success && chatProvider.error != null && mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(chatProvider.error!),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.fiber_manual_record,
                      label: 'Record',
                      color: Colors.redAccent,
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        // Check camera and microphone permissions for video recording
                        final cameraStatus = await Permission.camera.status;
                        final micStatus = await Permission.microphone.status;

                        if (cameraStatus.isPermanentlyDenied ||
                            micStatus.isPermanentlyDenied) {
                          navigator.pop();
                          if (mounted) {
                            _showPermissionDeniedDialog(
                              title: 'Camera & Microphone Required',
                              message:
                                  'Recording videos requires camera and microphone access. Please enable them in your device settings.',
                            );
                          }
                          return;
                        }

                        navigator.pop();
                        final success = await chatProvider
                            .pickAndSendVideoFromCamera();
                        if (!success && chatProvider.error != null && mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(chatProvider.error!),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                Gap(AppTheme.spacing3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.insert_drive_file,
                      label: 'File',
                      color: Colors.orange,
                      onTap: () async {
                        Navigator.pop(context);
                        await chatProvider.pickAndSendFiles();
                      },
                    ),
                    // Spacers to maintain alignment
                    SizedBox(width: 60.w),
                    SizedBox(width: 60.w),
                    SizedBox(width: 60.w),
                  ],
                ),
                Gap(AppTheme.spacing4),
                // File size limits info
                Container(
                  padding: EdgeInsets.all(AppTheme.spacing3),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral700.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16.sp,
                        color: AppTheme.neutral700.withValues(alpha: 0.7),
                      ),
                      Gap(AppTheme.spacing2),
                      Expanded(
                        child: Text(
                          'Max sizes: Images 5MB, Videos 25MB (15s max), Files 10MB',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.neutral700.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spacing3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28.sp),
          ),
          Gap(AppTheme.spacing2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.neutral700,
              fontWeight: FontWeight.w500,
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

    // Prepare reply metadata if replying
    Map<String, dynamic>? metadata;
    if (_replyingTo != null) {
      metadata = _replyingTo!.toJson();
    }

    _messageController.clear();
    _cancelReply(); // Clear reply state

    await chatProvider.sendTextMessage(text, metadata: metadata);

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

/// Custom painter for chat bubble tail/pointer at top corner
class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool isMe;

  _BubbleTailPainter({required this.color, required this.isMe});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    if (isMe) {
      // Tail pointing right at top (for sent messages)
      // Starts at the top-left of the tail area, curves up and right
      path.moveTo(0, 0); // Top-left corner (connects to bubble)
      path.lineTo(0, size.height); // Go down along the bubble edge
      path.quadraticBezierTo(
        0,
        size.height * 0.3,
        size.width,
        0,
      ); // Curve up to the point
      path.close();
    } else {
      // Tail pointing left at top (for received messages)
      // Starts at the top-right of the tail area, curves up and left
      path.moveTo(size.width, 0); // Top-right corner (connects to bubble)
      path.lineTo(size.width, size.height); // Go down along the bubble edge
      path.quadraticBezierTo(
        size.width,
        size.height * 0.3,
        0,
        0,
      ); // Curve up to the point
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isMe != isMe;
  }
}

/// Full screen image viewer
class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? fileName;

  const _FullScreenImageViewer({required this.imageUrl, this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(fileName ?? 'Photo', style: TextStyle(fontSize: 16.sp)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.white54, size: 64.sp),
                Gap(AppTheme.spacing2),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing red dot for recording indicator
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
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
        width: 12.w,
        height: 12.w,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Voice message player widget
class _VoiceMessagePlayer extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const _VoiceMessagePlayer({required this.message, required this.isMe});

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  PlayerController? _playerController;
  bool _isPlaying = false;
  int _durationSeconds = 0;
  int _positionSeconds = 0;
  bool _isLoading = false;
  bool _isPrepared = false;

  @override
  void initState() {
    super.initState();
    // Set initial duration from message metadata
    if (widget.message.audioDuration != null) {
      _durationSeconds = widget.message.audioDuration!;
    }
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  Future<void> _preparePlayer() async {
    if (_isPrepared || widget.message.mediaUrl == null) return;

    try {
      setState(() => _isLoading = true);

      _playerController = PlayerController();

      // Use centralized cache service
      final cacheService = MediaCacheService.instance;
      try {
        cacheService.basePath;
      } catch (_) {
        await cacheService.init();
      }

      final filePath = cacheService.getVoiceCachePath(widget.message.id);
      final file = File(filePath);

      // Download if not cached
      if (!await file.exists()) {
        final response = await http.get(Uri.parse(widget.message.mediaUrl!));
        await cacheService.cacheVoice(widget.message.id, response.bodyBytes);
      }

      await _playerController!.preparePlayer(
        path: filePath,
        shouldExtractWaveform: false,
      );

      _playerController!.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
            if (state == PlayerState.stopped) {
              _positionSeconds = 0;
            }
          });
        }
      });

      _playerController!.onCurrentDurationChanged.listen((duration) {
        if (mounted) {
          setState(() => _positionSeconds = (duration / 1000).round());
        }
      });

      final maxDuration = _playerController!.maxDuration;
      if (maxDuration > 0) {
        _durationSeconds = (maxDuration / 1000).round();
      }

      _isPrepared = true;
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load audio: $e')));
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (widget.message.mediaUrl == null) return;

    try {
      if (!_isPrepared) {
        await _preparePlayer();
        if (!_isPrepared) return;
      }

      if (_isPlaying) {
        await _playerController?.pausePlayer();
      } else {
        await _playerController?.startPlayer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to play audio: $e')));
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _durationSeconds > 0
        ? _positionSeconds / _durationSeconds
        : 0.0;

    return SizedBox(
      width: 180.w,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _isLoading ? null : _togglePlayPause,
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isMe ? Colors.white : AppTheme.primary,
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: widget.isMe ? Colors.white : AppTheme.primary,
                      size: 20.sp,
                    ),
            ),
          ),
          Gap(AppTheme.spacing2),
          // Progress bar and duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.w),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: widget.isMe
                        ? Colors.white.withValues(alpha: 0.3)
                        : AppTheme.neutral700.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isMe ? Colors.white : AppTheme.primary,
                    ),
                    minHeight: 4.w,
                  ),
                ),
                Gap(4.w),
                // Duration
                Text(
                  _isPlaying || _positionSeconds > 0
                      ? _formatDuration(_positionSeconds)
                      : _formatDuration(_durationSeconds),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.neutral700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Video message bubble with thumbnail support
class _VideoMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback onTap;

  const _VideoMessageBubble({
    required this.message,
    required this.isMe,
    required this.onTap,
  });

  @override
  State<_VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<_VideoMessageBubble> {
  File? _cachedThumbnail;

  @override
  void initState() {
    super.initState();
    _checkCachedThumbnail();
  }

  Future<void> _checkCachedThumbnail() async {
    if (widget.message.mediaUrl == null) return;

    // If there's already a network thumbnail, no need to check cache
    if (widget.message.thumbnailUrl != null) return;

    try {
      final cacheService = MediaCacheService.instance;
      try {
        cacheService.basePath;
      } catch (_) {
        await cacheService.init();
      }

      // First check if thumbnail is already cached
      var thumbnail = await cacheService.getCachedThumbnail(
        widget.message.mediaUrl!,
      );

      // If no thumbnail but video is cached, generate one
      if (thumbnail == null) {
        final cachedVideo = await cacheService.getCachedVideo(
          widget.message.mediaUrl!,
          fileName: widget.message.fileName,
        );
        if (cachedVideo != null) {
          thumbnail = await cacheService.generateAndCacheThumbnail(
            widget.message.mediaUrl!,
            cachedVideo.path,
          );
        }
      }

      if (mounted && thumbnail != null) {
        setState(() {
          _cachedThumbnail = thumbnail;
        });
      }
    } catch (_) {
      // Ignore errors - just won't show cached thumbnail
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 180.w,
        height: 120.w,
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.2)
              : AppTheme.neutral700.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radius2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Priority: 1. Network thumbnail, 2. Cached thumbnail, 3. Placeholder
            if (message.thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                child: CachedNetworkImage(
                  imageUrl: message.thumbnailUrl!,
                  fit: BoxFit.cover,
                  width: 180.w,
                  height: 120.w,
                  placeholder: (context, url) => _buildPlaceholder(isMe),
                  errorWidget: (context, url, error) => _cachedThumbnail != null
                      ? _buildCachedThumbnail()
                      : _buildPlaceholder(isMe),
                ),
              )
            else if (_cachedThumbnail != null)
              _buildCachedThumbnail()
            else
              _buildPlaceholder(isMe),
            // Play button overlay
            Container(
              padding: EdgeInsets.all(AppTheme.spacing3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 32.sp),
            ),
            // File size badge
            if (message.fileSize != null)
              Positioned(
                bottom: 8.w,
                right: 8.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4.w),
                  ),
                  child: Text(
                    MediaService.formatFileSize(message.fileSize!),
                    style: TextStyle(fontSize: 10.sp, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCachedThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius2),
      child: Image.file(
        _cachedThumbnail!,
        fit: BoxFit.cover,
        width: 180.w,
        height: 120.w,
      ),
    );
  }

  Widget _buildPlaceholder(bool isMe) {
    return Container(
      width: 180.w,
      height: 120.w,
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.1)
            : AppTheme.neutral700.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radius2),
      ),
      child: Icon(
        Icons.videocam,
        color: isMe
            ? Colors.white.withValues(alpha: 0.5)
            : AppTheme.neutral700.withValues(alpha: 0.3),
        size: 40.sp,
      ),
    );
  }
}

/// Full screen video player
class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? fileName;

  const _FullScreenVideoPlayer({required this.videoUrl, this.fileName});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  double _downloadProgress = 0;
  String? _cachedFilePath; // Store for fallback external playback

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // Initialize cache service if needed
      final cacheService = MediaCacheService.instance;
      try {
        cacheService.basePath; // Check if initialized
      } catch (_) {
        await cacheService.init();
      }

      // Get cache path for this video
      final filePath = cacheService.getVideoCachePath(
        widget.videoUrl,
        fileName: widget.fileName,
      );
      final file = File(filePath);

      // Check if already cached
      if (await file.exists()) {
        // Video is cached, skip download
        if (mounted) {
          setState(() {
            _downloadProgress = 1.0;
          });
        }
      } else {
        // Download video with progress
        setState(() {
          _downloadProgress = 0;
        });

        final request = http.Request('GET', Uri.parse(widget.videoUrl));
        final response = await http.Client().send(request);
        final contentLength = response.contentLength ?? 0;

        final bytes = <int>[];
        int received = 0;

        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          received += chunk.length;
          if (contentLength > 0 && mounted) {
            setState(() {
              _downloadProgress = received / contentLength;
            });
          }
        }

        // Save to cache
        await cacheService.cacheVideo(
          widget.videoUrl,
          bytes,
          fileName: widget.fileName,
        );

        // Generate thumbnail for future use
        cacheService.generateAndCacheThumbnail(widget.videoUrl, filePath);
      }

      // Store cached file path for fallback
      _cachedFilePath = filePath;

      // Initialize video player with cached file
      _videoPlayerController = VideoPlayerController.file(file);
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.white, size: 48.sp),
                Gap(AppTheme.spacing2),
                Text(
                  'Error playing video',
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.fileName ?? 'Video',
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
        ),
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_downloadProgress > 0 && _downloadProgress < 1) ...[
                    SizedBox(
                      width: 60.w,
                      height: 60.w,
                      child: CircularProgressIndicator(
                        value: _downloadProgress,
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    Gap(AppTheme.spacing3),
                    Text(
                      'Downloading... ${(_downloadProgress * 100).toInt()}%',
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    ),
                  ] else ...[
                    const CircularProgressIndicator(color: Colors.white),
                    Gap(AppTheme.spacing3),
                    Text(
                      'Preparing video...',
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    ),
                  ],
                ],
              )
            : _error != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48.sp),
                  Gap(AppTheme.spacing2),
                  Text(
                    'Unable to play video in app',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    textAlign: TextAlign.center,
                  ),
                  Gap(AppTheme.spacing1),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing4,
                    ),
                    child: Text(
                      'This may be an emulator limitation.\nTry opening in external player.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12.sp,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Gap(AppTheme.spacing4),
                  // Fallback button to open externally
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (_cachedFilePath != null) {
                        final result = await OpenFilex.open(_cachedFilePath!);
                        if (result.type != ResultType.done && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not open: ${result.message}',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in External Player'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing4,
                        vertical: AppTheme.spacing2,
                      ),
                    ),
                  ),
                  Gap(AppTheme.spacing3),
                  // Show technical error details (smaller)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing4,
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 9.sp,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Chewie(controller: _chewieController!),
      ),
    );
  }
}
