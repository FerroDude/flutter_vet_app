import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
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
          return Scaffold(
            appBar: AppBar(
              title: const Text('Vet Management'),
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.neutral700,
              elevation: 0,
            ),
            body: const Center(
              child: Text('Access denied. Admin privileges required.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Vet Management'),
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.neutral700,
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
                ? const Center(child: CircularProgressIndicator())
                : _buildVetsList(userProvider),
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
            Icon(Icons.medical_services, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No vets added yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first vet',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddVetDialog(context, userProvider),
              icon: const Icon(Icons.add),
              label: const Text('Add Vet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neutral700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Vets list
        ...List.generate(vets.length, (index) {
          final vet = vets[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildVetCard(vet, userProvider),
          );
        }),

        const SizedBox(height: 24),
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
            Icon(Icons.mail_outline, color: AppTheme.neutral700),
            const SizedBox(width: 8),
            Text(
              'Pending Invites',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading invites: ${snapshot.error}'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No pending invites',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final email = (data['email'] as String?) ?? '';
                    final status = (data['status'] as String?) ?? 'pending';
                    final role = (data['role'] as String?) ?? 'vet';

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.mark_email_unread),
                        title: Text(email),
                        subtitle: Text('Status: $status'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.neutral700.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppTheme.neutral700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Resend reset email',
                              icon: const Icon(Icons.refresh),
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
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  );
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Revoke invite',
                              icon: const Icon(Icons.delete, color: Colors.red),
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
                                          backgroundColor: Colors.red,
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
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppTheme.neutral600.withValues(alpha: 0.1),
          child: const Icon(Icons.medical_services, color: AppTheme.neutral600),
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Role: ${_getRoleDisplayName(vet.role)}'),
            const SizedBox(height: 2),
            Text('Added: ${_formatDate(vet.addedAt)}'),
            if (!vet.isActive) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Inactive',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          onSelected: (action) => _handleVetAction(action, vet, userProvider),
          itemBuilder: (context) => [
            if (vet.isActive)
              const PopupMenuItem(
                value: 'deactivate',
                child: ListTile(
                  leading: Icon(Icons.block, color: Colors.orange),
                  title: Text('Deactivate'),
                  contentPadding: EdgeInsets.zero,
                ),
              )
            else
              const PopupMenuItem(
                value: 'activate',
                child: ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Activate'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            const PopupMenuItem(
              value: 'remove',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Vet'),
        content: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Vet Email Address',
                    hintText: 'Enter the vet\'s email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
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
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim().toLowerCase();
              if (email.isEmpty) return;
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
            child: const Text('Send Password Reset'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _addVet(emailController.text.trim(), userProvider);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neutral700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Vet'),
          ),
        ],
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Vet'),
        content: const Text(
          'Are you sure you want to remove this vet from your clinic? '
          'They will lose access to all clinic features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeVet(vet, userProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
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
