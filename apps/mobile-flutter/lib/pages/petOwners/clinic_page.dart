import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_models.dart';
import '../../models/appointment_request_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/appointment_request_provider.dart';
import '../../shared/widgets/app_components.dart';
import '../../shared/widgets/pet_info_widget.dart';
import 'chat_room_page.dart';
import 'appointment_request_form.dart';
import 'pet_form_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';

/// Filter options for the clinic communication feed
enum ClinicFeedFilter { all, chats, appointments }

/// A unified item type for the combined feed
abstract class FeedItem {
  DateTime get sortDate;
  String get id;
}

class ChatFeedItem extends FeedItem {
  final ChatRoom chatRoom;
  ChatFeedItem(this.chatRoom);

  @override
  DateTime get sortDate =>
      chatRoom.lastMessage?.timestamp ?? chatRoom.updatedAt;

  @override
  String get id => 'chat_${chatRoom.id}';
}

class AppointmentFeedItem extends FeedItem {
  final AppointmentRequest request;
  AppointmentFeedItem(this.request);

  @override
  DateTime get sortDate => request.updatedAt;

  @override
  String get id => 'appt_${request.id}';
}

/// Unified Clinic Communication page for pet owners
/// Combines chat conversations and appointment requests in a single feed
class ClinicPage extends StatefulWidget {
  const ClinicPage({super.key});

  @override
  State<ClinicPage> createState() => _ClinicPageState();
}

class _ClinicPageState extends State<ClinicPage> {
  String? _lastPetOwnerId;
  ClinicFeedFilter _currentFilter = ClinicFeedFilter.all;

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
    _checkAndInitialize();
  }

  void _checkAndInitialize() {
    final userProvider = Provider.of<UserProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final appointmentProvider = Provider.of<AppointmentRequestProvider>(
      context,
      listen: false,
    );

    if (userProvider.isLoading) return;

    if (userProvider.isPetOwner) {
      final petOwnerId = userProvider.currentUser?.id;
      if (petOwnerId != null && petOwnerId != _lastPetOwnerId) {
        _lastPetOwnerId = petOwnerId;
        if (userProvider.hasClinicConnection) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            chatProvider.initializeChatRooms(petOwnerId: petOwnerId);
            appointmentProvider.initializeForPetOwner(petOwnerId);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ChatProvider, UserProvider, AppointmentRequestProvider>(
      builder: (context, chatProvider, userProvider, appointmentProvider, _) {
        final hasPendingChatRequest =
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
            appBar: _buildAppBar(userProvider),
            body: RefreshIndicator(
              onRefresh: () =>
                  _refresh(chatProvider, appointmentProvider, userProvider),
              child: _buildBody(
                chatProvider,
                userProvider,
                appointmentProvider,
              ),
            ),
            floatingActionButton:
                userProvider.isPetOwner && userProvider.hasClinicConnection
                ? _buildFAB(chatProvider, userProvider, hasPendingChatRequest)
                : null,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(UserProvider userProvider) {
    return AppBar(
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
                style: TextStyle(color: AppTheme.primary, fontSize: 16.sp),
                decoration: InputDecoration(
                  hintText: 'Search...',
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
              'Clinic',
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
    );
  }

  Widget _buildBody(
    ChatProvider chatProvider,
    UserProvider userProvider,
    AppointmentRequestProvider appointmentProvider,
  ) {
    // Check if not connected to clinic
    if (userProvider.isPetOwner && !userProvider.hasClinicConnection) {
      return AppEmptyState(
        icon: Icons.medical_services_outlined,
        message:
            'Connect to a veterinary clinic to communicate with your vet and request appointments.',
        actionLabel: 'Learn More',
        onAction: () {},
      );
    }

    // Check loading state
    final isLoading = chatProvider.isLoading || appointmentProvider.isLoading;
    final hasData =
        chatProvider.chatRooms.isNotEmpty ||
        appointmentProvider.myRequests.isNotEmpty;

    if (isLoading && !hasData) {
      return const AppLoadingIndicator();
    }

    // Check for errors
    if (chatProvider.error != null && appointmentProvider.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        message: chatProvider.error ?? appointmentProvider.error!,
        actionLabel: 'Try Again',
        onAction: () =>
            _refresh(chatProvider, appointmentProvider, userProvider),
      );
    }

    return Column(
      children: [
        // Filter chips
        _buildFilterChips(chatProvider, appointmentProvider),
        // Feed list
        Expanded(
          child: _buildFeedList(
            chatProvider,
            userProvider,
            appointmentProvider,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(
    ChatProvider chatProvider,
    AppointmentRequestProvider appointmentProvider,
  ) {
    final chatCount = chatProvider.chatRooms.length;
    final appointmentCount = appointmentProvider.myRequests.length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing4,
        vertical: AppTheme.spacing2,
      ),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            count: chatCount + appointmentCount,
            isSelected: _currentFilter == ClinicFeedFilter.all,
            onTap: () => setState(() => _currentFilter = ClinicFeedFilter.all),
          ),
          Gap(AppTheme.spacing2),
          _FilterChip(
            label: 'Chats',
            count: chatCount,
            isSelected: _currentFilter == ClinicFeedFilter.chats,
            onTap: () =>
                setState(() => _currentFilter = ClinicFeedFilter.chats),
            icon: Icons.chat_bubble_outline,
          ),
          Gap(AppTheme.spacing2),
          _FilterChip(
            label: 'Appointments',
            count: appointmentCount,
            isSelected: _currentFilter == ClinicFeedFilter.appointments,
            onTap: () =>
                setState(() => _currentFilter = ClinicFeedFilter.appointments),
            icon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList(
    ChatProvider chatProvider,
    UserProvider userProvider,
    AppointmentRequestProvider appointmentProvider,
  ) {
    // Build combined feed items
    List<FeedItem> feedItems = [];

    // Add chat items based on filter
    if (_currentFilter == ClinicFeedFilter.all ||
        _currentFilter == ClinicFeedFilter.chats) {
      feedItems.addAll(
        chatProvider.chatRooms.map((room) => ChatFeedItem(room)),
      );
    }

    // Add appointment items based on filter
    if (_currentFilter == ClinicFeedFilter.all ||
        _currentFilter == ClinicFeedFilter.appointments) {
      feedItems.addAll(
        appointmentProvider.myRequests.map((req) => AppointmentFeedItem(req)),
      );
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      feedItems = feedItems.where((item) {
        if (item is ChatFeedItem) {
          final room = item.chatRoom;
          final name = _getChatDisplayName(room, userProvider).toLowerCase();
          final lastMsg = (room.lastMessage?.content ?? '').toLowerCase();
          final topic = (room.topic ?? '').toLowerCase();
          return name.contains(_searchQuery) ||
              lastMsg.contains(_searchQuery) ||
              topic.contains(_searchQuery);
        } else if (item is AppointmentFeedItem) {
          final req = item.request;
          final petName = req.petName.toLowerCase();
          final reason = req.reason.toLowerCase();
          return petName.contains(_searchQuery) ||
              reason.contains(_searchQuery);
        }
        return false;
      }).toList();
    }

    // Sort by most recent
    feedItems.sort((a, b) => b.sortDate.compareTo(a.sortDate));

    if (feedItems.isEmpty) {
      return _buildEmptyState(chatProvider, userProvider);
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppTheme.spacing4),
      itemCount: feedItems.length,
      itemBuilder: (context, index) {
        final item = feedItems[index];
        if (item is ChatFeedItem) {
          return Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacing2),
            child: _buildChatCard(item.chatRoom, userProvider, chatProvider),
          );
        } else if (item is AppointmentFeedItem) {
          return Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacing2),
            child: _buildAppointmentCard(item.request, appointmentProvider),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState(
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) {
    String message;
    IconData icon;
    Widget? action;
    final hasPendingChatRequest =
        userProvider.isPetOwner &&
        chatProvider.chatRooms.any(
          (room) => room.status == ChatRoomStatus.pending,
        );

    if (_searchQuery.isNotEmpty) {
      icon = Icons.search_off;
      message = 'No results found for "$_searchQuery"';
    } else {
      switch (_currentFilter) {
        case ClinicFeedFilter.chats:
          icon = Icons.chat_bubble_outline;
          message =
              'No chat conversations yet.\nStart a new chat with your clinic.';
          action = FloatingActionButton.extended(
            heroTag: 'empty_state_chat_fab',
            onPressed: hasPendingChatRequest
                ? null
                : () => _showNewChatRequestDialog(chatProvider, userProvider),
            backgroundColor: hasPendingChatRequest
                ? AppTheme.neutral500
                : AppTheme.neutral800,
            foregroundColor: Colors.white,
            icon: Icon(
              hasPendingChatRequest
                  ? Icons.hourglass_top
                  : Icons.add_comment_outlined,
            ),
            label: Text(hasPendingChatRequest ? 'Chat Pending' : 'New Chat'),
          );
          break;
        case ClinicFeedFilter.appointments:
          icon = Icons.calendar_today_outlined;
          message =
              'No appointment requests yet.\nRequest an appointment with your clinic.';
          action = FloatingActionButton.extended(
            heroTag: 'empty_state_appointment_fab',
            onPressed: _openAppointmentForm,
            backgroundColor: AppTheme.brandTeal,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.calendar_today),
            label: const Text('Request Appointment'),
          );
          break;
        case ClinicFeedFilter.all:
          icon = Icons.forum_outlined;
          message =
              'No activity yet.\nStart a chat or request an appointment with your clinic.';
          break;
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64.sp, color: Colors.white.withValues(alpha: 0.5)),
            Gap(AppTheme.spacing3),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty && action != null) ...[
              Gap(AppTheme.spacing3),
              action,
            ],
            if (_searchQuery.isNotEmpty) ...[
              Gap(AppTheme.spacing2),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _isSearching = false;
                  });
                },
                child: const Text(
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

  Widget _buildChatCard(
    ChatRoom chatRoom,
    UserProvider userProvider,
    ChatProvider chatProvider,
  ) {
    final displayName = _getChatDisplayName(chatRoom, userProvider);
    final lastMessage = chatRoom.lastMessage?.content ?? 'No messages yet';
    final currentUserId = userProvider.currentUser?.id ?? '';
    final hasUnread = (chatRoom.unreadCounts[currentUserId] ?? 0) > 0;
    final unreadCount = chatRoom.unreadCounts[currentUserId] ?? 0;

    // For pet owners, show a clear indicator when this is just a chat request
    String subtitle;
    if (userProvider.isPetOwner && chatRoom.status == ChatRoomStatus.pending) {
      final clinicName = userProvider.connectedClinic?.name ?? 'clinic';
      subtitle = 'Chat request to $clinicName - Waiting for vet';
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
      borderRadius: BorderRadius.circular(AppTheme.radius4),
      child: Container(
        decoration: BoxDecoration(
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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(AppTheme.spacing3),
        child: Row(
          children: [
            // Type indicator + Avatar
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: hasUnread
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : AppTheme.primary.withValues(alpha: 0.1),
                  radius: 24.r,
                  child: Icon(
                    Icons.chat_bubble,
                    color: AppTheme.primary,
                    size: 20.sp,
                  ),
                ),
                // Unread indicator
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
                            Row(
                              children: [
                                // Chat type label
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.brandTeal.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radius1,
                                    ),
                                  ),
                                  child: Text(
                                    'CHAT',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.brandTeal,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Gap(AppTheme.spacing2),
                                Expanded(
                                  child: Text(
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
                                ),
                              ],
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
                onPressed: () =>
                    _confirmCancelChatRequest(chatRoom, chatProvider),
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(
    AppointmentRequest request,
    AppointmentRequestProvider appointmentProvider,
  ) {
    final dateFormat = DateFormat('MMM d');
    final dateRangeText =
        '${dateFormat.format(request.preferredDateStart)} - ${dateFormat.format(request.preferredDateEnd)}';
    final timeString = _formatChatTime(request.updatedAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content
          Padding(
            padding: EdgeInsets.all(AppTheme.spacing3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type indicator
                CircleAvatar(
                  backgroundColor: _getStatusColor(
                    request.status,
                  ).withValues(alpha: 0.15),
                  radius: 24.r,
                  child: Icon(
                    Icons.calendar_today,
                    color: _getStatusColor(request.status),
                    size: 20.sp,
                  ),
                ),
                Gap(AppTheme.spacing3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Appointment type label
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                request.status,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius1,
                              ),
                            ),
                            child: Text(
                              'APPOINTMENT',
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(request.status),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Gap(AppTheme.spacing2),
                          _buildStatusBadge(request.status),
                          const Spacer(),
                          Text(
                            timeString,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.neutral700,
                            ),
                          ),
                        ],
                      ),
                      Gap(AppTheme.spacing2),
                      // Pet name
                      Row(
                        children: [
                          Icon(
                            Icons.pets,
                            color: AppTheme.brandTeal,
                            size: 16.sp,
                          ),
                          Gap(AppTheme.spacing1),
                          Text(
                            request.petName,
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Gap(AppTheme.spacing1),
                      // Date and time preference
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: AppTheme.neutral700,
                            size: 14.sp,
                          ),
                          Gap(4.w),
                          Text(
                            dateRangeText,
                            style: TextStyle(
                              color: AppTheme.neutral700,
                              fontSize: 13.sp,
                            ),
                          ),
                          Gap(AppTheme.spacing2),
                          Icon(
                            Icons.access_time,
                            color: AppTheme.neutral700,
                            size: 14.sp,
                          ),
                          Gap(4.w),
                          Text(
                            request.timePreference.shortText,
                            style: TextStyle(
                              color: AppTheme.neutral700,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                      Gap(AppTheme.spacing1),
                      // Reason
                      Text(
                        request.reason,
                        style: TextStyle(
                          color: AppTheme.neutral700,
                          fontSize: 13.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Response message if any
                      if (request.responseMessage != null &&
                          request.responseMessage!.isNotEmpty) ...[
                        Gap(AppTheme.spacing2),
                        Container(
                          padding: EdgeInsets.all(AppTheme.spacing2),
                          decoration: BoxDecoration(
                            color: AppTheme.neutral100,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius2,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.message,
                                color: AppTheme.neutral700,
                                size: 14.sp,
                              ),
                              Gap(AppTheme.spacing2),
                              Expanded(
                                child: Text(
                                  request.responseMessage!,
                                  style: TextStyle(
                                    color: AppTheme.neutral700,
                                    fontSize: 12.sp,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Cancel button for pending requests
                      if (request.isPending) ...[
                        Gap(AppTheme.spacing2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _confirmCancelAppointment(
                              request,
                              appointmentProvider,
                            ),
                            child: Text(
                              'Cancel Request',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 13.sp,
                              ),
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
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AppointmentRequestStatus status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(AppTheme.radius1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), color: Colors.white, size: 10.sp),
          Gap(2.w),
          Text(
            status.displayText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AppointmentRequestStatus status) {
    switch (status) {
      case AppointmentRequestStatus.pending:
        return Colors.orange;
      case AppointmentRequestStatus.confirmed:
        return AppTheme.brandTeal;
      case AppointmentRequestStatus.denied:
        return Colors.red;
      case AppointmentRequestStatus.cancelled:
        return AppTheme.neutral500;
    }
  }

  IconData _getStatusIcon(AppointmentRequestStatus status) {
    switch (status) {
      case AppointmentRequestStatus.pending:
        return Icons.schedule;
      case AppointmentRequestStatus.confirmed:
        return Icons.check_circle;
      case AppointmentRequestStatus.denied:
        return Icons.cancel;
      case AppointmentRequestStatus.cancelled:
        return Icons.block;
    }
  }

  Widget _buildFAB(
    ChatProvider chatProvider,
    UserProvider userProvider,
    bool hasPendingChatRequest,
  ) {
    // Show different FAB(s) based on current filter
    switch (_currentFilter) {
      case ClinicFeedFilter.chats:
        // Only show chat button when in chats filter
        if (hasPendingChatRequest) {
          // If user has pending chat request, show disabled state or info
          return FloatingActionButton.extended(
            heroTag: 'chat_fab',
            onPressed: null,
            backgroundColor: AppTheme.neutral500,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.hourglass_top),
            label: const Text('Chat Pending'),
          );
        }
        return FloatingActionButton.extended(
          heroTag: 'chat_fab',
          onPressed: () =>
              _showNewChatRequestDialog(chatProvider, userProvider),
          backgroundColor: AppTheme.neutral800,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('New Chat'),
        );

      case ClinicFeedFilter.appointments:
        // Only show appointment button when in appointments filter
        return FloatingActionButton.extended(
          heroTag: 'appointment_fab',
          onPressed: () => _openAppointmentForm(),
          backgroundColor: AppTheme.brandTeal,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.calendar_today),
          label: const Text('Request Appointment'),
        );

      case ClinicFeedFilter.all:
        // Show both buttons side by side when viewing all
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chat button
            if (!hasPendingChatRequest)
              FloatingActionButton.extended(
                heroTag: 'chat_fab',
                onPressed: () =>
                    _showNewChatRequestDialog(chatProvider, userProvider),
                backgroundColor: AppTheme.neutral800,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('New Chat'),
              )
            else
              FloatingActionButton.extended(
                heroTag: 'chat_fab',
                onPressed: null,
                backgroundColor: AppTheme.neutral500,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.hourglass_top),
                label: const Text('Chat Pending'),
              ),
            Gap(AppTheme.spacing2),
            // Appointment button
            FloatingActionButton.extended(
              heroTag: 'appointment_fab',
              onPressed: () => _openAppointmentForm(),
              backgroundColor: AppTheme.brandTeal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.calendar_today),
              label: const Text('Request Appointment'),
            ),
          ],
        );
    }
  }

  void _openAppointmentForm() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final appointmentProvider = Provider.of<AppointmentRequestProvider>(
      context,
      listen: false,
    );
    final currentUserId = userProvider.currentUser?.id;

    if (currentUserId != null) {
      final petsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('pets')
          .limit(1)
          .get();

      if (petsSnapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Add a pet before requesting an appointment'),
            action: SnackBarAction(
              label: 'Add Pet',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PetFormPage()),
                );
              },
            ),
          ),
        );
        return;
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: appointmentProvider),
          ],
          child: const AppointmentRequestForm(),
        ),
      ),
    );
  }

  String _getChatDisplayName(ChatRoom chatRoom, UserProvider userProvider) {
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

  Future<void> _refresh(
    ChatProvider chatProvider,
    AppointmentRequestProvider appointmentProvider,
    UserProvider userProvider,
  ) async {
    if (userProvider.isPetOwner) {
      final petOwnerId = userProvider.currentUser?.id;
      if (petOwnerId != null) {
        await chatProvider.initializeChatRooms(petOwnerId: petOwnerId);
        appointmentProvider.initializeForPetOwner(petOwnerId);
      }
    }
  }

  Future<void> _confirmCancelChatRequest(
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

  Future<void> _confirmCancelAppointment(
    AppointmentRequest request,
    AppointmentRequestProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: Text(
          'Are you sure you want to cancel your appointment request for ${request.petName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await provider.cancelRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Request cancelled'
                  : provider.error ?? 'Failed to cancel request',
            ),
            backgroundColor: success ? AppTheme.brandTeal : Colors.red,
          ),
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
}

/// Filter chip widget for the feed
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14.sp,
                color: isSelected ? AppTheme.primary : Colors.white,
              ),
              Gap(4.w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : Colors.white,
              ),
            ),
            if (count > 0) ...[
              Gap(4.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius2),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppTheme.primary : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
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
