import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/vet_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/appointment_request_provider.dart';
import '../../models/appointment_request_model.dart';
import '../../theme/app_theme.dart';
import '../petOwners/profile_page.dart';
import '../petOwners/settings_page.dart';
import 'receptionist_home_page.dart';
import 'appointment_requests_page.dart';

class ReceptionistDashboardPage extends StatefulWidget {
  const ReceptionistDashboardPage({super.key});

  @override
  State<ReceptionistDashboardPage> createState() =>
      _ReceptionistDashboardPageState();
}

class _ReceptionistDashboardPageState extends State<ReceptionistDashboardPage> {
  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  void _initializeDashboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      final vetProvider = context.read<VetProvider>();
      final appointmentProvider = context.read<AppointmentRequestProvider>();
      final clinicId = userProvider.connectedClinic?.id;

      if (clinicId != null) {
        vetProvider.initialize(clinicId);
        appointmentProvider.initializeForReceptionist(clinicId);
      }
    });
  }

  void _navigateToClinic() {
    final homeState = context
        .findAncestorStateOfType<ReceptionistHomePageState>();
    homeState?.switchToClinic();
  }

  void _navigateToPatients() {
    final homeState = context
        .findAncestorStateOfType<ReceptionistHomePageState>();
    homeState?.switchToPatients();
  }

  void _navigateToAppointmentRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppointmentRequestsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, VetProvider>(
      builder: (context, userProvider, vetProvider, _) {
        final clinic = userProvider.connectedClinic;
        final receptionistName =
            userProvider.currentUser?.displayName.split(' ').first ?? 'there';

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
                    // Unified "Your Day" Section
                    SliverToBoxAdapter(
                      child: _buildYourDaySection(
                        context,
                        receptionistName,
                        clinic,
                        userProvider,
                      ),
                    ),

                    // Quick Actions
                    SliverToBoxAdapter(child: _buildQuickActions(context)),

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

  /// Unified "Your Day" section - combines greeting, appointments, and messages
  Widget _buildYourDaySection(
    BuildContext context,
    String receptionistName,
    dynamic clinic,
    UserProvider userProvider,
  ) {
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Padding(
      padding: EdgeInsets.all(AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with greeting and action buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()}, $receptionistName',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      today,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    if (clinic != null) ...[
                      Gap(2.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_hospital_outlined,
                            size: 12.sp,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          Gap(4.w),
                          Text(
                            clinic.name,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  size: 22.sp,
                  color: Colors.white,
                ),
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
                icon: Icon(
                  Icons.person_outline,
                  size: 22.sp,
                  color: Colors.white,
                ),
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

          Gap(AppTheme.spacing5),

          // Appointment Requests Section
          _buildAppointmentRequestsSection(),

          Gap(AppTheme.spacing4),

          // Today's Appointments (Coming Soon placeholder)
          _buildAppointmentsCard(),

          Gap(AppTheme.spacing4),

          // Messages Section
          _buildMessagesSection(),
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

  /// Appointment Requests section
  Widget _buildAppointmentRequestsSection() {
    return Consumer<AppointmentRequestProvider>(
      builder: (context, provider, _) {
        final pendingCount = provider.pendingCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.white, size: 16.sp),
                Gap(AppTheme.spacing2),
                Text(
                  'Appointment Requests',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Gap(AppTheme.spacing3),
            if (pendingCount == 0)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppTheme.spacing4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radius4),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: AppTheme.brandTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radius3),
                      ),
                      child: Icon(
                        Icons.check_circle,
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
                            'No pending requests',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                          Gap(2.h),
                          Text(
                            'All appointment requests have been handled',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.neutral700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              _MessageCard(
                icon: Icons.calendar_today,
                iconColor: Colors.orange,
                title:
                    '$pendingCount pending request${pendingCount != 1 ? 's' : ''}',
                subtitle: 'Pet owners waiting for confirmation',
                badgeCount: pendingCount,
                badgeColor: Colors.orange,
                onTap: _navigateToAppointmentRequests,
              ),
          ],
        );
      },
    );
  }

  /// Today's confirmed appointments card driven by real data
  Widget _buildAppointmentsCard() {
    return Consumer<AppointmentRequestProvider>(
      builder: (context, provider, _) {
        final todayAppointments = todaysConfirmedAppointments(
          provider.allRequests,
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppTheme.spacing4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppTheme.brandTeal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: AppTheme.brandTeal,
                      size: 18.sp,
                    ),
                  ),
                  Gap(AppTheme.spacing3),
                  Text(
                    "Today's Appointments",
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (todayAppointments.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandTeal,
                        borderRadius: BorderRadius.circular(AppTheme.radius2),
                      ),
                      child: Text(
                        todayAppointments.length.toString(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              Gap(AppTheme.spacing3),
              if (todayAppointments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppTheme.spacing3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radius3),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 18.sp,
                      ),
                      Gap(AppTheme.spacing2),
                      Expanded(
                        child: Text(
                          'No confirmed appointments for today',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...todayAppointments.map(
                  (appt) => Padding(
                    padding: EdgeInsets.only(bottom: AppTheme.spacing2),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(AppTheme.spacing3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radius3),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.pets,
                            size: 18.sp,
                            color: AppTheme.primary,
                          ),
                          Gap(AppTheme.spacing2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${appt.petName} — ${appt.petOwnerName}',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                Gap(2.h),
                                Text(
                                  '${appt.timePreference.shortText} · ${appt.reason}',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: AppTheme.neutral700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Messages section with pending requests and unread messages
  Widget _buildMessagesSection() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final unreadCount = chatProvider.totalUnreadCount;
        final pendingCount = chatProvider.pendingRequests.length;
        final hasItems = unreadCount > 0 || pendingCount > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 16.sp,
                ),
                Gap(AppTheme.spacing2),
                Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Gap(AppTheme.spacing3),
            if (!hasItems)
              _buildAllCaughtUpCard()
            else
              Column(
                children: [
                  // Pending Requests Card
                  if (pendingCount > 0) ...[
                    _MessageCard(
                      icon: Icons.pending_actions,
                      iconColor: Colors.orange,
                      title:
                          '$pendingCount pending request${pendingCount != 1 ? 's' : ''}',
                      subtitle: 'Pet owners waiting for response',
                      badgeCount: pendingCount,
                      badgeColor: Colors.orange,
                      onTap: _navigateToClinic,
                    ),
                    Gap(AppTheme.spacing2),
                  ],
                  // Unread Messages Card
                  if (unreadCount > 0)
                    _MessageCard(
                      icon: Icons.mark_email_unread,
                      iconColor: AppTheme.brandBlueLight,
                      title:
                          '$unreadCount unread message${unreadCount != 1 ? 's' : ''}',
                      subtitle: 'From active conversations',
                      badgeCount: unreadCount,
                      badgeColor: AppTheme.brandBlueLight,
                      onTap: _navigateToClinic,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  /// All caught up card
  Widget _buildAllCaughtUpCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: AppTheme.brandTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius3),
            ),
            child: Icon(
              Icons.check_circle,
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
                    color: AppTheme.primary,
                  ),
                ),
                Gap(2.h),
                Text(
                  'No pending requests or unread messages',
                  style: TextStyle(fontSize: 12.sp, color: AppTheme.neutral700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Quick actions row
  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Gap(AppTheme.spacing2),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.people_outline,
                  label: 'Patients',
                  onTap: _navigateToPatients,
                ),
              ),
              Gap(AppTheme.spacing3),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Messages',
                  onTap: _navigateToClinic,
                ),
              ),
              Gap(AppTheme.spacing3),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.calendar_month,
                  label: 'Requests',
                  onTap: _navigateToAppointmentRequests,
                ),
              ),
            ],
          ),
          Gap(AppTheme.spacing5),
        ],
      ),
    );
  }
}

/// Message card for the Messages section
class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int badgeCount;
  final Color badgeColor;
  final VoidCallback onTap;

  const _MessageCard({
    required this.icon,
    required this.iconColor,
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
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radius3),
                ),
                child: Icon(icon, color: iconColor, size: 20.sp),
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
                color: AppTheme.neutral700.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick action button for shortcuts
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: AppTheme.spacing3,
            horizontal: AppTheme.spacing2,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radius3),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22.sp),
              Gap(AppTheme.spacing2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
