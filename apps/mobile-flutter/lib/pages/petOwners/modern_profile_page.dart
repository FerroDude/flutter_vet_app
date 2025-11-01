import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../models/clinic_models.dart';
import '../../widgets/modern_modals.dart';

/// Modern, redesigned profile page with clean UI and smooth animations
class ModernProfilePage extends StatelessWidget {
  const ModernProfilePage({super.key, required this.injectedUserProvider});

  final UserProvider injectedUserProvider;

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.surfacePrimary,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: context.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ChangeNotifierProvider.value(
        value: injectedUserProvider,
        child: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final profile = userProvider.currentUser;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(AppTheme.spacing4),
              children: [
                // Profile Header Card
                _ProfileHeader(
                  authUser: authUser,
                  profile: profile,
                  isDark: isDark,
                ),

                SizedBox(height: AppTheme.spacing5),

                // Account Information
                _SectionTitle(title: 'Account Information', icon: Icons.person),
                SizedBox(height: AppTheme.spacing2),
                _InfoCard(
                  isDark: isDark,
                  children: [
                    _InfoTile(
                      icon: Icons.person_outline,
                      label: 'Display Name',
                      value:
                          profile?.displayName ??
                          authUser?.displayName ??
                          'Not set',
                    ),
                    Divider(height: 1, color: context.borderLight),
                    _InfoTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: profile?.email ?? authUser?.email ?? 'Not set',
                    ),
                    Divider(height: 1, color: context.borderLight),
                    _InfoTile(
                      icon: Icons.shield_outlined,
                      label: 'Account Type',
                      value: _getUserTypeLabel(profile?.userType),
                    ),
                    if (profile?.createdAt != null) ...[
                      Divider(height: 1, color: context.borderLight),
                      _InfoTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'Member Since',
                        value: DateFormat(
                          'MMMM d, yyyy',
                        ).format(profile!.createdAt),
                      ),
                    ],
                  ],
                ),

                SizedBox(height: AppTheme.spacing5),

                // Clinic Information (if connected)
                if (userProvider.connectedClinic != null) ...[
                  _SectionTitle(
                    title: 'Connected Clinic',
                    icon: Icons.local_hospital,
                  ),
                  SizedBox(height: AppTheme.spacing2),
                  _InfoCard(
                    isDark: isDark,
                    children: [
                      _InfoTile(
                        icon: Icons.business_outlined,
                        label: 'Clinic Name',
                        value: userProvider.connectedClinic!.name,
                      ),
                      Divider(height: 1, color: context.borderLight),
                      _InfoTile(
                        icon: Icons.location_on_outlined,
                        label: 'Address',
                        value: userProvider.connectedClinic!.address,
                      ),
                      Divider(height: 1, color: context.borderLight),
                      _InfoTile(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: userProvider.connectedClinic!.phone,
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacing5),
                ],

                // Actions
                _SectionTitle(title: 'Actions', icon: Icons.settings_outlined),
                SizedBox(height: AppTheme.spacing2),
                _InfoCard(
                  isDark: isDark,
                  children: [
                    _ActionTile(
                      icon: Icons.edit_outlined,
                      label: 'Edit Profile',
                      color: context.primaryColor,
                      onTap: () {
                        _showEditProfileDialog(context, authUser, userProvider);
                      },
                    ),
                    if (authUser != null && !authUser.emailVerified) ...[
                      Divider(height: 1, color: context.borderLight),
                      _ActionTile(
                        icon: Icons.mark_email_read_outlined,
                        label: 'Verify Email',
                        color: AppTheme.warningAmber,
                        onTap: () {
                          _resendVerificationEmail(context, authUser);
                        },
                      ),
                    ],
                    Divider(height: 1, color: context.borderLight),
                    _ActionTile(
                      icon: Icons.lock_outline,
                      label: 'Change Password',
                      color: context.primaryColor,
                      onTap: () {
                        _showChangePasswordDialog(context, authUser);
                      },
                    ),
                    Divider(height: 1, color: context.borderLight),
                    _ActionTile(
                      icon: Icons.delete_outline,
                      label: 'Delete Account',
                      color: AppTheme.errorRed,
                      onTap: () {
                        _showDeleteAccountDialog(context);
                      },
                    ),
                  ],
                ),

                SizedBox(height: AppTheme.spacing8),
              ],
            );
          },
        ),
      ),
    );
  }

  String _getUserTypeLabel(UserType? userType) {
    switch (userType) {
      case UserType.petOwner:
        return 'Pet Owner';
      case UserType.vet:
        return 'Veterinarian';
      case UserType.clinicAdmin:
        return 'Clinic Admin';
      case UserType.appOwner:
        return 'App Owner';
      default:
        return 'Pet Owner';
    }
  }

  void _showEditProfileDialog(
    BuildContext context,
    User? authUser,
    UserProvider userProvider,
  ) {
    final profile = userProvider.currentUser;
    final nameController = TextEditingController(
      text: profile?.displayName ?? authUser?.displayName ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setState) {
          bool isLoading = false;

          return ModernBottomSheet(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ModernModalHeader(
                    title: 'Edit Profile',
                    icon: Icons.edit_outlined,
                    iconColor: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(height: 24),
                  ModernModalTextField(
                    controller: nameController,
                    label: 'Display Name',
                    hint: 'Enter your name',
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ModernModalButton(
                          text: 'Cancel',
                          isPrimary: false,
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(dialogContext),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ModernModalButton(
                          text: 'Save',
                          isLoading: isLoading,
                          icon: Icons.check,
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              setState(() => isLoading = true);

                              try {
                                final newName = nameController.text.trim();
                                await userProvider.updateProfile(
                                  displayName: newName,
                                );
                                if (authUser != null) {
                                  await authUser.updateDisplayName(newName);
                                  await authUser.reload();
                                }

                                if (builderContext.mounted) {
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(
                                    builderContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Profile updated successfully!',
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (builderContext.mounted) {
                                  ScaffoldMessenger.of(
                                    builderContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      backgroundColor: Color(0xFFEF4444),
                                    ),
                                  );
                                }
                              } finally {
                                if (builderContext.mounted) {
                                  setState(() => isLoading = false);
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _resendVerificationEmail(BuildContext context, User authUser) async {
    try {
      await authUser.sendEmailVerification();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending verification email: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context, User? authUser) {
    if (authUser == null) return;

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setState) {
          bool isLoading = false;
          bool showCurrentPassword = false;
          bool showNewPassword = false;
          bool showConfirmPassword = false;

          return ModernBottomSheet(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ModernModalHeader(
                    title: 'Change Password',
                    icon: Icons.lock_outline,
                    iconColor: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 24),
                  ModernModalTextField(
                    controller: currentPasswordController,
                    label: 'Current Password',
                    hint: 'Enter current password',
                    icon: Icons.lock_outline,
                    obscureText: !showCurrentPassword,
                    suffix: IconButton(
                      icon: Icon(
                        showCurrentPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(
                          () => showCurrentPassword = !showCurrentPassword,
                        );
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ModernModalTextField(
                    controller: newPasswordController,
                    label: 'New Password',
                    hint: 'At least 6 characters',
                    icon: Icons.lock_outline,
                    obscureText: !showNewPassword,
                    suffix: IconButton(
                      icon: Icon(
                        showNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => showNewPassword = !showNewPassword);
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ModernModalTextField(
                    controller: confirmPasswordController,
                    label: 'Confirm New Password',
                    hint: 'Re-enter new password',
                    icon: Icons.lock_outline,
                    obscureText: !showConfirmPassword,
                    suffix: IconButton(
                      icon: Icon(
                        showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(
                          () => showConfirmPassword = !showConfirmPassword,
                        );
                      },
                    ),
                    validator: (value) {
                      if (value != newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ModernModalButton(
                          text: 'Cancel',
                          isPrimary: false,
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(dialogContext),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ModernModalButton(
                          text: 'Update',
                          isLoading: isLoading,
                          icon: Icons.check,
                          color: const Color(0xFFF59E0B),
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              setState(() => isLoading = true);

                              try {
                                // Reauthenticate
                                final credential = EmailAuthProvider.credential(
                                  email: authUser.email!,
                                  password: currentPasswordController.text,
                                );
                                await authUser.reauthenticateWithCredential(
                                  credential,
                                );

                                // Update password
                                await authUser.updatePassword(
                                  newPasswordController.text,
                                );

                                if (builderContext.mounted) {
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(
                                    builderContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Password changed successfully!',
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (builderContext.mounted) {
                                  ScaffoldMessenger.of(
                                    builderContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      backgroundColor: Color(0xFFEF4444),
                                    ),
                                  );
                                }
                              } finally {
                                if (builderContext.mounted) {
                                  setState(() => isLoading = false);
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showModernConfirmDialog(
      context,
      title: 'Delete Account',
      message:
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
      confirmText: 'Delete Account',
      confirmColor: const Color(0xFFEF4444),
      icon: Icons.warning_outlined,
      iconColor: const Color(0xFFEF4444),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deletion - Please contact support'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
    }
  }
}

// Separate Widget Components for Better Organization
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.authUser,
    required this.profile,
    required this.isDark,
  });

  final User? authUser;
  final dynamic profile;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.displayName ?? authUser?.displayName ?? 'User';
    final email = profile?.email ?? authUser?.email ?? '';
    final isVerified = authUser?.emailVerified ?? false;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.primaryColor, context.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: Text(
                displayName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: AppTheme.spacing4),
          Text(
            displayName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spacing1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified, size: 16, color: Colors.white),
              ],
            ],
          ),
          if (!isVerified) ...[
            SizedBox(height: AppTheme.spacing2),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacing3,
                vertical: AppTheme.spacing1,
              ),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: const Text(
                'Email not verified',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.isDark, required this.children});

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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacing4),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spacing2),
            decoration: BoxDecoration(
              color: context.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: context.primaryColor, size: 20),
          ),
          SizedBox(width: AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      trailing: Icon(Icons.chevron_right, color: context.secondaryTextColor),
      onTap: onTap,
    );
  }
}
