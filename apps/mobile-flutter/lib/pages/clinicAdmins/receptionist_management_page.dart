import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../models/clinic_models.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';

class ReceptionistManagementPage extends StatefulWidget {
  const ReceptionistManagementPage({super.key});

  @override
  State<ReceptionistManagementPage> createState() =>
      _ReceptionistManagementPageState();
}

class _ReceptionistManagementPageState
    extends State<ReceptionistManagementPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (!userProvider.canManageReceptionists) {
          return Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text(
                  'Receptionist Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: Center(
                child: Text(
                  'Access denied. Admin privileges required.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                'Receptionist Management',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: () =>
                      _showAddReceptionistDialog(context, userProvider),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                await userProvider.refresh();
              },
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : _buildReceptionistsList(userProvider),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceptionistsList(UserProvider userProvider) {
    final receptionists = userProvider.clinicMembers
        .where((m) => m.role == ClinicRole.receptionist && m.isActive)
        .toList();

    return ListView(
      padding: EdgeInsets.all(AppTheme.spacing4),
      children: [
        // Pending invites section FIRST (more important when no active receptionists)
        _buildInvitesSection(userProvider),

        Gap(AppTheme.spacing6),

        // Section header for active receptionists
        Row(
          children: [
            Icon(Icons.people_outline, color: Colors.white, size: 18.sp),
            Gap(AppTheme.spacing2),
            Text(
              'Active Receptionists',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            Gap(AppTheme.spacing2),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppTheme.brandTeal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${receptionists.length}',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.brandTeal,
                ),
              ),
            ),
          ],
        ),
        Gap(AppTheme.spacing3),

        // Receptionists list or empty state
        if (receptionists.isEmpty)
          _buildGlassyContainer(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacing4),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20.sp,
                  ),
                  Gap(AppTheme.spacing2),
                  Expanded(
                    child: Text(
                      'No active receptionists yet',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(receptionists.length, (index) {
            final receptionist = receptionists[index];
            return _buildGlassyReceptionistCard(receptionist, userProvider);
          }),
      ],
    );
  }

  Widget _buildInvitesSection(UserProvider userProvider) {
    final clinicId = userProvider.connectedClinic?.id;
    if (clinicId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.mail_outline, color: Colors.white, size: 18.sp),
            Gap(AppTheme.spacing2),
            Text(
              'Pending Invites',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        Gap(AppTheme.spacing3),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('clinics')
              .doc(clinicId)
              .collection('invites')
              .where('role', isEqualTo: 'receptionist')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildGlassyContainer(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacing4),
                    child: SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildGlassyContainer(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacing4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppTheme.error,
                        size: 20.sp,
                      ),
                      Gap(AppTheme.spacing2),
                      Expanded(
                        child: Text(
                          'Error loading invites',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return _buildGlassyContainer(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacing4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 20.sp,
                      ),
                      Gap(AppTheme.spacing2),
                      Text(
                        'No pending invites',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final email = (data['email'] as String?) ?? '';
                final status = (data['status'] as String?) ?? 'pending';

                return _buildGlassyInviteCard(
                  email: email,
                  status: status,
                  userProvider: userProvider,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGlassyContainer({required Widget child}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildGlassyReceptionistCard(
    ClinicMember receptionist,
    UserProvider userProvider,
  ) {
    final isActive = receptionist.isActive;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isActive ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        border: Border.all(
          color: isActive
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.brandTeal.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.support_agent,
                color: isActive
                    ? AppTheme.brandTeal
                    : Colors.white.withValues(alpha: 0.5),
                size: 24.sp,
              ),
            ),
            Gap(12.w),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row
                  Row(
                    children: [
                      Expanded(
                        child:
                            FutureBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(receptionist.userId)
                                  .get(),
                              builder: (context, snapshot) {
                                String name = 'Receptionist';
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  final data = snapshot.data!.data();
                                  final displayName =
                                      data?['displayName'] as String?;
                                  final email = data?['email'] as String?;
                                  if (displayName != null &&
                                      displayName.isNotEmpty) {
                                    name = displayName;
                                  } else if (email != null &&
                                      email.isNotEmpty) {
                                    name = email;
                                  }
                                }
                                return Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                      ),
                      if (!isActive) ...[
                        Gap(8.w),
                        _buildStatusBadge('Inactive', AppTheme.error),
                      ],
                    ],
                  ),
                  Gap(6.h),
                  // Details row
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12.sp,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      Gap(4.w),
                      Text(
                        'Added ${_formatDate(receptionist.addedAt)}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Gap(8.w),
            // Actions
            _buildGlassyIconButton(
              icon: Icons.more_vert,
              onTap: () => _showReceptionistActions(receptionist, userProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassyInviteCard({
    required String email,
    required String status,
    required UserProvider userProvider,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.mark_email_unread_outlined,
                color: Colors.orange,
                size: 22.sp,
              ),
            ),
            Gap(12.w),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Gap(4.h),
                  Row(
                    children: [
                      _buildStatusBadge('Pending', Colors.orange),
                      Gap(8.w),
                      Text(
                        'Awaiting signup',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Gap(8.w),
            // Actions menu
            _buildGlassyIconButton(
              icon: Icons.more_vert,
              onTap: () => _showInviteActions(email, userProvider),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteActions(String email, UserProvider userProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: AppTheme.spacing4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Email header
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Gap(AppTheme.spacing4),
                _buildActionTile(
                  icon: Icons.send_outlined,
                  label: 'Resend Invite',
                  subtitle: 'Send password setup email again',
                  color: AppTheme.brandTeal,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _resendInvite(email, userProvider);
                  },
                ),
                Gap(AppTheme.spacing2),
                _buildActionTile(
                  icon: Icons.cancel_outlined,
                  label: 'Revoke Invite',
                  subtitle: 'Cancel this invitation',
                  color: AppTheme.error,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showRevokeInviteDialog(email, userProvider);
                  },
                ),
                Gap(AppTheme.spacing2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildGlassyIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    String? tooltip,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(
          icon,
          color: color ?? Colors.white.withValues(alpha: 0.7),
          size: 18.sp,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  void _showReceptionistActions(
    ClinicMember receptionist,
    UserProvider userProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: AppTheme.spacing4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Actions
                if (receptionist.isActive)
                  _buildActionTile(
                    icon: Icons.pause_circle_outline,
                    label: 'Deactivate',
                    subtitle: 'Temporarily disable access',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _toggleReceptionistStatus(receptionist, userProvider);
                    },
                  )
                else
                  _buildActionTile(
                    icon: Icons.play_circle_outline,
                    label: 'Activate',
                    subtitle: 'Restore access',
                    color: AppTheme.success,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _toggleReceptionistStatus(receptionist, userProvider);
                    },
                  ),
                Gap(AppTheme.spacing2),
                _buildActionTile(
                  icon: Icons.delete_outline,
                  label: 'Remove',
                  subtitle: 'Remove from clinic permanently',
                  color: AppTheme.error,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showRemoveReceptionistDialog(receptionist, userProvider);
                  },
                ),
                Gap(AppTheme.spacing2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacing3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            Gap(AppTheme.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _resendInvite(String email, UserProvider userProvider) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await userProvider.provisionAuthAccountAndSendReset(email);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Reset email sent to $email' : 'Could not send reset email',
          ),
          backgroundColor: ok ? AppTheme.success : Colors.orange,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showRevokeInviteDialog(String email, UserProvider userProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: AppTheme.spacing4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: EdgeInsets.all(AppTheme.spacing3),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius3),
                ),
                child: Icon(
                  Icons.cancel_outlined,
                  color: AppTheme.error,
                  size: 32.sp,
                ),
              ),
              Gap(AppTheme.spacing4),
              Text(
                'Revoke Invite',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Gap(AppTheme.spacing2),
              Text(
                'Revoke the invite for $email? They will not be able to join your clinic.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Gap(AppTheme.spacing4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacing3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius2),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  Gap(AppTheme.spacing3),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final ok = await userProvider
                              .revokeReceptionistInvite(email);
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Invite revoked'
                                    : 'Failed to revoke invite',
                              ),
                              backgroundColor: ok
                                  ? AppTheme.success
                                  : AppTheme.error,
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacing3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius2),
                        ),
                      ),
                      child: const Text('Revoke'),
                    ),
                  ),
                ],
              ),
              Gap(AppTheme.spacing2),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddReceptionistDialog(
    BuildContext context,
    UserProvider userProvider,
  ) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: EdgeInsets.only(bottom: AppTheme.spacing4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Add New Receptionist',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Gap(AppTheme.spacing2),
                  Text(
                    'Enter the email address of the receptionist you want to add.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  Gap(AppTheme.spacing4),
                  Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  Gap(AppTheme.spacing2),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'receptionist@example.com',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing3,
                          vertical: AppTheme.spacing3,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  ),
                  Gap(AppTheme.spacing4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacing3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius2,
                              ),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      Gap(AppTheme.spacing3),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(sheetContext);
                              await _addReceptionist(
                                emailController.text.trim(),
                                userProvider,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandTeal,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacing3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius2,
                              ),
                            ),
                          ),
                          child: const Text('Send Invite'),
                        ),
                      ),
                    ],
                  ),
                  Gap(AppTheme.spacing2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addReceptionist(String email, UserProvider userProvider) async {
    setState(() => _isLoading = true);

    try {
      final success = await userProvider.inviteReceptionistByEmail(email);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to $email'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        final errorMessage =
            userProvider.error ?? 'Failed to invite receptionist.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleReceptionistStatus(
    ClinicMember receptionist,
    UserProvider userProvider,
  ) async {
    try {
      final action = receptionist.isActive ? 'deactivated' : 'activated';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receptionist $action successfully'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showRemoveReceptionistDialog(
    ClinicMember receptionist,
    UserProvider userProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: AppTheme.spacing4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: EdgeInsets.all(AppTheme.spacing3),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius3),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.error,
                  size: 32.sp,
                ),
              ),
              Gap(AppTheme.spacing4),
              Text(
                'Remove Receptionist',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Gap(AppTheme.spacing2),
              Text(
                'Are you sure you want to remove this receptionist? They will lose access to all clinic features.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Gap(AppTheme.spacing4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacing3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius2),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  Gap(AppTheme.spacing3),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _removeReceptionist(receptionist, userProvider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacing3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius2),
                        ),
                      ),
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ),
              Gap(AppTheme.spacing2),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeReceptionist(
    ClinicMember receptionist,
    UserProvider userProvider,
  ) async {
    setState(() => _isLoading = true);

    try {
      final success = await userProvider.removeMemberFromClinic(
        receptionist.userId,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receptionist removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove receptionist: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
