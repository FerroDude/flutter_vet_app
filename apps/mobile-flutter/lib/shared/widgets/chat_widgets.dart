import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_models.dart';

/// Available emoji reactions
const List<String> kReactionEmojis = [
  '👍',
  '\u2764\uFE0F',
  '😂',
  '😮',
  '😢',
  '😡',
];

/// Reply data model for storing reply information
class ReplyData {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;

  const ReplyData({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'replyToId': messageId,
    'replyToSenderId': senderId,
    'replyToSenderName': senderName,
    'replyToContent': content,
    'replyToType': type.index,
  };

  factory ReplyData.fromJson(Map<String, dynamic> json) {
    return ReplyData(
      messageId: json['replyToId'] ?? '',
      senderId: json['replyToSenderId'] ?? '',
      senderName: json['replyToSenderName'] ?? '',
      content: json['replyToContent'] ?? '',
      type: MessageType.values[json['replyToType'] ?? 0],
    );
  }

  factory ReplyData.fromMessage(ChatMessage message) {
    return ReplyData(
      messageId: message.id,
      senderId: message.senderId,
      senderName: message.senderName,
      content: message.content,
      type: message.type,
    );
  }
}

/// Reaction data model
class ReactionData {
  final String emoji;
  final List<String> userIds;
  final List<String> userNames;

  const ReactionData({
    required this.emoji,
    required this.userIds,
    required this.userNames,
  });

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'userIds': userIds,
    'userNames': userNames,
  };

  factory ReactionData.fromJson(Map<String, dynamic> json) {
    return ReactionData(
      emoji: json['emoji'] ?? '',
      userIds: List<String>.from(json['userIds'] ?? []),
      userNames: List<String>.from(json['userNames'] ?? []),
    );
  }
}

/// Swipeable message wrapper for reply gesture
class SwipeableMessage extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeReply;
  final VoidCallback? onSwipeTime;
  final bool isMe;
  final bool enableSwipeToReply;
  final bool enableSwipeToTime;

  const SwipeableMessage({
    super.key,
    required this.child,
    required this.onSwipeReply,
    this.onSwipeTime,
    required this.isMe,
    this.enableSwipeToReply = true,
    this.enableSwipeToTime = true,
  });

  @override
  State<SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<SwipeableMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0;
  bool _showTime = false;

  static const double _replyThreshold = 60.0;
  static const double _timeThreshold = 40.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      // For "me" messages (right side), swipe left to reply
      // For "other" messages (left side), swipe right to reply
      if (widget.isMe) {
        _dragExtent += details.delta.dx;
        _dragExtent = _dragExtent.clamp(-100.0, 0.0);
      } else {
        _dragExtent += details.delta.dx;
        _dragExtent = _dragExtent.clamp(0.0, 100.0);
      }

      // Show time indicator
      if (_dragExtent.abs() > _timeThreshold && widget.enableSwipeToTime) {
        if (!_showTime) {
          _showTime = true;
          HapticFeedback.lightImpact();
        }
      } else {
        _showTime = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final absExtent = _dragExtent.abs();

    if (absExtent >= _replyThreshold && widget.enableSwipeToReply) {
      HapticFeedback.mediumImpact();
      widget.onSwipeReply();
    }

    setState(() {
      _dragExtent = 0;
      _showTime = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          // Reply indicator
          if (_dragExtent.abs() > 20)
            Positioned(
              left: widget.isMe ? null : 0,
              right: widget.isMe ? 0 : null,
              child: AnimatedOpacity(
                opacity: (_dragExtent.abs() / _replyThreshold).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 100),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.reply, color: Colors.white, size: 20.sp),
                ),
              ),
            ),
          // Message content
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Reply preview shown above the message input
class ReplyPreview extends StatelessWidget {
  final ReplyData replyData;
  final VoidCallback onCancel;
  final bool isMe;

  const ReplyPreview({
    super.key,
    required this.replyData,
    required this.onCancel,
    required this.isMe,
  });

  String _getPreviewText() {
    switch (replyData.type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.voice:
        return '🎤 Voice message';
      case MessageType.file:
        return '📎 File';
      default:
        return replyData.content.length > 50
            ? '${replyData.content.substring(0, 50)}...'
            : replyData.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing3,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: AppTheme.primary, width: 3.w),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${replyData.senderName}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
                Gap(2.h),
                Text(
                  _getPreviewText(),
                  style: TextStyle(fontSize: 13.sp, color: AppTheme.neutral700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: Icon(Icons.close, color: AppTheme.neutral700, size: 20.sp),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.w),
          ),
        ],
      ),
    );
  }
}

/// Reply bubble shown inside a message when it's replying to another
class ReplyBubble extends StatelessWidget {
  final ReplyData replyData;
  final bool isMe;
  final VoidCallback? onTap;

  const ReplyBubble({
    super.key,
    required this.replyData,
    required this.isMe,
    this.onTap,
  });

  String _getPreviewText() {
    switch (replyData.type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.voice:
        return '🎤 Voice message';
      case MessageType.file:
        return '📎 File';
      default:
        return replyData.content.length > 40
            ? '${replyData.content.substring(0, 40)}...'
            : replyData.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: AppTheme.spacing2),
        padding: EdgeInsets.all(AppTheme.spacing2),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withOpacity(0.15)
              : AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radius2),
          border: Border(
            left: BorderSide(
              color: isMe ? Colors.white.withOpacity(0.5) : AppTheme.primary,
              width: 2.w,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              replyData.senderName,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isMe ? Colors.white.withOpacity(0.9) : AppTheme.primary,
              ),
            ),
            Gap(2.h),
            Text(
              _getPreviewText(),
              style: TextStyle(
                fontSize: 12.sp,
                color: isMe
                    ? Colors.white.withOpacity(0.7)
                    : AppTheme.neutral700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Emoji reaction picker popup
class EmojiReactionPicker extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;
  final VoidCallback onClose;

  const EmojiReactionPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacing3,
          vertical: AppTheme.spacing2,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: kReactionEmojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onEmojiSelected(emoji);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Text(emoji, style: TextStyle(fontSize: 24.sp)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Display reactions below a message (WhatsApp style - overlapping bubble)
class ReactionsDisplay extends StatelessWidget {
  final List<ReactionData> reactions;
  final String currentUserId;
  final Function(String emoji) onReactionTap;
  final bool isMe;

  const ReactionsDisplay({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTap,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Background color matches the chat bubble
    final backgroundColor = isMe ? AppTheme.primary : Colors.white;

    return GestureDetector(
      onTap: () {
        // Tap on first reaction to toggle
        if (reactions.isNotEmpty) {
          onReactionTap(reactions.first.emoji);
        }
      },
      onLongPress: () => _showAllReactors(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show emojis (up to 3)
            ...reactions.take(3).map((reaction) {
              return Text(reaction.emoji, style: TextStyle(fontSize: 16.sp));
            }),
          ],
        ),
      ),
    );
  }

  void _showAllReactors(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.all(AppTheme.spacing4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.neutral400,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Gap(AppTheme.spacing4),
            Text(
              'Reactions',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
            Gap(AppTheme.spacing3),
            ...reactions.map(
              (reaction) => Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  children: [
                    Text(reaction.emoji, style: TextStyle(fontSize: 24.sp)),
                    Gap(AppTheme.spacing3),
                    Expanded(
                      child: Text(
                        reaction.userNames.join(', '),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppTheme.neutral700,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.neutral100,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        '${reaction.userIds.length}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.neutral700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Gap(AppTheme.spacing4),
          ],
        ),
      ),
    );
  }
}

/// Link preview widget for URLs in messages
class LinkPreviewWidget extends StatelessWidget {
  final String url;
  final bool isMe;

  const LinkPreviewWidget({super.key, required this.url, required this.isMe});

  Future<void> _launchUrl() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _launchUrl,
      child: Container(
        margin: EdgeInsets.only(top: AppTheme.spacing2),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.15) : AppTheme.neutral100,
          borderRadius: BorderRadius.circular(AppTheme.radius2),
        ),
        child: AnyLinkPreview.builder(
          link: url,
          placeholderWidget: Container(
            padding: EdgeInsets.all(AppTheme.spacing3),
            child: Row(
              children: [
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMe ? Colors.white : AppTheme.primary,
                    ),
                  ),
                ),
                Gap(AppTheme.spacing2),
                Expanded(
                  child: Text(
                    url,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isMe
                          ? Colors.white.withOpacity(0.7)
                          : AppTheme.neutral700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          errorWidget: Container(
            padding: EdgeInsets.all(AppTheme.spacing3),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: 20.sp,
                  color: isMe
                      ? Colors.white.withOpacity(0.7)
                      : AppTheme.primary,
                ),
                Gap(AppTheme.spacing2),
                Expanded(
                  child: Text(
                    url,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isMe
                          ? Colors.white.withOpacity(0.7)
                          : AppTheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          itemBuilder: (context, metadata, imageProvider, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image preview
                if (imageProvider != null)
                  Container(
                    height: 120.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                // Text content
                Padding(
                  padding: EdgeInsets.all(AppTheme.spacing2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (metadata.title != null)
                        Text(
                          metadata.title!,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: isMe ? Colors.white : AppTheme.primary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (metadata.desc != null) ...[
                        Gap(4.h),
                        Text(
                          metadata.desc!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isMe
                                ? Colors.white.withOpacity(0.7)
                                : AppTheme.neutral700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      Gap(4.h),
                      Row(
                        children: [
                          Icon(
                            Icons.link,
                            size: 12.sp,
                            color: isMe
                                ? Colors.white.withOpacity(0.5)
                                : AppTheme.neutral600,
                          ),
                          Gap(4.w),
                          Expanded(
                            child: Text(
                              Uri.parse(url).host,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: isMe
                                    ? Colors.white.withOpacity(0.5)
                                    : AppTheme.neutral600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Chat search bar widget
class ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClose;
  final Function(String) onChanged;
  final int matchCount;
  final int currentMatch;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const ChatSearchBar({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onChanged,
    required this.matchCount,
    required this.currentMatch,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing3,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              style: TextStyle(fontSize: 14.sp, color: AppTheme.primary),
              decoration: InputDecoration(
                hintText: 'Search messages...',
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.neutral600,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20.sp,
                  color: AppTheme.neutral600,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true,
                fillColor: AppTheme.neutral100,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing3,
                  vertical: AppTheme.spacing2,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty) ...[
            Gap(AppTheme.spacing2),
            Text(
              matchCount > 0 ? '$currentMatch of $matchCount' : 'No results',
              style: TextStyle(fontSize: 12.sp, color: AppTheme.neutral700),
            ),
            Gap(AppTheme.spacing1),
            IconButton(
              onPressed: matchCount > 0 ? onPrevious : null,
              icon: Icon(
                Icons.keyboard_arrow_up,
                color: matchCount > 0 ? AppTheme.primary : AppTheme.neutral400,
              ),
              constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.w),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              onPressed: matchCount > 0 ? onNext : null,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: matchCount > 0 ? AppTheme.primary : AppTheme.neutral400,
              ),
              constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.w),
              padding: EdgeInsets.zero,
            ),
          ],
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: AppTheme.neutral700, size: 20.sp),
            constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.w),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// Utility to extract URLs from text
class UrlUtils {
  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s<>\[\]{}|\\^]+',
    caseSensitive: false,
  );

  static List<String> extractUrls(String text) {
    return _urlRegex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  static bool hasUrl(String text) {
    return _urlRegex.hasMatch(text);
  }
}

/// Highlighted text widget for search results
class HighlightedText extends StatelessWidget {
  final String text;
  final String highlight;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  const HighlightedText({
    super.key,
    required this.text,
    required this.highlight,
    this.style,
    this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (highlight.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerHighlight, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + highlight.length),
          style:
              highlightStyle ??
              style?.copyWith(
                backgroundColor: Colors.yellow.withOpacity(0.5),
                fontWeight: FontWeight.bold,
              ),
        ),
      );

      start = index + highlight.length;
    }

    return RichText(text: TextSpan(children: spans));
  }
}

/// Message highlight animation wrapper
class MessageHighlight extends StatefulWidget {
  final Widget child;
  final bool shouldHighlight;
  final VoidCallback? onHighlightComplete;

  const MessageHighlight({
    super.key,
    required this.child,
    required this.shouldHighlight,
    this.onHighlightComplete,
  });

  @override
  State<MessageHighlight> createState() => _MessageHighlightState();
}

class _MessageHighlightState extends State<MessageHighlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _colorAnimation = ColorTween(
      begin: AppTheme.primary.withOpacity(0.3),
      end: Colors.transparent,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onHighlightComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(MessageHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldHighlight && !oldWidget.shouldHighlight) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: widget.shouldHighlight ? _colorAnimation.value : null,
            borderRadius: BorderRadius.circular(AppTheme.radius3),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
