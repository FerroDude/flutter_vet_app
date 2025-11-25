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

    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Profile', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () {
                // missing Navigate to edit profile
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
                  _buildSection(context, 'Connected Clinic', [
                    _buildInfoRow(
                      context,
                      Icons.business,
                      'Clinic',
                      clinic.name,
                    ),
                    if (clinic.address.isNotEmpty)
                      _buildInfoRow(
                        context,
                        Icons.location_on_outlined,
                        'Address',
                        clinic.address,
                      ),
                    if (clinic.phone.isNotEmpty)
                      _buildInfoRow(
                        context,
                        Icons.phone_outlined,
                        'Phone',
                        clinic.phone,
                      ),
                    if (clinic.email.isNotEmpty)
                      _buildInfoRow(
                        context,
                        Icons.email_outlined,
                        'Email',
                        clinic.email,
                      ),
                  ]),
                ],

                Gap(AppTheme.spacing3),
                _buildSection(context, 'Account Information', [
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
                ]),

                Gap(AppTheme.spacing6),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    User? authUser,
    dynamic profile,
  ) {
    final rawDisplayName =
        profile?.displayName ?? authUser?.displayName ?? '';
    final email = profile?.email ?? authUser?.email ?? '';

    // Ensure we always have a non-empty name to display and to derive initials
    final displayName = rawDisplayName.isNotEmpty
        ? rawDisplayName
        : (email.isNotEmpty ? email : 'User');
    final initialSource = displayName.isNotEmpty ? displayName : 'U';

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing6),
      margin: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48.r,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Text(
              initialSource[0].toUpperCase(),
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
              color: AppTheme.primary,
            ),
          ),
          Gap(AppTheme.spacing1),
          Text(
            email,
            style: TextStyle(fontSize: 15.sp, color: AppTheme.neutral700),
          ),
          Gap(AppTheme.spacing4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem(context, '0', 'Pets'),
              Container(
                width: 1,
                height: 32.h,
                color: AppTheme.neutral200,
                margin: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
              ),
              _buildStatItem(context, '0', 'Appointments'),
              Container(
                width: 1,
                height: 32.h,
                color: AppTheme.neutral200,
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
            color: AppTheme.primary,
          ),
        ),
        Gap(4.h),
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: AppTheme.neutral700),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.spacing4,
            AppTheme.spacing3,
            AppTheme.spacing4,
            AppTheme.spacing2,
          ),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
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
          margin: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          child: Column(
            children: children
                .expand(
                  (child) => [
                    child,
                    if (child != children.last)
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: AppTheme.neutral200,
                        indent: 52.w,
                      ),
                  ],
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing4,
        vertical: AppTheme.spacing3,
      ),
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
                    color: AppTheme.neutral700,
                  ),
                ),
                Gap(2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.primary,
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
