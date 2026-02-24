import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../shared/widgets/app_components.dart';
import '../../shared/widgets/pet_info_widget.dart';
import 'chat_room_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String? _lastClinicId;
  String? _lastPetOwnerId;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndInitializeChats();
  }

  void _checkAndInitializeChats() {
    final userProvider = Provider.of<UserProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (userProvider.isLoading) return;

    if (userProvider.isPetOwner) {
      final petOwnerId = userProvider.currentUser?.id;
      if (petOwnerId != null && petOwnerId != _lastPetOwnerId) {
        _lastPetOwnerId = petOwnerId;
        if (userProvider.hasClinicConnection) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            chatProvider.initializeChatRooms(petOwnerId: petOwnerId);
          });
        }
      }
    } else if (userProvider.isVet ||
        userProvider.isClinicAdmin ||
        userProvider.isReceptionist) {
      final clinicId = userProvider.connectedClinic?.id;
      final userId = userProvider.currentUser?.id;
      if (clinicId != null && userId != null && clinicId != _lastClinicId) {
        _lastClinicId = clinicId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          chatProvider.initializeChatRooms(
            clinicId: clinicId,
            // All staff see their own accepted chats + pending requests
            vetId: userId,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, UserProvider>(
      builder: (context, chatProvider, userProvider, child) {
        final hasPendingRequest =
            userProvider.isPetOwner &&
            chatProvider.chatRooms.any(
              (room) => room.status == ChatRoomStatus.pending,
            );

        return Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: _isSearching
                  ? Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radius3),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16.sp,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search chats...',
                          hintStyle: TextStyle(
                            color: AppTheme.neutral600,
                            fontSize: 16.sp,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          icon: Icon(
                            Icons.search,
                            color: AppTheme.neutral600,
                            size: 20.sp,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      'Chats',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              leading: _isSearching
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          _isSearching = false;
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              actions: [
                if (!_isSearching)
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                    tooltip: 'Search',
                  ),
                if (_isSearching && _searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                    tooltip: 'Clear',
                  ),
                if (!_isSearching) ...[
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
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
                    icon: const Icon(Icons.person_outline),
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
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () => _refreshChats(chatProvider, userProvider),
              child: _buildChatsList(chatProvider, userProvider),
            ),
            floatingActionButton:
                userProvider.isPetOwner &&
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
      return const AppLoadingIndicator();
    }

    if (chatProvider.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        message: chatProvider.error!,
        actionLabel: 'Try Again',
        onAction: () => _refreshChats(chatProvider, userProvider),
      );
    }

    var chatRooms = chatProvider.chatRooms;

    // For vets/admins/receptionists, also show pending requests
    var pendingRequests =
        userProvider.isVet ||
            userProvider.isClinicAdmin ||
            userProvider.isReceptionist
        ? chatProvider.pendingRequests
        : const <ChatRoom>[];

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      chatRooms = chatRooms.where((room) {
        final name = _getDisplayName(room, userProvider).toLowerCase();
        final lastMsg = (room.lastMessage?.content ?? '').toLowerCase();
        final topic = (room.topic ?? '').toLowerCase();
        return name.contains(_searchQuery) ||
            lastMsg.contains(_searchQuery) ||
            topic.contains(_searchQuery);
      }).toList();

      pendingRequests = pendingRequests.where((room) {
        final name = _getDisplayName(room, userProvider).toLowerCase();
        final desc = (room.requestDescription ?? '').toLowerCase();
        return name.contains(_searchQuery) || desc.contains(_searchQuery);
      }).toList();
    }

    if (chatRooms.isEmpty && pendingRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isNotEmpty
                    ? Icons.search_off
                    : Icons.chat_bubble_outline,
                size: 64.sp,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              Gap(AppTheme.spacing3),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No chats found for "$_searchQuery"'
                    : 'No conversations yet',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty) ...[
                Gap(AppTheme.spacing2),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                    });
                  },
                  child: Text(
                    'Clear search',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(AppTheme.spacing4),
      children: [
        if (pendingRequests.isNotEmpty &&
            (userProvider.isVet ||
                userProvider.isClinicAdmin ||
                userProvider.isReceptionist)) ...[
          Text(
            'Chat requests',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
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
            color: Colors.white.withValues(alpha: 0.9),
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
    if (userProvider.isPetOwner && chatRoom.status == ChatRoomStatus.pending) {
      final clinicName = userProvider.connectedClinic?.name ?? 'clinic';
      subtitle = 'Chat request to $clinicName • Waiting for vet';
    } else {
      subtitle = lastMessage;
    }

    // Format the timestamp for last message
    final lastMessageTime =
        chatRoom.lastMessage?.timestamp ?? chatRoom.updatedAt;
    final timeString = _formatChatTime(lastMessageTime);

    return InkWell(
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
      onLongPress:
          (userProvider.isVet ||
              userProvider.isClinicAdmin ||
              userProvider.isReceptionist)
          ? () => _showChatOptionsMenu(chatRoom, chatProvider, userProvider)
          : null,
      borderRadius: BorderRadius.circular(AppTheme.radius4),
      child: Container(
        decoration: BoxDecoration(
          // Highlight unread chats with a subtle left border
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius4),
          border: hasUnread
              ? Border(
                  left: BorderSide(color: AppTheme.primary, width: 4.w),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: hasUnread
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: hasUnread ? 12 : 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(AppTheme.spacing3),
        child: Row(
          children: [
            // Avatar with unread indicator
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: hasUnread
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : AppTheme.primary.withValues(alpha: 0.1),
                  radius: 24.r,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 18.sp,
                    ),
                  ),
                ),
                // Small dot indicator for unread
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            Gap(AppTheme.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppTheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Pet name chip
                            if (chatRoom.petIds.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 2.h),
                                child: _PetNameChip(
                                  petOwnerId: chatRoom.petOwnerId,
                                  petId: chatRoom.petIds.first,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Time indicator
                      Text(
                        timeString,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: hasUnread
                              ? AppTheme.primary
                              : AppTheme.neutral700,
                        ),
                      ),
                    ],
                  ),
                  Gap(4.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: hasUnread
                                ? AppTheme.neutral800
                                : AppTheme.neutral700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Unread count badge
                      if (hasUnread)
                        Container(
                          margin: EdgeInsets.only(left: AppTheme.spacing2),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (userProvider.isPetOwner &&
                chatRoom.status == ChatRoomStatus.pending)
              TextButton(
                onPressed: () => _confirmCancelRequest(chatRoom, chatProvider),
                child: const Text('Cancel'),
              )
            else if (userProvider.isVet ||
                userProvider.isClinicAdmin ||
                userProvider.isReceptionist)
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppTheme.neutral700),
                onPressed: () =>
                    _showChatOptionsMenu(chatRoom, chatProvider, userProvider),
              ),
          ],
        ),
      ),
    );
  }

  /// Format chat timestamp to show relative time
  String _formatChatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    } else if (diff.inDays < 1) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (diff.inDays < 7) {
      return DateFormat('EEE').format(timestamp);
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat request cancelled')));
      } else if (chatProvider.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(chatProvider.error!)));
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
    } else if (userProvider.isVet ||
        userProvider.isClinicAdmin ||
        userProvider.isReceptionist) {
      final clinicId = userProvider.connectedClinic?.id;
      final userId = userProvider.currentUser?.id;
      if (clinicId != null && userId != null) {
        await chatProvider.initializeChatRooms(
          clinicId: clinicId,
          vetId: userId,
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
    String? selectedPetId;
    String? validationError;

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                gradient: AppTheme.backgroundGradient,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacing4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: EdgeInsets.only(bottom: AppTheme.spacing4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Title
                      Text(
                        'New Chat Request',
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      SizedBox(height: AppTheme.spacing4),

                      // Pet selector
                      PetSelector(
                        petOwnerId: userProvider.currentUser?.id ?? '',
                        selectedPetId: selectedPetId,
                        onPetSelected: (petId) {
                          setSheetState(() {
                            selectedPetId = petId;
                            validationError = null;
                          });
                        },
                      ),
                      SizedBox(height: AppTheme.spacing4),

                      // Title field
                      Text(
                        'Title',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing2),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radius2),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: TextField(
                          controller: titleController,
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Follow-up about symptoms',
                            hintStyle: TextStyle(
                              color: AppTheme.neutral700.withValues(alpha: 0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(AppTheme.spacing3),
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing4),
                      // Description field
                      Text(
                        'Description (optional)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing2),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radius2),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: TextField(
                          controller: descriptionController,
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 16,
                          ),
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Describe the reason for this chat',
                            hintStyle: TextStyle(
                              color: AppTheme.neutral700.withValues(alpha: 0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(AppTheme.spacing3),
                          ),
                        ),
                      ),
                      // Validation error
                      if (validationError != null) ...[
                        SizedBox(height: AppTheme.spacing3),
                        Container(
                          padding: EdgeInsets.all(AppTheme.spacing3),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius2,
                            ),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 18.sp,
                              ),
                              SizedBox(width: AppTheme.spacing2),
                              Expanded(
                                child: Text(
                                  validationError!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: AppTheme.spacing6),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(null),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: AppTheme.spacing3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius2,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          SizedBox(width: AppTheme.spacing3),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // Validate pet selection
                                if (selectedPetId == null) {
                                  setSheetState(() {
                                    validationError =
                                        'Please select a pet for this chat';
                                  });
                                  return;
                                }
                                if (titleController.text.trim().isEmpty) {
                                  setSheetState(() {
                                    validationError = 'Please enter a title';
                                  });
                                  return;
                                }
                                Navigator.of(sheetContext).pop({
                                  'petId': selectedPetId,
                                  'title': titleController.text.trim(),
                                  'description': descriptionController.text
                                      .trim(),
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primary,
                                padding: EdgeInsets.symmetric(
                                  vertical: AppTheme.spacing3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius2,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Create',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spacing4),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      final clinicId = userProvider.connectedClinic?.id;
      final petOwnerId = userProvider.currentUser?.id;
      final petOwnerName = userProvider.currentUser?.displayName ?? 'Pet Owner';

      if (clinicId == null || petOwnerId == null) return;

      final chatId = await chatProvider.createChatRequest(
        clinicId: clinicId,
        petOwnerId: petOwnerId,
        petOwnerName: petOwnerName,
        title: result['title'] as String,
        description: (result['description'] as String).isEmpty
            ? null
            : result['description'] as String,
        petIds: [result['petId'] as String],
      );

      if (!mounted) return;

      if (chatId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat request sent to clinic')),
        );
      } else if (chatProvider.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(chatProvider.error!)));
      }
    }
  }

  Future<void> _showChatOptionsMenu(
    ChatRoom chatRoom,
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return Container(
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(AppTheme.spacing4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Manage Chat',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Chat info card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  chatRoom.petOwnerName[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chatRoom.petOwnerName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (chatRoom.topic != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      chatRoom.topic!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Delete action card
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              Navigator.of(dialogContext).pop('delete'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: AppTheme.error,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Delete Chat',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Permanently remove this conversation',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Cancel button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacing3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == 'delete') {
      _confirmDeleteChat(chatRoom, chatProvider);
    }
  }

  Future<void> _confirmDeleteChat(
    ChatRoom chatRoom,
    ChatProvider chatProvider,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return Container(
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(AppTheme.spacing4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              size: 22,
                              color: AppTheme.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Delete Chat',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Message
                      Text(
                        'Are you sure you want to delete this chat? '
                        'This will remove the conversation for both you and the pet owner. '
                        'This action cannot be undone.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.error,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spacing2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      final success = await chatProvider.deleteChatRoom(chatRoom.id);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted successfully')),
        );
      } else if (chatProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.error!),
            backgroundColor: Colors.red,
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
    final hasPet = chatRoom.petIds.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(AppTheme.spacing3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Pet owner name and pet info
          Row(
            children: [
              Expanded(
                child: Text(
                  'From: $petOwnerName',
                  style: TextStyle(fontSize: 12.sp, color: AppTheme.neutral700),
                ),
              ),
            ],
          ),
          // Pet info chip if a pet is associated
          if (hasPet) ...[
            const SizedBox(height: 8),
            PetInfoWidget(
              petOwnerId: chatRoom.petOwnerId,
              petId: chatRoom.petIds.first,
              style: PetInfoStyle.chip,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontSize: 13.sp, color: AppTheme.neutral700),
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
                      const SnackBar(content: Text('Chat request accepted')),
                    );
                  } else if (chatProvider.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(chatProvider.error!)),
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

/// A small chip that displays the pet name for chat list items
class _PetNameChip extends StatelessWidget {
  final String petOwnerId;
  final String petId;

  const _PetNameChip({required this.petOwnerId, required this.petId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(petOwnerId)
          .collection('pets')
          .doc(petId)
          .snapshots(),
      builder: (context, snapshot) {
        String petName = 'Pet';

        if (snapshot.hasData && snapshot.data!.exists) {
          final petData = snapshot.data!.data()!;
          petName = petData['name'] as String? ?? 'Pet';
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, size: 12.sp, color: AppTheme.brandTeal),
            SizedBox(width: 4.w),
            Text(
              petName,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.brandTeal,
              ),
            ),
          ],
        );
      },
    );
  }
}
