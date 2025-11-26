import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../models/clinic_models.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';

class VetManagementPage extends StatefulWidget {
  const VetManagementPage({super.key});

  @override
  State<VetManagementPage> createState() => _VetManagementPageState();
}

class _VetManagementPageState extends State<VetManagementPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (!userProvider.canManageVets) {
          return Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text(
                  'Vet Management',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                'Vet Management',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: () => _showAddVetDialog(context, userProvider),
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
                  : _buildVetsList(userProvider),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVetsList(UserProvider userProvider) {
    final vets = userProvider.clinicMembers
        .where((m) => m.role == ClinicRole.vet)
        .toList();

    if (vets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services,
              size: 64.sp,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            Gap(AppTheme.spacing4),
            Text(
              'No vets added yet',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Gap(AppTheme.spacing2),
            Text(
              'Tap the + button to add your first vet',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            Gap(AppTheme.spacing6),
            ElevatedButton.icon(
              onPressed: () => _showAddVetDialog(context, userProvider),
              icon: const Icon(Icons.add),
              label: const Text('Add Vet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing4,
                  vertical: AppTheme.spacing3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius2),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(AppTheme.spacing4),
      children: [
        // Vets list
        ...List.generate(vets.length, (index) {
          final vet = vets[index];
          return Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacing2),
            child: _buildVetCard(vet, userProvider),
          );
        }),

        Gap(AppTheme.spacing6),
        // Pending invites section
        _buildInvitesSection(userProvider),
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
            Icon(Icons.mail_outline, color: Colors.white),
            Gap(AppTheme.spacing2),
            Text(
              'Pending Invites',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder:
              (
                context,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: EdgeInsets.all(AppTheme.spacing4),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: EdgeInsets.all(AppTheme.spacing4),
                    child: Text(
                      'Error loading invites: ${snapshot.error}',
                      style: TextStyle(color: AppTheme.error),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(AppTheme.spacing4),
                    child: Text(
                      'No pending invites',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final email = (data['email'] as String?) ?? '';
                    final status = (data['status'] as String?) ?? 'pending';
                    final role = (data['role'] as String?) ?? 'vet';

                    return Container(
                      margin: EdgeInsets.only(bottom: AppTheme.spacing2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radius3),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing4,
                          vertical: AppTheme.spacing2,
                        ),
                        leading: Icon(Icons.mark_email_unread, color: AppTheme.primary),
                        title: Text(
                          email,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primary,
                          ),
                        ),
                        subtitle: Text(
                          'Status: $status',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.neutral700,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing2,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.sp,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Resend reset email',
                              icon: Icon(Icons.refresh, color: AppTheme.primary, size: 20.sp),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final ok = await userProvider
                                      .provisionAuthAccountAndSendReset(email);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Reset email sent to $email'
                                            : 'Could not send reset email',
                                      ),
                                      backgroundColor: ok
                                          ? AppTheme.success
                                          : Colors.orange,
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
                            ),
                            IconButton(
                              tooltip: 'Revoke invite',
                              icon: Icon(Icons.delete, color: AppTheme.error, size: 20.sp),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Revoke Invite'),
                                    content: Text(
                                      'Revoke the invite for $email? This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.error,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Revoke'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  if (!context.mounted) return;
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    final ok = await userProvider
                                        .revokeVetInvite(email);
                                    if (!context.mounted) return;
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
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
        ),
      ],
    );
  }

  Widget _buildVetCard(ClinicMember vet, UserProvider userProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(AppTheme.spacing4),
        leading: CircleAvatar(
          backgroundColor: AppTheme.brandTeal.withValues(alpha: 0.1),
          child: Icon(Icons.medical_services, color: AppTheme.brandTeal),
        ),
        title: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(vet.userId)
              .get(),
          builder: (context, snapshot) {
            String name = 'Vet Member';
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data();
              final displayName = data?['displayName'] as String?;
              final email = data?['email'] as String?;
              if (displayName != null && displayName.isNotEmpty) {
                name = displayName;
              } else if (email != null && email.isNotEmpty) {
                name = email;
              }
            }
            return Text(
              name,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Gap(AppTheme.spacing1),
            Text(
              'Role: ${_getRoleDisplayName(vet.role)}',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.neutral700,
              ),
            ),
            Gap(2),
            Text(
              'Added: ${_formatDate(vet.addedAt)}',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.neutral700,
              ),
            ),
            if (!vet.isActive) ...[
              Gap(AppTheme.spacing1),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Inactive',
                  style: TextStyle(
                    color: AppTheme.error,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, color: AppTheme.neutral700),
          onSelected: (action) => _handleVetAction(action, vet, userProvider),
          itemBuilder: (context) => [
            if (vet.isActive)
              PopupMenuItem(
                value: 'deactivate',
                child: ListTile(
                  leading: Icon(Icons.block, color: Colors.orange),
                  title: Text('Deactivate'),
                  contentPadding: EdgeInsets.zero,
                ),
              )
            else
              PopupMenuItem(
                value: 'activate',
                child: ListTile(
                  leading: Icon(Icons.check_circle, color: AppTheme.success),
                  title: Text('Activate'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            PopupMenuItem(
              value: 'remove',
              child: ListTile(
                leading: Icon(Icons.delete, color: AppTheme.error),
                title: Text('Remove'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplayName(ClinicRole role) {
    switch (role) {
      case ClinicRole.admin:
        return 'Administrator';
      case ClinicRole.vet:
        return 'Veterinarian';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleVetAction(
    String action,
    ClinicMember vet,
    UserProvider userProvider,
  ) {
    switch (action) {
      case 'activate':
      case 'deactivate':
        _toggleVetStatus(vet, userProvider);
        break;
      case 'remove':
        _showRemoveVetDialog(vet, userProvider);
        break;
    }
  }

  void _showAddVetDialog(BuildContext context, UserProvider userProvider) {
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
                  // Handle bar
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
                  
                  // Title
                  Text(
                    'Add New Vet',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Gap(AppTheme.spacing2),
                  Text(
                    'Enter the email address of the vet you want to add to your clinic.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  Gap(AppTheme.spacing4),
                  
                  // Email label
                  Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  Gap(AppTheme.spacing2),
                  
                  // Email input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: AppTheme.primary),
                      decoration: InputDecoration(
                        hintText: 'vet@example.com',
                        hintStyle: TextStyle(color: AppTheme.neutral400),
                        prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
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
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
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
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(sheetContext);
                              await _addVet(emailController.text.trim(), userProvider);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primary,
                            padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radius2),
                            ),
                          ),
                          child: const Text('Add Vet'),
                        ),
                      ),
                    ],
                  ),
                  
                  Gap(AppTheme.spacing3),
                  
                  // Password reset option
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        final email = emailController.text.trim().toLowerCase();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter an email address first'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        try {
                          final ok = await userProvider.provisionAuthAccountAndSendReset(
                            email,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Password setup email sent to $email.'
                                      : 'Could not send password setup email to $email.',
                                ),
                                backgroundColor: ok ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to send reset email: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        Icons.lock_reset,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 18,
                      ),
                      label: Text(
                        'Send Password Reset Email',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
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

  Future<void> _addVet(String email, UserProvider userProvider) async {
    setState(() => _isLoading = true);

    try {
      // Vets always have full access - no permissions tracking needed
      final success = await userProvider.inviteVetByEmail(email);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invitation recorded for $email. Ask them to sign up with this email to access the clinic.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorMessage = userProvider.error ?? 'Failed to invite vet.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleVetStatus(
    ClinicMember vet,
    UserProvider userProvider,
  ) async {
    try {
      // missing: Implement status toggle
      final action = vet.isActive ? 'deactivated' : 'activated';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vet $action successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update vet status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRemoveVetDialog(ClinicMember vet, UserProvider userProvider) {
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
              
              // Warning icon
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
              
              // Title
              Text(
                'Remove Vet',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Gap(AppTheme.spacing2),
              
              // Message
              Text(
                'Are you sure you want to remove this vet from your clinic? '
                'They will lose access to all clinic features.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Gap(AppTheme.spacing4),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
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
                        _removeVet(vet, userProvider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
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

  Future<void> _removeVet(ClinicMember vet, UserProvider userProvider) async {
    setState(() => _isLoading = true);

    try {
      final success = await userProvider.removeMemberFromClinic(vet.userId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vet removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove vet: $e'),
            backgroundColor: Colors.red,
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
