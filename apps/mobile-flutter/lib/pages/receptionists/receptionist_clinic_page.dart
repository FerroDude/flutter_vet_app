import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_models.dart';
import '../../models/appointment_request_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/appointment_request_provider.dart';
import '../../shared/widgets/pet_info_widget.dart';
import '../petOwners/chat_room_page.dart';
import '../petOwners/settings_page.dart';
import '../petOwners/profile_page.dart';

/// Filter options for the receptionist clinic feed
enum ReceptionistFeedFilter { all, chats, appointments }

/// A unified item type for the combined feed
abstract class ReceptionistFeedItem {
  DateTime get sortDate;
  String get id;
  bool get isPending;
}

class ChatFeedItem extends ReceptionistFeedItem {
  final ChatRoom chatRoom;
  ChatFeedItem(this.chatRoom);

  @override
  DateTime get sortDate =>
      chatRoom.lastMessage?.timestamp ?? chatRoom.updatedAt;

  @override
  String get id => 'chat_${chatRoom.id}';

  @override
  bool get isPending => chatRoom.status == ChatRoomStatus.pending;
}

class AppointmentFeedItem extends ReceptionistFeedItem {
  final AppointmentRequest request;
  AppointmentFeedItem(this.request);

  @override
  DateTime get sortDate => request.updatedAt;

  @override
  String get id => 'appt_${request.id}';

  @override
  bool get isPending => request.isPending;
}

/// Unified Clinic Communication page for receptionists
/// Combines chat requests, active chats, and appointment requests in a single feed
class ReceptionistClinicPage extends StatefulWidget {
  const ReceptionistClinicPage({super.key});

  @override
  State<ReceptionistClinicPage> createState() => _ReceptionistClinicPageState();
}

class _ReceptionistClinicPageState extends State<ReceptionistClinicPage> {
  String? _lastClinicId;
  ReceptionistFeedFilter _currentFilter = ReceptionistFeedFilter.all;

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

    final clinicId = userProvider.connectedClinic?.id;
    final userId = userProvider.currentUser?.id;
    if (clinicId != null && userId != null && clinicId != _lastClinicId) {
      _lastClinicId = clinicId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chatProvider.initializeChatRooms(clinicId: clinicId, vetId: userId);
        appointmentProvider.initializeForReceptionist(clinicId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ChatProvider, UserProvider, AppointmentRequestProvider>(
      builder: (context, chatProvider, userProvider, appointmentProvider, _) {
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
              'Communications',
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
    // Check loading state
    final isLoading = chatProvider.isLoading || appointmentProvider.isLoading;
    final hasData =
        chatProvider.chatRooms.isNotEmpty ||
        chatProvider.pendingRequests.isNotEmpty ||
        appointmentProvider.pendingRequests.isNotEmpty ||
        appointmentProvider.allRequests.isNotEmpty;

    if (isLoading && !hasData) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
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
    // Calculate counts for badges
    final pendingChats = chatProvider.pendingRequests.length;
    final unreadChats = chatProvider.totalUnreadCount;
    final totalChatBadge = pendingChats + unreadChats;
    final pendingAppointments = appointmentProvider.pendingCount;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing4,
        vertical: AppTheme.spacing2,
      ),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            filter: ReceptionistFeedFilter.all,
            badgeCount: totalChatBadge + pendingAppointments,
          ),
          Gap(AppTheme.spacing2),
          _buildFilterChip(
            label: 'Chats',
            filter: ReceptionistFeedFilter.chats,
            badgeCount: totalChatBadge,
          ),
          Gap(AppTheme.spacing2),
          _buildFilterChip(
            label: 'Appointments',
            filter: ReceptionistFeedFilter.appointments,
            badgeCount: pendingAppointments,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required ReceptionistFeedFilter filter,
    int badgeCount = 0,
  }) {
    final isSelected = _currentFilter == filter;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFilter = filter;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacing3,
          vertical: AppTheme.spacing2,
        ),
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
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : Colors.white,
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (badgeCount > 0) ...[
              Gap(6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.primary,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedList(
    ChatProvider chatProvider,
    UserProvider userProvider,
    AppointmentRequestProvider appointmentProvider,
  ) {
    // Build combined feed items
    final List<ReceptionistFeedItem> allItems = [];

    // Add pending chat requests first (always important)
    if (_currentFilter == ReceptionistFeedFilter.all ||
        _currentFilter == ReceptionistFeedFilter.chats) {
      for (final request in chatProvider.pendingRequests) {
        allItems.add(ChatFeedItem(request));
      }
      // Add active chats
      for (final chatRoom in chatProvider.chatRooms) {
        allItems.add(ChatFeedItem(chatRoom));
      }
    }

    // Add appointment requests
    if (_currentFilter == ReceptionistFeedFilter.all ||
        _currentFilter == ReceptionistFeedFilter.appointments) {
      for (final request in appointmentProvider.allRequests) {
        allItems.add(AppointmentFeedItem(request));
      }
    }

    // Apply search filter
    List<ReceptionistFeedItem> filteredItems = allItems;
    if (_searchQuery.isNotEmpty) {
      filteredItems = allItems.where((item) {
        if (item is ChatFeedItem) {
          final name = item.chatRoom.petOwnerName.toLowerCase();
          final topic = (item.chatRoom.topic ?? '').toLowerCase();
          final lastMsg = (item.chatRoom.lastMessage?.content ?? '')
              .toLowerCase();
          return name.contains(_searchQuery) ||
              topic.contains(_searchQuery) ||
              lastMsg.contains(_searchQuery);
        } else if (item is AppointmentFeedItem) {
          final name = item.request.petOwnerName.toLowerCase();
          final petName = item.request.petName.toLowerCase();
          final reason = item.request.reason.toLowerCase();
          return name.contains(_searchQuery) ||
              petName.contains(_searchQuery) ||
              reason.contains(_searchQuery);
        }
        return false;
      }).toList();
    }

    // Sort: pending items first, then by date (most recent first)
    filteredItems.sort((a, b) {
      // Pending items always come first
      if (a.isPending && !b.isPending) return -1;
      if (!a.isPending && b.isPending) return 1;
      // Then sort by date (most recent first)
      return b.sortDate.compareTo(a.sortDate);
    });

    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppTheme.spacing4),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        if (item is ChatFeedItem) {
          return Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacing3),
            child: _buildChatCard(item.chatRoom, userProvider, chatProvider),
          );
        } else if (item is AppointmentFeedItem) {
          return Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacing3),
            child: _buildAppointmentCard(
              item.request,
              userProvider,
              appointmentProvider,
              chatProvider,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_currentFilter) {
      case ReceptionistFeedFilter.chats:
        icon = Icons.chat_bubble_outline;
        message = _searchQuery.isNotEmpty
            ? 'No chats found for "$_searchQuery"'
            : 'No chat conversations yet';
        break;
      case ReceptionistFeedFilter.appointments:
        icon = Icons.calendar_today;
        message = _searchQuery.isNotEmpty
            ? 'No appointments found for "$_searchQuery"'
            : 'No appointment requests yet';
        break;
      case ReceptionistFeedFilter.all:
        icon = Icons.inbox;
        message = _searchQuery.isNotEmpty
            ? 'No results found for "$_searchQuery"'
            : 'No communications yet';
        break;
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64.sp, color: Colors.white.withValues(alpha: 0.5)),
            Gap(AppTheme.spacing4),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16.sp,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              Gap(AppTheme.spacing3),
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

  Widget _buildChatCard(
    ChatRoom chatRoom,
    UserProvider userProvider,
    ChatProvider chatProvider,
  ) {
    final isPending = chatRoom.status == ChatRoomStatus.pending;
    final currentUserId = userProvider.currentUser?.id ?? '';
    final unreadCount = chatRoom.unreadCounts[currentUserId] ?? 0;
    final hasUnread = unreadCount > 0;

    final lastMessage = chatRoom.lastMessage?.content ?? 'No messages yet';
    final timeString = _formatChatTime(
      chatRoom.lastMessage?.timestamp ?? chatRoom.updatedAt,
    );

    return InkWell(
      onTap: isPending
          ? null
          : () {
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
          border: isPending
              ? Border.all(color: Colors.orange, width: 2)
              : hasUnread
              ? Border(
                  left: BorderSide(color: AppTheme.primary, width: 4.w),
                )
              : null,
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Container(
              padding: EdgeInsets.all(AppTheme.spacing3),
              decoration: BoxDecoration(
                color: isPending
                    ? Colors.orange.withValues(alpha: 0.1)
                    : AppTheme.brandTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radius4),
                  topRight: Radius.circular(AppTheme.radius4),
                ),
              ),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 20.r,
                    backgroundColor: AppTheme.brandTeal.withValues(alpha: 0.2),
                    child: Text(
                      chatRoom.petOwnerName.isNotEmpty
                          ? chatRoom.petOwnerName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: AppTheme.brandTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                  Gap(AppTheme.spacing3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chatRoom.petOwnerName,
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        if (chatRoom.topic != null)
                          Text(
                            chatRoom.topic!,
                            style: TextStyle(
                              color: AppTheme.neutral700,
                              fontSize: 12.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (isPending)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing2,
                        vertical: AppTheme.spacing1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(AppTheme.radius2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat, color: Colors.white, size: 12.sp),
                          Gap(4.w),
                          Text(
                            'NEW REQUEST',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (hasUnread)
                    Container(
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
                    )
                  else
                    Text(
                      timeString,
                      style: TextStyle(
                        color: AppTheme.neutral700,
                        fontSize: 11.sp,
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(AppTheme.spacing3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pet info
                  if (chatRoom.petIds.isNotEmpty) ...[
                    PetInfoWidget(
                      petOwnerId: chatRoom.petOwnerId,
                      petId: chatRoom.petIds.first,
                      style: PetInfoStyle.chip,
                    ),
                    Gap(AppTheme.spacing2),
                  ],

                  // Last message or description
                  if (isPending && chatRoom.requestDescription != null)
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacing2),
                      decoration: BoxDecoration(
                        color: AppTheme.neutral100,
                        borderRadius: BorderRadius.circular(AppTheme.radius2),
                      ),
                      child: Text(
                        chatRoom.requestDescription!,
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13.sp,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Text(
                      lastMessage,
                      style: TextStyle(
                        color: AppTheme.neutral700,
                        fontSize: 13.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Accept button for pending requests
                  if (isPending) ...[
                    Gap(AppTheme.spacing3),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptChatRequest(
                          chatRoom,
                          chatProvider,
                          userProvider,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandTeal,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: AppTheme.spacing2,
                          ),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Accept Chat Request'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(
    AppointmentRequest request,
    UserProvider userProvider,
    AppointmentRequestProvider appointmentProvider,
    ChatProvider chatProvider,
  ) {
    final dateFormat = DateFormat('MMM d');
    final dateRangeText =
        '${dateFormat.format(request.preferredDateStart)} - ${dateFormat.format(request.preferredDateEnd)}';
    final timeAgo = _getTimeAgo(request.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        border: request.isPending
            ? Border.all(color: AppTheme.brandTeal, width: 2)
            : null,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(AppTheme.spacing3),
            decoration: BoxDecoration(
              color: request.isPending
                  ? AppTheme.brandTeal.withValues(alpha: 0.1)
                  : _getStatusColor(request.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radius4),
                topRight: Radius.circular(AppTheme.radius4),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: AppTheme.brandTeal.withValues(alpha: 0.2),
                  child: Text(
                    request.petOwnerName.isNotEmpty
                        ? request.petOwnerName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: AppTheme.brandTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                Gap(AppTheme.spacing3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.petOwnerName,
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: AppTheme.neutral700,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (request.isPending)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing2,
                      vertical: AppTheme.spacing1,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brandTeal,
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 12.sp,
                        ),
                        Gap(4.w),
                        Text(
                          'APPOINTMENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _buildStatusBadge(request.status),
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(AppTheme.spacing3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pet name
                Row(
                  children: [
                    Icon(Icons.pets, color: AppTheme.brandTeal, size: 18.sp),
                    Gap(AppTheme.spacing2),
                    Text(
                      request.petName,
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (request.petSpecies != null &&
                        request.petSpecies!.isNotEmpty) ...[
                      Gap(AppTheme.spacing2),
                      Text(
                        '(${request.petSpecies})',
                        style: TextStyle(
                          color: AppTheme.neutral700,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ],
                ),
                Gap(AppTheme.spacing2),

                // Date & Time preferences
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
                    Gap(AppTheme.spacing3),
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
                Gap(AppTheme.spacing2),

                // Reason
                Container(
                  padding: EdgeInsets.all(AppTheme.spacing2),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral100,
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.description,
                        color: AppTheme.neutral700,
                        size: 14.sp,
                      ),
                      Gap(AppTheme.spacing2),
                      Expanded(
                        child: Text(
                          request.reason,
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13.sp,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Response message for handled requests
                if (!request.isPending &&
                    request.responseMessage != null &&
                    request.responseMessage!.isNotEmpty) ...[
                  Gap(AppTheme.spacing2),
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacing2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        request.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.message,
                          color: _getStatusColor(request.status),
                          size: 14.sp,
                        ),
                        Gap(AppTheme.spacing2),
                        Expanded(
                          child: Text(
                            request.responseMessage!,
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action buttons for pending requests
                if (request.isPending) ...[
                  Gap(AppTheme.spacing3),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showDenyDialog(request, appointmentProvider),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacing2,
                            ),
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Deny'),
                        ),
                      ),
                      Gap(AppTheme.spacing2),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openChat(
                            request,
                            userProvider,
                            chatProvider,
                            appointmentProvider,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacing2,
                            ),
                          ),
                          icon: const Icon(Icons.chat, size: 16),
                          label: const Text('Chat'),
                        ),
                      ),
                      Gap(AppTheme.spacing2),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showConfirmDialog(request, appointmentProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandTeal,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacing2,
                            ),
                          ),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Confirm'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AppointmentRequestStatus status) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing2,
        vertical: AppTheme.spacing1,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(AppTheme.radius2),
      ),
      child: Text(
        status.displayText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
        ),
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

  String _formatChatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return DateFormat('h:mm a').format(timestamp);
    if (diff.inDays < 7) return DateFormat('EEE').format(timestamp);
    return DateFormat('MMM d').format(timestamp);
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }

  Future<void> _refresh(
    ChatProvider chatProvider,
    AppointmentRequestProvider appointmentProvider,
    UserProvider userProvider,
  ) async {
    final clinicId = userProvider.connectedClinic?.id;
    final userId = userProvider.currentUser?.id;
    if (clinicId != null && userId != null) {
      await Future.wait([
        chatProvider.initializeChatRooms(clinicId: clinicId, vetId: userId),
        Future(() => appointmentProvider.initializeForReceptionist(clinicId)),
      ]);
    }
  }

  Future<void> _acceptChatRequest(
    ChatRoom chatRoom,
    ChatProvider chatProvider,
    UserProvider userProvider,
  ) async {
    final userId = userProvider.currentUser?.id;
    final userName = userProvider.currentUser?.displayName ?? 'Receptionist';
    if (userId == null) return;

    final success = await chatProvider.acceptChatRequest(
      chatRoomId: chatRoom.id,
      vetId: userId,
      vetName: userName,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat request accepted'),
          backgroundColor: AppTheme.brandTeal,
        ),
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

  Future<void> _showConfirmDialog(
    AppointmentRequest request,
    AppointmentRequestProvider provider,
  ) async {
    final messageController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm appointment request for ${request.petName}?'),
            Gap(AppTheme.spacing3),
            Text(
              'Optional message to pet owner:',
              style: TextStyle(fontSize: 12.sp, color: AppTheme.neutral700),
            ),
            Gap(AppTheme.spacing1),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                hintText: 'e.g., Appointment scheduled for Monday 10am',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandTeal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final userProvider = context.read<UserProvider>();
      final success = await provider.confirmRequest(
        requestId: request.id,
        handledBy: userProvider.currentUser?.id ?? '',
        handledByName: userProvider.currentUser?.displayName ?? '',
        message: messageController.text.trim().isNotEmpty
            ? messageController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Request confirmed'
                  : provider.error ?? 'Failed to confirm',
            ),
            backgroundColor: success ? AppTheme.brandTeal : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDenyDialog(
    AppointmentRequest request,
    AppointmentRequestProvider provider,
  ) async {
    final messageController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deny appointment request for ${request.petName}?'),
            Gap(AppTheme.spacing3),
            Text(
              'Please provide a reason:',
              style: TextStyle(fontSize: 12.sp, color: AppTheme.neutral700),
            ),
            Gap(AppTheme.spacing1),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                hintText: 'e.g., No availability this week, please try again',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final userProvider = context.read<UserProvider>();
      final success = await provider.denyRequest(
        requestId: request.id,
        handledBy: userProvider.currentUser?.id ?? '',
        handledByName: userProvider.currentUser?.displayName ?? '',
        message: messageController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Request denied' : provider.error ?? 'Failed to deny',
            ),
            backgroundColor: success ? AppTheme.brandTeal : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openChat(
    AppointmentRequest request,
    UserProvider userProvider,
    ChatProvider chatProvider,
    AppointmentRequestProvider appointmentProvider,
  ) async {
    final clinicId = userProvider.connectedClinic?.id;
    final staffId = userProvider.currentUser?.id;
    final staffName = userProvider.currentUser?.displayName ?? '';

    if (clinicId == null || staffId == null) return;

    // Create or find chat room with the pet owner
    final chatRoomId = await chatProvider.startChatWithPatient(
      clinicId: clinicId,
      staffId: staffId,
      staffName: staffName,
      staffRole: 'receptionist',
      petOwnerId: request.petOwnerId,
      petOwnerName: request.petOwnerName,
      petIds: [request.petId],
      topic: 'Re: Appointment request for ${request.petName}',
    );

    if (chatRoomId != null && mounted) {
      // Link chat room to request
      await appointmentProvider.linkChatRoom(
        requestId: request.id,
        chatRoomId: chatRoomId,
      );

      // Refresh chat rooms to get the updated list
      await chatProvider.initializeChatRooms(
        clinicId: clinicId,
        vetId: staffId,
      );

      // Find the chat room
      final chatRoom = chatProvider.chatRooms.firstWhere(
        (r) => r.id == chatRoomId,
        orElse: () => chatProvider.chatRooms.first,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider.value(
              value: chatProvider,
              child: ChatRoomPage(chatRoom: chatRoom),
            ),
          ),
        );
      }
    }
  }
}
