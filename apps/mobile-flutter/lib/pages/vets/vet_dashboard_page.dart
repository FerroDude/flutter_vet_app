import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/vet_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/symptom_models.dart';
import '../../theme/app_theme.dart';
import '../petOwners/profile_page.dart';
import '../petOwners/settings_page.dart';
import 'patient_detail_page.dart';
import 'vet_home_page.dart';

class VetDashboardPage extends StatefulWidget {
  const VetDashboardPage({super.key});

  @override
  State<VetDashboardPage> createState() => _VetDashboardPageState();
}

class _VetDashboardPageState extends State<VetDashboardPage> {
  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  void _initializeDashboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      final vetProvider = context.read<VetProvider>();
      final clinicId = userProvider.connectedClinic?.id;

      if (clinicId != null) {
        vetProvider.initialize(clinicId);
      }
    });
  }

  void _navigateToChat() {
    final homeState = context.findAncestorStateOfType<VetHomePageState>();
    homeState?.switchToChat();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, VetProvider>(
      builder: (context, userProvider, vetProvider, _) {
        final clinic = userProvider.connectedClinic;
        final vetName = userProvider.currentUser?.displayName.split(' ').first ?? 'there';

        return Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  final clinicId = userProvider.connectedClinic?.id;
                  if (clinicId != null) {
                    vetProvider.initialize(clinicId);
                  }
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // Header with greeting and clinic
                    SliverToBoxAdapter(child: _buildHeader(context, vetName, clinic, userProvider)),
                    
                    // Needs Attention Section
                    SliverToBoxAdapter(child: _buildNeedsAttentionSection(context)),
                    
                    // Overview Stats Section
                    SliverToBoxAdapter(child: _buildOverviewSection(vetProvider)),
                    
                    // Recent Activity Section
                    SliverToBoxAdapter(child: _buildRecentActivitySection(vetProvider)),
                    
                    // Bottom padding
                    SliverToBoxAdapter(child: Gap(AppTheme.spacing8)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, String vetName, dynamic clinic, UserProvider userProvider) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Gap(4.h),
                Text(
                  'Dr. $vetName',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                // Clinic name with switch option
                if (clinic != null) ...[
                  Gap(6.h),
                  InkWell(
                    onTap: () {
                      // TODO: Show clinic switcher when multi-clinic support is added
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Multi-clinic switching coming soon!'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.h),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_hospital_outlined,
                            size: 14.sp,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          Gap(6.w),
                          Text(
                            clinic.name,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          Gap(4.w),
                          Icon(
                            Icons.swap_horiz,
                            size: 14.sp,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, size: 24.sp, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsPage(injectedUserProvider: userProvider),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person_outline, size: 24.sp, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfilePage(injectedUserProvider: userProvider),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Builds the "Needs Attention" section with separate action cards
  Widget _buildNeedsAttentionSection(BuildContext context) {
    return Consumer2<ChatProvider, VetProvider>(
      builder: (context, chatProvider, vetProvider, child) {
        final unreadCount = chatProvider.totalUnreadCount;
        final pendingCount = chatProvider.pendingRequests.length;
        final symptomCount = vetProvider.recentSymptomCount;
        final totalCount = unreadCount + pendingCount + symptomCount;
        final hasNotifications = totalCount > 0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Icon(
                    hasNotifications ? Icons.notifications_active : Icons.notifications_none,
                    color: Colors.white,
                    size: 18.sp,
                  ),
                  Gap(AppTheme.spacing2),
                  Text(
                    'Needs Attention',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (hasNotifications) ...[
                    Gap(AppTheme.spacing2),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$totalCount',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Gap(AppTheme.spacing3),
              
              // Action cards or empty state
              if (!hasNotifications)
                _buildAllCaughtUpCard()
              else
                Column(
                  children: [
                    // Pending Requests Card (higher priority - orange)
                    if (pendingCount > 0) ...[
                      _ActionCard(
                        icon: Icons.pending_actions,
                        iconBackgroundColor: Colors.orange,
                        title: '$pendingCount pending chat request${pendingCount != 1 ? 's' : ''}',
                        subtitle: 'Pet owners are waiting for your response',
                        badgeCount: pendingCount,
                        badgeColor: Colors.orange,
                        onTap: _navigateToChat,
                      ),
                      Gap(AppTheme.spacing2),
                    ],
                    
                    // Unread Messages Card (blue)
                    if (unreadCount > 0) ...[
                      _ActionCard(
                        icon: Icons.chat_bubble,
                        iconBackgroundColor: AppTheme.brandBlueLight,
                        title: '$unreadCount unread message${unreadCount != 1 ? 's' : ''}',
                        subtitle: 'Tap to view your conversations',
                        badgeCount: unreadCount,
                        badgeColor: AppTheme.brandBlueLight,
                        onTap: _navigateToChat,
                      ),
                      Gap(AppTheme.spacing2),
                    ],
                    
                    // New Symptoms Card (red/warning)
                    if (symptomCount > 0)
                      _ActionCard(
                        icon: Icons.monitor_heart,
                        iconBackgroundColor: Colors.redAccent,
                        title: '$symptomCount new symptom${symptomCount != 1 ? 's' : ''} logged',
                        subtitle: 'Pet owners reported symptoms in the last 24h',
                        badgeCount: symptomCount,
                        badgeColor: Colors.redAccent,
                        onTap: () => _showRecentSymptoms(context, vetProvider),
                      ),
                  ],
                ),
              
              Gap(AppTheme.spacing4),
            ],
          ),
        );
      },
    );
  }

  /// Shows a bottom sheet with recent symptoms and marks them as seen
  void _showRecentSymptoms(BuildContext context, VetProvider vetProvider) {
    // Mark symptoms as seen when opening the sheet
    vetProvider.markSymptomsAsSeen();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecentSymptomsSheet(symptoms: vetProvider.recentSymptoms),
    );
  }

  Widget _buildAllCaughtUpCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: AppTheme.brandTeal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radius3),
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: AppTheme.brandTeal,
              size: 24.sp,
            ),
          ),
          Gap(AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're all caught up!",
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Gap(2.h),
                Text(
                  'No pending requests or unread messages',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(VetProvider vetProvider) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dashboard_outlined,
                size: 18.sp,
                color: Colors.white,
              ),
              Gap(AppTheme.spacing2),
              Text(
                'Overview',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Gap(AppTheme.spacing3),
          // Two stat cards side by side: Chats and Symptoms
          Row(
            children: [
              Expanded(
                child: Consumer<ChatProvider>(
                  builder: (context, chatProvider, _) {
                    final activeChats = chatProvider.chatRooms.length;
                    final pendingRequests = chatProvider.pendingRequests.length;

                    return _StatCard(
                      icon: Icons.chat_bubble_outline,
                      label: 'Active Chats',
                      value: '$activeChats',
                      subtitle: pendingRequests > 0 ? '$pendingRequests pending' : null,
                      color: AppTheme.brandBlueLight,
                    );
                  },
                ),
              ),
              Gap(AppTheme.spacing3),
              Expanded(
                child: _buildCompactSymptomsCard(vetProvider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSymptomsCard(VetProvider vetProvider) {
    final symptomsThisWeek = vetProvider.symptomsThisWeek;
    final trend = vetProvider.symptomTrend;
    
    String? subtitle;
    if (trend > 0) {
      subtitle = '↑ from last week';
    } else if (trend < 0) {
      subtitle = '↓ from last week';
    }

    return _StatCard(
      icon: Icons.monitor_heart_outlined,
      label: 'Symptoms',
      value: '$symptomsThisWeek',
      subtitle: subtitle,
      color: Colors.redAccent,
    );
  }

  Widget _buildRecentActivitySection(VetProvider vetProvider) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        // Build unified activity feed
        final activities = _buildActivityFeed(vetProvider, chatProvider);
        
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timeline,
                    size: 18.sp,
                    color: Colors.white,
                  ),
                  Gap(AppTheme.spacing2),
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Gap(AppTheme.spacing3),
              if (vetProvider.isLoading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacing4),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              else if (activities.isEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radius3),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  padding: EdgeInsets.all(AppTheme.spacing5),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48.sp,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      Gap(AppTheme.spacing2),
                      Text(
                        'No recent activity',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      Gap(AppTheme.spacing1),
                      Text(
                        'Activity will appear here as patients send messages and log symptoms',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...activities.take(8).map(
                  (activity) => Padding(
                    padding: EdgeInsets.only(bottom: AppTheme.spacing2),
                    child: _ActivityCard(
                      activity: activity,
                      onTap: () => _handleActivityTap(activity),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Build a unified activity feed from multiple sources
  List<ActivityItem> _buildActivityFeed(VetProvider vetProvider, ChatProvider chatProvider) {
    final List<ActivityItem> activities = [];
    
    // 1. Add recent messages from chat rooms
    for (final room in chatProvider.chatRooms) {
      if (room.lastMessage != null) {
        final lastMsg = room.lastMessage!;
        // Only include messages from the last 48 hours
        final cutoff = DateTime.now().subtract(const Duration(hours: 48));
        if (lastMsg.timestamp.isAfter(cutoff)) {
          activities.add(ActivityItem(
            type: ActivityType.newMessage,
            title: room.petOwnerName,
            subtitle: lastMsg.content.length > 50 
                ? '${lastMsg.content.substring(0, 50)}...'
                : lastMsg.content,
            timestamp: lastMsg.timestamp,
            avatarText: room.petOwnerName.isNotEmpty 
                ? room.petOwnerName[0].toUpperCase() 
                : 'U',
            metadata: {'chatRoom': room},
          ));
        }
      }
    }
    
    // 2. Add recent symptoms
    for (final enriched in vetProvider.recentSymptoms.take(10)) {
      activities.add(ActivityItem(
        type: ActivityType.newSymptom,
        title: '${enriched.petName} - ${getSymptomLabel(enriched.symptom.type)}',
        subtitle: enriched.ownerName,
        timestamp: enriched.symptom.timestamp,
        avatarText: enriched.petName.isNotEmpty 
            ? enriched.petName[0].toUpperCase() 
            : 'P',
        metadata: {'symptom': enriched},
      ));
    }
    
    // 3. Add pending chat requests
    for (final request in chatProvider.pendingRequests) {
      activities.add(ActivityItem(
        type: ActivityType.chatRequest,
        title: 'Chat request from ${request.petOwnerName}',
        subtitle: request.topic ?? request.requestDescription ?? 'Wants to connect',
        timestamp: request.createdAt,
        avatarText: request.petOwnerName.isNotEmpty 
            ? request.petOwnerName[0].toUpperCase() 
            : 'U',
        metadata: {'chatRoom': request},
      ));
    }
    
    // Sort by timestamp (most recent first)
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return activities;
  }

  void _handleActivityTap(ActivityItem activity) {
    switch (activity.type) {
      case ActivityType.newMessage:
      case ActivityType.chatRequest:
        _navigateToChat();
        break;
      case ActivityType.newSymptom:
        final enrichedSymptom = activity.metadata?['symptom'] as EnrichedSymptom?;
        if (enrichedSymptom != null) {
          _showPetSymptoms(context, enrichedSymptom);
        }
        break;
      case ActivityType.newPatient:
        final homeState = context.findAncestorStateOfType<VetHomePageState>();
        homeState?.switchToPatients();
        break;
    }
  }

  void _showPetSymptoms(BuildContext context, EnrichedSymptom clickedSymptom) {
    final vetProvider = context.read<VetProvider>();
    final userProvider = context.read<UserProvider>();
    
    // Filter symptoms for this specific pet
    final petSymptoms = vetProvider.recentSymptoms
        .where((s) => 
            s.symptom.petId == clickedSymptom.symptom.petId &&
            s.symptom.ownerId == clickedSymptom.symptom.ownerId)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PetSymptomsSheet(
        petName: clickedSymptom.petName,
        ownerName: clickedSymptom.ownerName,
        ownerId: clickedSymptom.symptom.ownerId,
        petId: clickedSymptom.symptom.petId,
        symptoms: petSymptoms,
        userProvider: userProvider,
        vetProvider: vetProvider,
      ),
    );
  }
}

/// Tappable action card for the "Needs Attention" section
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBackgroundColor;
  final String title;
  final String subtitle;
  final int badgeCount;
  final Color badgeColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconBackgroundColor,
    required this.title,
    required this.subtitle,
    required this.badgeCount,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        child: Container(
          padding: EdgeInsets.all(AppTheme.spacing3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius4),
            boxShadow: [
              BoxShadow(
                color: iconBackgroundColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container with colored background
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: iconBackgroundColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radius3),
                ),
                child: Icon(
                  icon,
                  color: iconBackgroundColor,
                  size: 22.sp,
                ),
              ),
              Gap(AppTheme.spacing3),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.neutral700,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge and arrow
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(AppTheme.radius3),
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Gap(AppTheme.spacing2),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14.sp,
                    color: AppTheme.neutral700,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stat card for the overview section
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: EdgeInsets.all(AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius2),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          Gap(AppTheme.spacing3),
          Text(
            value,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          Gap(AppTheme.spacing1),
          Text(
            label,
            style: TextStyle(fontSize: 13.sp, color: AppTheme.neutral700),
          ),
          if (subtitle != null) ...[
            Gap(AppTheme.spacing1),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11.sp,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Activity card for the unified activity feed
class _ActivityCard extends StatelessWidget {
  final ActivityItem activity;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.activity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getActivityColor();
    final icon = _getActivityIcon();
    final timeAgo = _formatTimeAgo(activity.timestamp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        child: Container(
          padding: EdgeInsets.all(AppTheme.spacing3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius3),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity type indicator
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius2),
                ),
                child: activity.avatarText != null
                    ? Center(
                        child: Text(
                          activity.avatarText!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      )
                    : Icon(icon, color: color, size: 18.sp),
              ),
              Gap(AppTheme.spacing3),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Activity type icon
                        Icon(icon, color: color, size: 14.sp),
                        Gap(6.w),
                        Expanded(
                          child: Text(
                            activity.title,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Gap(AppTheme.spacing2),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppTheme.neutral700,
                          ),
                        ),
                      ],
                    ),
                    Gap(4.h),
                    Text(
                      activity.subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.neutral700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Gap(AppTheme.spacing2),
              Icon(
                Icons.arrow_forward_ios,
                size: 12.sp,
                color: AppTheme.neutral700.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getActivityColor() {
    switch (activity.type) {
      case ActivityType.newMessage:
        return AppTheme.brandBlueLight;
      case ActivityType.newSymptom:
        return Colors.redAccent;
      case ActivityType.newPatient:
        return AppTheme.brandTeal;
      case ActivityType.chatRequest:
        return Colors.orange;
    }
  }

  IconData _getActivityIcon() {
    switch (activity.type) {
      case ActivityType.newMessage:
        return Icons.chat_bubble_outline;
      case ActivityType.newSymptom:
        return Icons.monitor_heart;
      case ActivityType.newPatient:
        return Icons.person_add_outlined;
      case ActivityType.chatRequest:
        return Icons.pending_actions;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) {
      return 'now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}

/// Bottom sheet showing recent symptoms from all clinic patients
class _RecentSymptomsSheet extends StatelessWidget {
  final List<EnrichedSymptom> symptoms;

  const _RecentSymptomsSheet({required this.symptoms});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: AppTheme.spacing3),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppTheme.neutral700.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.spacing2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radius3),
                  ),
                  child: Icon(
                    Icons.monitor_heart,
                    color: Colors.redAccent,
                    size: 20.sp,
                  ),
                ),
                Gap(AppTheme.spacing3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Symptoms',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      Text(
                        'Logged by pet owners in the last 48 hours',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.neutral700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.neutral700),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.neutral700.withValues(alpha: 0.1)),
          // Symptoms list
          Flexible(
            child: symptoms.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(AppTheme.spacing6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48.sp,
                          color: AppTheme.brandTeal,
                        ),
                        Gap(AppTheme.spacing3),
                        Text(
                          'No symptoms reported',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primary,
                          ),
                        ),
                        Gap(AppTheme.spacing1),
                        Text(
                          'Great news! No pet owners have logged symptoms recently.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppTheme.neutral700,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.all(AppTheme.spacing4),
                    itemCount: symptoms.length,
                    separatorBuilder: (_, __) => Gap(AppTheme.spacing2),
                    itemBuilder: (context, index) {
                      final enriched = symptoms[index];
                      return _SymptomCard(enriched: enriched);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Card displaying a single symptom in the recent symptoms sheet
class _SymptomCard extends StatelessWidget {
  final EnrichedSymptom enriched;

  const _SymptomCard({required this.enriched});

  @override
  Widget build(BuildContext context) {
    final symptom = enriched.symptom;
    final timeAgo = _formatTimeAgo(symptom.timestamp);
    
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        border: Border.all(
          color: _getSymptomColor(symptom.type).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: _getSymptomColor(symptom.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius2),
            ),
            child: Icon(
              _getSymptomIcon(symptom.type),
              color: _getSymptomColor(symptom.type),
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
                    Expanded(
                      child: Text(
                        getSymptomLabel(symptom.type),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppTheme.neutral700,
                      ),
                    ),
                  ],
                ),
                Gap(4.h),
                Row(
                  children: [
                    Icon(Icons.pets, size: 12.sp, color: AppTheme.brandTeal),
                    Gap(4.w),
                    Text(
                      enriched.petName,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.brandTeal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Gap(AppTheme.spacing2),
                    Icon(Icons.person_outline, size: 12.sp, color: AppTheme.neutral700),
                    Gap(4.w),
                    Expanded(
                      child: Text(
                        enriched.ownerName,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.neutral700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (symptom.note != null && symptom.note!.isNotEmpty) ...[
                  Gap(AppTheme.spacing2),
                  Text(
                    symptom.note!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  IconData _getSymptomIcon(SymptomType type) {
    switch (type) {
      case SymptomType.vomiting:
        return Icons.sick;
      case SymptomType.diarrhea:
        return Icons.report_problem;
      case SymptomType.cough:
        return Icons.air;
      case SymptomType.sneezing:
        return Icons.masks;
      case SymptomType.choking:
        return Icons.warning;
      case SymptomType.seizure:
        return Icons.emergency;
      case SymptomType.disorientation:
        return Icons.psychology;
      case SymptomType.circling:
        return Icons.rotate_right;
      case SymptomType.restlessness:
        return Icons.run_circle;
      case SymptomType.limping:
        return Icons.accessible;
      case SymptomType.jointDiscomfort:
        return Icons.healing;
      case SymptomType.itching:
        return Icons.pets;
      case SymptomType.ocularDischarge:
        return Icons.visibility;
      case SymptomType.vaginalDischarge:
        return Icons.female;
      case SymptomType.estrus:
        return Icons.favorite;
      case SymptomType.other:
        return Icons.monitor_heart;
    }
  }

  Color _getSymptomColor(SymptomType type) {
    switch (type) {
      case SymptomType.vomiting:
      case SymptomType.diarrhea:
        return Colors.red;
      case SymptomType.choking:
      case SymptomType.seizure:
        return Colors.red.shade700;
      case SymptomType.cough:
      case SymptomType.sneezing:
        return Colors.blue;
      case SymptomType.disorientation:
      case SymptomType.circling:
      case SymptomType.restlessness:
        return Colors.orange;
      case SymptomType.limping:
      case SymptomType.jointDiscomfort:
        return Colors.purple;
      case SymptomType.itching:
      case SymptomType.ocularDischarge:
        return Colors.pink;
      case SymptomType.vaginalDischarge:
      case SymptomType.estrus:
        return Colors.teal;
      case SymptomType.other:
        return Colors.grey;
    }
  }
}

/// Bottom sheet showing symptoms for a specific pet with navigation to patient page
class _PetSymptomsSheet extends StatelessWidget {
  final String petName;
  final String ownerName;
  final String ownerId;
  final String petId;
  final List<EnrichedSymptom> symptoms;
  final UserProvider userProvider;
  final VetProvider vetProvider;

  const _PetSymptomsSheet({
    required this.petName,
    required this.ownerName,
    required this.ownerId,
    required this.petId,
    required this.symptoms,
    required this.userProvider,
    required this.vetProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: AppTheme.spacing3),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppTheme.neutral700.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header with pet info
          Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: AppTheme.brandTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radius3),
                  ),
                  child: Icon(
                    Icons.pets,
                    color: AppTheme.brandTeal,
                    size: 24.sp,
                  ),
                ),
                Gap(AppTheme.spacing3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        petName,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      Gap(2.h),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14.sp,
                            color: AppTheme.neutral700,
                          ),
                          Gap(4.w),
                          Text(
                            ownerName,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppTheme.neutral700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.neutral700),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.neutral700.withValues(alpha: 0.1)),
          // Symptoms list
          Flexible(
            child: symptoms.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(AppTheme.spacing6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48.sp,
                          color: AppTheme.brandTeal,
                        ),
                        Gap(AppTheme.spacing3),
                        Text(
                          'No recent symptoms',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.all(AppTheme.spacing4),
                    itemCount: symptoms.length,
                    separatorBuilder: (_, __) => Gap(AppTheme.spacing2),
                    itemBuilder: (context, index) {
                      final enriched = symptoms[index];
                      return _PetSymptomCard(enriched: enriched);
                    },
                  ),
          ),
          // Navigation button
          Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close the sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MultiProvider(
                        providers: [
                          ChangeNotifierProvider.value(value: userProvider),
                          ChangeNotifierProvider.value(value: vetProvider),
                        ],
                        child: PatientDetailPage(
                          ownerId: ownerId,
                          initialExpandedPetId: petId,
                        ),
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.open_in_new, size: 18.sp),
                label: Text('View Pet Owner Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simplified symptom card for pet-specific view (no owner info needed)
class _PetSymptomCard extends StatelessWidget {
  final EnrichedSymptom enriched;

  const _PetSymptomCard({required this.enriched});

  @override
  Widget build(BuildContext context) {
    final symptom = enriched.symptom;
    final timeAgo = _formatTimeAgo(symptom.timestamp);
    
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        border: Border.all(
          color: _getSymptomColor(symptom.type).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: _getSymptomColor(symptom.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius2),
            ),
            child: Icon(
              _getSymptomIcon(symptom.type),
              color: _getSymptomColor(symptom.type),
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
                    Expanded(
                      child: Text(
                        getSymptomLabel(symptom.type),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppTheme.neutral700,
                      ),
                    ),
                  ],
                ),
                Gap(4.h),
                Text(
                  DateFormat('EEEE, MMM d \'at\' h:mm a').format(symptom.timestamp),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.neutral700,
                  ),
                ),
                if (symptom.note != null && symptom.note!.isNotEmpty) ...[
                  Gap(AppTheme.spacing2),
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacing2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notes,
                          size: 14.sp,
                          color: AppTheme.neutral700,
                        ),
                        Gap(AppTheme.spacing2),
                        Expanded(
                          child: Text(
                            symptom.note!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  IconData _getSymptomIcon(SymptomType type) {
    switch (type) {
      case SymptomType.vomiting:
        return Icons.sick;
      case SymptomType.diarrhea:
        return Icons.report_problem;
      case SymptomType.cough:
        return Icons.air;
      case SymptomType.sneezing:
        return Icons.masks;
      case SymptomType.choking:
        return Icons.warning;
      case SymptomType.seizure:
        return Icons.emergency;
      case SymptomType.disorientation:
        return Icons.psychology;
      case SymptomType.circling:
        return Icons.rotate_right;
      case SymptomType.restlessness:
        return Icons.run_circle;
      case SymptomType.limping:
        return Icons.accessible;
      case SymptomType.jointDiscomfort:
        return Icons.healing;
      case SymptomType.itching:
        return Icons.pets;
      case SymptomType.ocularDischarge:
        return Icons.visibility;
      case SymptomType.vaginalDischarge:
        return Icons.female;
      case SymptomType.estrus:
        return Icons.favorite;
      case SymptomType.other:
        return Icons.monitor_heart;
    }
  }

  Color _getSymptomColor(SymptomType type) {
    switch (type) {
      case SymptomType.vomiting:
      case SymptomType.diarrhea:
        return Colors.red;
      case SymptomType.choking:
      case SymptomType.seizure:
        return Colors.red.shade700;
      case SymptomType.cough:
      case SymptomType.sneezing:
        return Colors.blue;
      case SymptomType.disorientation:
      case SymptomType.circling:
      case SymptomType.restlessness:
        return Colors.orange;
      case SymptomType.limping:
      case SymptomType.jointDiscomfort:
        return Colors.purple;
      case SymptomType.itching:
      case SymptomType.ocularDischarge:
        return Colors.pink;
      case SymptomType.vaginalDischarge:
      case SymptomType.estrus:
        return Colors.teal;
      case SymptomType.other:
        return Colors.grey;
    }
  }
}
