import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../theme/app_theme.dart';
import '../../providers/user_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.injectedUserProvider});

  final UserProvider injectedUserProvider;

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined),
            onPressed: () {
              // TODO: Navigate to edit profile
            },
          ),
        ],
      ),
      body: ChangeNotifierProvider.value(
        value: injectedUserProvider,
        child: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final profile = userProvider.currentUser;
            final clinic = userProvider.connectedClinic;
            
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildProfileHeader(context, authUser, profile),
                
                if (clinic != null) ...[
                  Gap(AppTheme.spacing3),
                  _buildSection(
                    context,
                    'Connected Clinic',
                    [
                      _buildInfoRow(context, Icons.business, 'Clinic', clinic.name),
                      if (clinic.address.isNotEmpty)
                        _buildInfoRow(context, Icons.location_on_outlined, 'Address', clinic.address),
                      if (clinic.phone.isNotEmpty)
                        _buildInfoRow(context, Icons.phone_outlined, 'Phone', clinic.phone),
                      if (clinic.email.isNotEmpty)
                        _buildInfoRow(context, Icons.email_outlined, 'Email', clinic.email),
                    ],
                  ),
                ],
                
                Gap(AppTheme.spacing3),
                _buildSection(
                  context,
                  'Account Information',
                  [
                    _buildInfoRow(
                      context,
                      Icons.email_outlined,
                      'Email',
                      profile?.email ?? authUser?.email ?? 'Not set',
                    ),
                    _buildInfoRow(
                      context,
                      Icons.shield_outlined,
                      'Account Type',
                      _getUserTypeLabel(profile?.globalType),
                    ),
                    if (profile?.createdAt != null)
                      _buildInfoRow(
                        context,
                        Icons.calendar_today_outlined,
                        'Member Since',
                        DateFormat('MMMM d, yyyy').format(profile!.createdAt),
                      ),
                  ],
                ),
                
                Gap(AppTheme.spacing6),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, User? authUser, dynamic profile) {
    final displayName = profile?.displayName ?? authUser?.displayName ?? 'User';
    final email = profile?.email ?? authUser?.email ?? '';

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing6),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(bottom: BorderSide(color: context.border, width: 0.5)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48.r,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            child: Text(
              displayName[0].toUpperCase(),
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 40.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Gap(AppTheme.spacing3),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          Gap(AppTheme.spacing1),
          Text(
            email,
            style: TextStyle(
              fontSize: 15.sp,
              color: context.textSecondary,
            ),
          ),
          Gap(AppTheme.spacing4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem(context, '0', 'Pets'),
              Container(
                width: 1,
                height: 32.h,
                color: context.border,
                margin: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
              ),
              _buildStatItem(context, '0', 'Appointments'),
              Container(
                width: 1,
                height: 32.h,
                color: context.border,
                margin: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
              ),
              _buildStatItem(context, '0', 'Records'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        Gap(4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(AppTheme.spacing4, AppTheme.spacing3, AppTheme.spacing4, AppTheme.spacing2),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.surface,
            border: Border(
              top: BorderSide(color: context.border, width: 0.5),
              bottom: BorderSide(color: context.border, width: 0.5),
            ),
          ),
          child: Column(
            children: children.expand((child) => [
              child,
              if (child != children.last)
                Divider(height: 0.5, thickness: 0.5, color: context.border, indent: 52.w),
            ]).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4, vertical: AppTheme.spacing3),
      child: Row(
        children: [
          Icon(icon, size: 22.sp, color: AppTheme.primary),
          Gap(AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: context.textSecondary,
                  ),
                ),
                Gap(2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getUserTypeLabel(String? userType) {
    switch (userType) {
      case 'pet_owner':
        return 'Pet Owner';
      case 'vet':
        return 'Veterinarian';
      case 'clinic_admin':
        return 'Clinic Administrator';
      case 'app_owner':
        return 'App Owner';
      default:
        return 'Pet Owner';
    }
  }
}

