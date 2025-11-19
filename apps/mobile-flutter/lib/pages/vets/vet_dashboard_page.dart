import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../providers/user_provider.dart';
import '../../providers/vet_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../petOwners/profile_page.dart';
import '../petOwners/settings_page.dart';

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

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, VetProvider>(
      builder: (context, userProvider, vetProvider, _) {
        final clinic = userProvider.connectedClinic;
        final vetName = userProvider.currentUser?.displayName ?? 'Vet';

        return Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            title: Text(
              'Dashboard',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.neutral700,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
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
                icon: const Icon(Icons.person_outline),
                tooltip: 'Profile',
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
          body: ListView(
            padding: EdgeInsets.all(AppTheme.spacing4),
            children: [
              // Welcome Section
              Text(
                'Welcome, $vetName',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              Gap(AppTheme.spacing2),

              // Clinic Info Card
              if (clinic != null)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius3),
                    side: BorderSide(color: context.border),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacing4),
                    child: Row(
                      children: [
                        Container(
                          width: 48.w,
                          height: 48.w,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius2,
                            ),
                          ),
                          child: Icon(
                            Icons.local_hospital,
                            color: AppTheme.primary,
                            size: 24.sp,
                          ),
                        ),
                        Gap(AppTheme.spacing3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clinic.name,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                              Gap(AppTheme.spacing1),
                              Text(
                                clinic.address,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius3),
                    side: BorderSide(color: context.border),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacing4),
                    child: Text(
                      'No clinic linked yet',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ),

              Gap(AppTheme.spacing5),

              // Quick Stats Section
              Text(
                'Overview',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              Gap(AppTheme.spacing3),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.pets,
                      label: 'Patients',
                      value: vetProvider.isLoading
                          ? '-'
                          : '${vetProvider.patients.length}',
                      color: AppTheme.neutral700,
                    ),
                  ),
                  Gap(AppTheme.spacing3),
                  Expanded(
                    child: Consumer<ChatProvider>(
                      builder: (context, chatProvider, _) {
                        final activeChats = chatProvider.chatRooms.length;
                        final pendingRequests =
                            chatProvider.pendingRequests.length;

                        return _StatCard(
                          icon: Icons.chat_bubble,
                          label: 'Chats',
                          value: '$activeChats',
                          subtitle: pendingRequests > 0
                              ? '$pendingRequests pending'
                              : null,
                          color: AppTheme.primary,
                        );
                      },
                    ),
                  ),
                ],
              ),

              Gap(AppTheme.spacing5),

              // Recent Activity Section
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              Gap(AppTheme.spacing3),

              if (vetProvider.isLoading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacing4),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (vetProvider.patients.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius3),
                    side: BorderSide(color: context.border),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacing5),
                    child: Column(
                      children: [
                        Icon(
                          Icons.pets_outlined,
                          size: 48.sp,
                          color: context.textSecondary,
                        ),
                        Gap(AppTheme.spacing2),
                        Text(
                          'No patients yet',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...vetProvider.patients
                    .take(5)
                    .map(
                      (owner) => Padding(
                        padding: EdgeInsets.only(bottom: AppTheme.spacing2),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius3,
                            ),
                            side: BorderSide(color: context.border),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                owner.displayName.isNotEmpty
                                    ? owner.displayName[0].toUpperCase()
                                    : owner.email[0].toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            title: Text(
                              owner.displayName.isEmpty
                                  ? owner.email
                                  : owner.displayName,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              owner.email,
                              style: TextStyle(fontSize: 12.sp),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16.sp,
                              color: context.textSecondary,
                            ),
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
}

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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        side: BorderSide(color: context.border),
      ),
      child: Padding(
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
                color: context.textPrimary,
              ),
            ),
            Gap(AppTheme.spacing1),
            Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: context.textSecondary),
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
      ),
    );
  }
}
