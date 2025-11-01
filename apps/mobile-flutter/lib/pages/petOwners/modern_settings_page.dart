import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_toggle_widget.dart';
import '../../widgets/modern_modals.dart';

/// Modern, redesigned settings page with clean UI and smooth animations
class ModernSettingsPage extends StatelessWidget {
  const ModernSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.surfacePrimary,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: context.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(AppTheme.spacing4),
        children: [
          // User Info Card (if signed in)
          if (user != null) _UserInfoCard(user: user, isDark: isDark),

          SizedBox(height: AppTheme.spacing4),

          // App Preferences
          _SectionTitle(title: 'App Preferences', icon: Icons.tune),
          SizedBox(height: AppTheme.spacing2),
          _SettingsCard(
            isDark: isDark,
            children: [
              _SwitchSettingTile(
                icon: Icons.notifications_outlined,
                title: 'Push Notifications',
                subtitle: 'Get notified about appointments and reminders',
                value: true,
                onChanged: (value) {
                  _showFeatureSnackbar(context, 'Notifications', value);
                },
              ),
              Divider(height: 1, color: context.borderLight),
              _ThemeSettingTile(),
              Divider(height: 1, color: context.borderLight),
              _TapSettingTile(
                icon: Icons.language_outlined,
                title: 'Language',
                subtitle: 'English (US)',
                onTap: () {
                  _showComingSoonSnackbar(context, 'Language selection');
                },
              ),
            ],
          ),

          SizedBox(height: AppTheme.spacing5),

          // Pet Care Settings
          _SectionTitle(title: 'Pet Care', icon: Icons.pets),
          SizedBox(height: AppTheme.spacing2),
          _SettingsCard(
            isDark: isDark,
            children: [
              _SwitchSettingTile(
                icon: Icons.medication_outlined,
                title: 'Medication Reminders',
                subtitle: 'Get reminded about pet medications',
                value: true,
                onChanged: (value) {
                  _showFeatureSnackbar(context, 'Medication reminders', value);
                },
              ),
              Divider(height: 1, color: context.borderLight),
              _SwitchSettingTile(
                icon: Icons.calendar_today_outlined,
                title: 'Appointment Reminders',
                subtitle: 'Get reminded about upcoming vet visits',
                value: true,
                onChanged: (value) {
                  _showFeatureSnackbar(context, 'Appointment reminders', value);
                },
              ),
              Divider(height: 1, color: context.borderLight),
              _SwitchSettingTile(
                icon: Icons.share_outlined,
                title: 'Share Pet Profiles',
                subtitle: 'Allow vets to view pet profiles',
                value: true,
                onChanged: (value) {
                  _showFeatureSnackbar(context, 'Pet profile sharing', value);
                },
              ),
            ],
          ),

          SizedBox(height: AppTheme.spacing5),

          // Data & Privacy
          _SectionTitle(title: 'Data & Privacy', icon: Icons.security),
          SizedBox(height: AppTheme.spacing2),
          _SettingsCard(
            isDark: isDark,
            children: [
              _TapSettingTile(
                icon: Icons.cloud_upload_outlined,
                title: 'Data Backup',
                subtitle: 'Backup pet data to cloud',
                onTap: () {
                  _showComingSoonSnackbar(context, 'Data backup');
                },
              ),
              Divider(height: 1, color: context.borderLight),
              _TapSettingTile(
                icon: Icons.lock_outline,
                title: 'Privacy Policy',
                subtitle: 'View our privacy policy',
                onTap: () {
                  _showComingSoonSnackbar(context, 'Privacy policy');
                },
              ),
              Divider(height: 1, color: context.borderLight),
              _TapSettingTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'View terms of service',
                onTap: () {
                  _showComingSoonSnackbar(context, 'Terms of service');
                },
              ),
            ],
          ),

          SizedBox(height: AppTheme.spacing5),

          // Account Actions
          _SectionTitle(title: 'Account', icon: Icons.person_outline),
          SizedBox(height: AppTheme.spacing2),
          _SettingsCard(
            isDark: isDark,
            children: [
              _TapSettingTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help with the app',
                onTap: () {
                  _showComingSoonSnackbar(context, 'Help & Support');
                },
              ),
              Divider(height: 1, color: context.borderLight),
              _TapSettingTile(
                icon: Icons.info_outline,
                title: 'About',
                subtitle: 'Version 1.0.0',
                onTap: () {
                  _showAboutDialog(context);
                },
              ),
              Divider(height: 1, color: context.borderLight),
              _TapSettingTile(
                icon: Icons.logout,
                title: 'Sign Out',
                subtitle: 'Sign out of your account',
                onTap: () {
                  _showSignOutDialog(context);
                },
                titleColor: AppTheme.errorRed,
                iconColor: AppTheme.errorRed,
              ),
            ],
          ),

          SizedBox(height: AppTheme.spacing8),
        ],
      ),
    );
  }

  void _showFeatureSnackbar(
    BuildContext context,
    String feature,
    bool enabled,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature ${enabled ? 'enabled' : 'disabled'}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showComingSoonSnackbar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming soon!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About VetPlus'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('A modern pet care management app'),
            SizedBox(height: 16),
            Text(
              '© 2024 VetPlus. All rights reserved.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) async {
    final confirmed = await showModernConfirmDialog(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmText: 'Sign Out',
      confirmColor: const Color(0xFFEF4444),
      icon: Icons.logout,
      iconColor: const Color(0xFFEF4444),
    );

    if (confirmed == true && context.mounted) {
      try {
        await FirebaseAuth.instance.signOut();
        // The auth listener will handle navigation
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }
}

// Separate Widget Components for Better Organization
class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({required this.user, required this.isDark});

  final User user;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName ?? 'User';
    final email = user.email ?? '';

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.primaryColor.withOpacity(0.1),
            context.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.primaryColor,
                  context.primaryColor.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Center(
              child: Text(
                displayName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacing4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.secondaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.primaryColor),
        SizedBox(width: AppTheme.spacing2),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.textColor,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.isDark, required this.children});

  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: context.borderLight, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchSettingTile extends StatelessWidget {
  const _SwitchSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing4,
        vertical: AppTheme.spacing2,
      ),
      leading: Container(
        padding: EdgeInsets.all(AppTheme.spacing2),
        decoration: BoxDecoration(
          color: context.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Icon(icon, color: context.primaryColor, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: context.textColor),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: context.secondaryTextColor),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: context.primaryColor,
      ),
    );
  }
}

class _ThemeSettingTile extends StatelessWidget {
  const _ThemeSettingTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppTheme.spacing2),
                decoration: BoxDecoration(
                  color: context.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: context.primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: AppTheme.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Theme',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose your preferred theme',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacing3),
          const ThemeToggleWidget(showLabel: false, isExpanded: true),
        ],
      ),
    );
  }
}

class _TapSettingTile extends StatelessWidget {
  const _TapSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing4,
        vertical: AppTheme.spacing2,
      ),
      leading: Container(
        padding: EdgeInsets.all(AppTheme.spacing2),
        decoration: BoxDecoration(
          color: (iconColor ?? context.primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Icon(icon, color: iconColor ?? context.primaryColor, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor ?? context.textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: context.secondaryTextColor),
      ),
      trailing: Icon(Icons.chevron_right, color: context.secondaryTextColor),
      onTap: onTap,
    );
  }
}
