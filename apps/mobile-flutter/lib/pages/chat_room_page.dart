import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

class ChatRoomPage extends StatefulWidget {
  final ChatRoom chatRoom;

  const ChatRoomPage({super.key, required this.chatRoom});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeChatRoom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Leave chat room when disposing
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
    return Consumer2<ChatProvider, UserProvider>(
      builder: (context, chatProvider, userProvider, child) {
        return Scaffold(
          appBar: _buildAppBar(chatProvider, userProvider),
          body: Column(
            children: [
              Expanded(child: _buildMessagesList(chatProvider, userProvider)),
              _buildMessageInput(chatProvider, userProvider),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) {
    final currentChatRoom = chatProvider.currentChatRoom ?? widget.chatRoom;

    return AppBar(
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userProvider.isPetOwner
                ? userProvider.connectedClinic?.name ?? 'Clinic'
                : currentChatRoom.petOwnerName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (currentChatRoom.topic != null)
            Text(
              currentChatRoom.topic!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      actions: [
        if (userProvider.isVet || userProvider.isClinicAdmin)
          IconButton(
            onPressed: () => _showParticipants(context, chatProvider),
            icon: const Icon(Icons.people),
          ),
        PopupMenuButton(
          onSelected: (action) =>
              _handleAppBarAction(action, chatProvider, userProvider),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'participants',
              child: ListTile(
                leading: Icon(Icons.people),
                title: Text('Participants'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (userProvider.isVet || userProvider.isClinicAdmin)
              const PopupMenuItem(
                value: 'add_vet',
                child: ListTile(
                  leading: Icon(Icons.person_add),
                  title: Text('Add Vet'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessagesList(
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) {
    if (chatProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final messages = chatProvider.currentMessages;

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Show newest messages at bottom
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isCurrentUser = message.senderId == userProvider.currentUser?.id;
        final showTimestamp = _shouldShowTimestamp(messages, index);

        return Column(
          children: [
            if (showTimestamp) _buildTimestampDivider(message.timestamp),
            _buildMessageBubble(message, isCurrentUser, userProvider),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildTimestampDivider(DateTime timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatTimestamp(timestamp),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    bool isCurrentUser,
    UserProvider userProvider,
  ) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCurrentUser ? AppTheme.primaryBlue : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isCurrentUser ? 18 : 4),
                  bottomRight: Radius.circular(isCurrentUser ? 4 : 18),
                ),
              ),
              child: _buildMessageContent(message, isCurrentUser),
            ),
            const SizedBox(height: 2),
            Text(
              _formatMessageTime(message.timestamp),
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isCurrentUser) {
    final textColor = isCurrentUser ? Colors.white : Colors.black87;

    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(color: textColor, fontSize: 16),
        );

      case MessageType.appointment:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event, color: textColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Appointment',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message.content,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ],
        );

      case MessageType.medication:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.medication, color: textColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Medication',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message.content,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ],
        );

      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image, color: textColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Image',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                message.content,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ],
          ],
        );
    }
  }

  Widget _buildMessageInput(
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: () => _showAttachmentOptions(context, chatProvider),
              icon: const Icon(Icons.attach_file),
              color: AppTheme.primaryBlue,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(chatProvider),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.primaryBlue,
              child: IconButton(
                onPressed: _isLoading ? null : () => _sendMessage(chatProvider),
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowTimestamp(List<ChatMessage> messages, int index) {
    if (index == messages.length - 1)
      return true; // Always show for first message

    final currentMessage = messages[index];
    final nextMessage = messages[index + 1];

    // Show timestamp if messages are more than 30 minutes apart
    final timeDifference = nextMessage.timestamp.difference(
      currentMessage.timestamp,
    );
    return timeDifference.inMinutes > 30;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sendMessage(ChatProvider chatProvider) async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isLoading = true);

    final success = await chatProvider.sendTextMessage(message);

    if (success) {
      _messageController.clear();
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  void _handleAppBarAction(
    String action,
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) {
    switch (action) {
      case 'participants':
        _showParticipants(context, chatProvider);
        break;
      case 'add_vet':
        _showAddVetDialog(context, chatProvider, userProvider);
        break;
    }
  }

  void _showParticipants(BuildContext context, ChatProvider chatProvider) {
    // TODO: Show chat info for one-on-one chat (vet info, pet info, etc.)
    // One-on-one chats don't have traditional participants list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat info not yet implemented for one-on-one chats'),
      ),
    );
  }

  void _showAddVetDialog(
    BuildContext context,
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) {
    // TODO: Implement add vet dialog with clinic member selection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add vet feature coming soon')),
    );
  }

  void _showAttachmentOptions(BuildContext context, ChatProvider chatProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _AttachmentOptionsSheet(
        onAppointmentShare: () {
          Navigator.pop(context);
          // TODO: Implement appointment sharing
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment sharing coming soon')),
          );
        },
        onMedicationShare: () {
          Navigator.pop(context);
          // TODO: Implement medication sharing
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medication sharing coming soon')),
          );
        },
      ),
    );
  }
}

// TODO: Remove - not needed for one-on-one chats
// class _ParticipantsSheet extends StatelessWidget {
//   final List<ChatParticipant> participants;
//   const _ParticipantsSheet({required this.participants});
//   @override Widget build(BuildContext context) { return Container(...); }
// }

class _AttachmentOptionsSheet extends StatelessWidget {
  final VoidCallback onAppointmentShare;
  final VoidCallback onMedicationShare;

  const _AttachmentOptionsSheet({
    required this.onAppointmentShare,
    required this.onMedicationShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Share',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttachmentOption(
                context,
                icon: Icons.event,
                label: 'Appointment',
                color: AppTheme.primaryBlue,
                onTap: onAppointmentShare,
              ),
              _buildAttachmentOption(
                context,
                icon: Icons.medication,
                label: 'Medication',
                color: AppTheme.primaryGreen,
                onTap: onMedicationShare,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
