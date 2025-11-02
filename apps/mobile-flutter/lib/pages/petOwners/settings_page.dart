import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../widgets/theme_toggle_widget.dart';
import 'profile_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.injectedUserProvider});

  final UserProvider? injectedUserProvider;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final effectiveProvider =
        injectedUserProvider ?? context.read<UserProvider>();

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ChangeNotifierProvider.value(
        value: effectiveProvider,
        child: Consumer<UserProvider>(
          builder: (context, userProvider, _) {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                if (user != null)
                  _buildProfileHeader(context, user, userProvider),

                Gap(AppTheme.spacing3),

                _buildSection(context, 'Account', [
                  _buildTile(
                    context,
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProfilePage(injectedUserProvider: userProvider),
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.pets_outlined,
                    title: 'My Pets',
                    subtitle: 'Manage your pets',
                    onTap: () {},
                  ),
                  _buildTile(
                    context,
                    icon: Icons.local_hospital_outlined,
                    title: 'Connected Clinic',
                    subtitle:
                        userProvider.connectedClinic?.name ?? 'Not connected',
                    onTap: () {},
                  ),
                ]),

                _buildSection(context, 'Preferences', [
                  _buildSwitchTile(
                    context,
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Appointments and reminders',
                    value: true,
                    onChanged: (value) {},
                  ),
                  _buildTile(
                    context,
                    icon: Icons.brightness_6_outlined,
                    title: 'Appearance',
                    subtitle: 'Light or dark mode',
                    trailing: const ThemeToggleWidget(),
                    onTap: null,
                  ),
                  _buildTile(
                    context,
                    icon: Icons.language_outlined,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () {},
                  ),
                ]),

                _buildSection(context, 'Support', [
                  _buildTile(
                    context,
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    onTap: () {},
                  ),
                  _buildTile(
                    context,
                    icon: Icons.chat_bubble_outline,
                    title: 'Contact Us',
                    onTap: () {},
                  ),
                  _buildTile(
                    context,
                    icon: Icons.star_outline,
                    title: 'Rate App',
                    onTap: () {},
                  ),
                ]),

                _buildSection(context, 'About', [
                  _buildTile(
                    context,
                    icon: Icons.policy_outlined,
                    title: 'Privacy Policy',
                    onTap: () {},
                  ),
                  _buildTile(
                    context,
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () {},
                  ),
                  _buildTile(
                    context,
                    icon: Icons.info_outline,
                    title: 'App Version',
                    subtitle: '1.0.0',
                    onTap: null,
                  ),
                ]),

                Padding(
                  padding: EdgeInsets.all(AppTheme.spacing4),
                  child: OutlinedButton(
                    onPressed: () async {
                      final shouldSignOut = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text(
                            'Are you sure you want to sign out?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.error,
                              ),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );

                      if (shouldSignOut == true && context.mounted) {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(color: AppTheme.error),
                      padding: EdgeInsets.symmetric(
                        vertical: AppTheme.spacing3,
                      ),
                    ),
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                Gap(AppTheme.spacing6),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    User user,
    UserProvider userProvider,
  ) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(bottom: BorderSide(color: context.border, width: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32.r,
            backgroundColor: AppTheme.neutral800.withValues(alpha:0.1),
            child: Text(
              (user.displayName ?? user.email ?? 'U')[0].toUpperCase(),
              style: TextStyle(
                color: AppTheme.neutral800,
                fontSize: 24.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Gap(AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? 'User',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                Gap(AppTheme.spacing1),
                Text(
                  user.email ?? '',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.textSecondary, size: 20.sp),
        ],
      ),
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
            children: children
                .expand(
                  (child) => [
                    child,
                    if (child != children.last)
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: context.border,
                        indent: 52.w,
                      ),
                  ],
                )
                .toList(),
          ),
        ),
        Gap(AppTheme.spacing3),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacing4,
          vertical: AppTheme.spacing3,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22.sp, color: AppTheme.neutral800),
            Gap(AppTheme.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w400,
                      color: context.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    Gap(2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: context.textSecondary,
                size: 20.sp,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing4,
        vertical: AppTheme.spacing3,
      ),
      child: Row(
        children: [
          Icon(icon, size: 22.sp, color: AppTheme.neutral800),
          Gap(AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                    color: context.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  Gap(2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.neutral800,
          ),
        ],
      ),
    );
  }
}
