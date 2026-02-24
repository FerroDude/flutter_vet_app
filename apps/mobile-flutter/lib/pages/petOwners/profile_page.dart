import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../theme/app_theme.dart';
import '../../providers/user_provider.dart';

Stream<int> petCountStream(FirebaseFirestore firestore, String userId) {
  if (userId.isEmpty) return Stream.value(0);
  return firestore
      .collection('users')
      .doc(userId)
      .collection('pets')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}

Stream<int> appointmentCountStream(FirebaseFirestore firestore, String userId) {
  if (userId.isEmpty) return Stream.value(0);
  return firestore
      .collection('appointmentRequests')
      .where('petOwnerId', isEqualTo: userId)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}

Stream<int> recordCountStream(FirebaseFirestore firestore, String userId) {
  if (userId.isEmpty) return Stream.value(0);
  return firestore
      .collectionGroup('symptoms')
      .where('ownerId', isEqualTo: userId)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}

class ProfilePage extends StatelessWidget {
  ProfilePage({
    super.key,
    required this.injectedUserProvider,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  final UserProvider injectedUserProvider;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Profile', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () => _showEditProfileDialog(context),
            ),
          ],
        ),
        body: ChangeNotifierProvider.value(
          value: injectedUserProvider,
          child: Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              final profile = userProvider.currentUser;
              final clinic = userProvider.connectedClinic;
              final userId = profile?.id ?? authUser?.uid ?? '';

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildProfileHeader(context, authUser, profile, userId),

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
    String userId,
  ) {
    final rawDisplayName = profile?.displayName ?? authUser?.displayName ?? '';
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
              _buildStatItem(
                context,
                petCountStream(firestore, userId),
                'Pets',
              ),
              Container(
                width: 1,
                height: 32.h,
                color: AppTheme.neutral200,
                margin: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
              ),
              _buildStatItem(
                context,
                appointmentCountStream(firestore, userId),
                'Appointments',
              ),
              Container(
                width: 1,
                height: 32.h,
                color: AppTheme.neutral200,
                margin: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
              ),
              _buildStatItem(
                context,
                recordCountStream(firestore, userId),
                'Records',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    Stream<int> countStream,
    String label,
  ) {
    return Column(
      children: [
        StreamBuilder<int>(
          stream: countStream,
          builder: (context, snapshot) {
            final value = snapshot.data ?? 0;
            return Text(
              value.toString(),
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            );
          },
        ),
        Gap(4.h),
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: AppTheme.neutral700),
        ),
      ],
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final currentProfile = injectedUserProvider.currentUser;
    final displayNameController = TextEditingController(
      text: currentProfile?.displayName ?? '',
    );
    final phoneController = TextEditingController(
      text: currentProfile?.phone ?? '',
    );
    final addressController = TextEditingController(
      text: currentProfile?.address ?? '',
    );
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                      ),
                    ),
                    Gap(AppTheme.spacing3),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    Gap(AppTheme.spacing3),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          final ok = await injectedUserProvider.updateProfile(
                            displayName: displayNameController.text.trim(),
                            phone: phoneController.text.trim(),
                            address: addressController.text.trim(),
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop(ok);
                        },
                  child: saving
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    displayNameController.dispose();
    phoneController.dispose();
    addressController.dispose();

    if (saved == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Profile updated successfully' : 'Failed to update profile',
        ),
        backgroundColor: saved ? AppTheme.brandTeal : Colors.red,
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
                  style: TextStyle(fontSize: 13.sp, color: AppTheme.neutral700),
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
