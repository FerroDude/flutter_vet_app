import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../models/appointment_request_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/appointment_request_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../petOwners/chat_room_page.dart';

class AppointmentRequestsPage extends StatefulWidget {
  const AppointmentRequestsPage({super.key});

  @override
  State<AppointmentRequestsPage> createState() =>
      _AppointmentRequestsPageState();
}

class _AppointmentRequestsPageState extends State<AppointmentRequestsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final userProvider = context.read<UserProvider>();
      final clinicId = userProvider.connectedClinic?.id;
      if (clinicId != null) {
        context.read<AppointmentRequestProvider>().initializeForReceptionist(
          clinicId,
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Appointment Requests',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18.sp,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.brandTeal,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            tabs: [
              Tab(
                child: Consumer<AppointmentRequestProvider>(
                  builder: (context, provider, _) {
                    final count = provider.pendingCount;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Pending'),
                        if (count > 0) ...[
                          Gap(6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const Tab(text: 'Handled'),
            ],
          ),
        ),
        body: Consumer<AppointmentRequestProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.pendingRequests.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(provider),
                _buildHandledTab(provider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPendingTab(AppointmentRequestProvider provider) {
    if (provider.pendingRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'All Caught Up!',
        message: 'No pending appointment requests.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final clinicId = context.read<UserProvider>().connectedClinic?.id;
        if (clinicId != null) {
          provider.initializeForReceptionist(clinicId);
        }
      },
      child: ListView.builder(
        padding: EdgeInsets.all(AppTheme.spacing4),
        itemCount: provider.pendingRequests.length,
        itemBuilder: (context, index) {
          final request = provider.pendingRequests[index];
          return _buildRequestCard(request, provider);
        },
      ),
    );
  }

  Widget _buildHandledTab(AppointmentRequestProvider provider) {
    final handledRequests = provider.allRequests
        .where((r) => r.status != AppointmentRequestStatus.pending)
        .toList();

    if (handledRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No History',
        message: 'Handled requests will appear here.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppTheme.spacing4),
      itemCount: handledRequests.length,
      itemBuilder: (context, index) {
        final request = handledRequests[index];
        return _buildRequestCard(request, provider, showActions: false);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80.sp, color: Colors.white.withValues(alpha: 0.5)),
            Gap(AppTheme.spacing4),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap(AppTheme.spacing2),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    AppointmentRequest request,
    AppointmentRequestProvider provider, {
    bool showActions = true,
  }) {
    final dateFormat = DateFormat('MMM d');
    final dateRangeText =
        '${dateFormat.format(request.preferredDateStart)} - ${dateFormat.format(request.preferredDateEnd)}';
    final timeAgo = _getTimeAgo(request.createdAt);

    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacing3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
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
                // Pet owner avatar placeholder
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
                if (!request.isPending) _buildStatusBadge(request.status),
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
                      size: 16.sp,
                    ),
                    Gap(AppTheme.spacing2),
                    Text(
                      dateRangeText,
                      style: TextStyle(
                        color: AppTheme.neutral700,
                        fontSize: 14.sp,
                      ),
                    ),
                    Gap(AppTheme.spacing3),
                    Icon(
                      Icons.access_time,
                      color: AppTheme.neutral700,
                      size: 16.sp,
                    ),
                    Gap(AppTheme.spacing1),
                    Text(
                      request.timePreference.shortText,
                      style: TextStyle(
                        color: AppTheme.neutral700,
                        fontSize: 14.sp,
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
                        size: 16.sp,
                      ),
                      Gap(AppTheme.spacing2),
                      Expanded(
                        child: Text(
                          request.reason,
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Notes if any
                if (request.notes != null && request.notes!.isNotEmpty) ...[
                  Gap(AppTheme.spacing2),
                  Text(
                    'Notes: ${request.notes}',
                    style: TextStyle(
                      color: AppTheme.neutral700,
                      fontSize: 13.sp,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                // Response message for handled requests
                if (!request.isPending &&
                    request.responseMessage != null &&
                    request.responseMessage!.isNotEmpty) ...[
                  Gap(AppTheme.spacing3),
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
                          size: 16.sp,
                        ),
                        Gap(AppTheme.spacing2),
                        Expanded(
                          child: Text(
                            request.responseMessage!,
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action buttons for pending requests
                if (showActions && request.isPending) ...[
                  Gap(AppTheme.spacing3),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDenyDialog(request, provider),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacing2,
                            ),
                          ),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Deny'),
                        ),
                      ),
                      Gap(AppTheme.spacing2),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openChat(request),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacing2,
                            ),
                          ),
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('Chat'),
                        ),
                      ),
                      Gap(AppTheme.spacing2),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showConfirmDialog(request, provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandTeal,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacing2,
                            ),
                          ),
                          icon: const Icon(Icons.check, size: 18),
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
          fontSize: 11.sp,
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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
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

  Future<void> _openChat(AppointmentRequest request) async {
    final userProvider = context.read<UserProvider>();
    final chatProvider = context.read<ChatProvider>();

    final clinicId = userProvider.connectedClinic?.id;
    final staffId = userProvider.currentUser?.id;
    final staffName = userProvider.currentUser?.displayName ?? '';

    if (clinicId == null || staffId == null) return;

    // Create or find chat room with the pet owner
    final chatRoomId = await chatProvider.createOrFindOneOnOneChat(
      clinicId: clinicId,
      petOwnerId: request.petOwnerId,
      petOwnerName: request.petOwnerName,
      vetId: staffId,
      vetName: staffName,
      petIds: [request.petId],
      topic: 'Re: Appointment request for ${request.petName}',
    );

    if (chatRoomId != null && mounted) {
      // Link chat room to request
      final provider = context.read<AppointmentRequestProvider>();
      await provider.linkChatRoom(
        requestId: request.id,
        chatRoomId: chatRoomId,
      );

      // Navigate to chat
      final chatRoom = chatProvider.chatRooms.firstWhere(
        (r) => r.id == chatRoomId,
        orElse: () => chatProvider.chatRooms.first,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomPage(chatRoom: chatRoom),
          ),
        );
      }
    }
  }
}
