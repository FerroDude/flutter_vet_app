import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/clinic_models.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

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
            appBar: AppBar(title: const Text('Vet Management')),
            body: const Center(
              child: Text('Access denied. Admin privileges required.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Vet Management'),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
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
    final vets = userProvider.clinicMembers;

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
                backgroundColor: AppTheme.primaryBlue,
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
            Icon(Icons.mail_outline, color: AppTheme.primaryBlue),
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
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.mark_email_unread),
                        title: Text(data['email'] ?? ''),
                        subtitle: Text(
                          'Status: ${data['status'] ?? 'pending'}',
                        ),
                        trailing: Text(
                          (data['role'] ?? 'vet').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
          backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
          child: const Icon(
            Icons.medical_services,
            color: AppTheme.primaryGreen,
          ),
        ),
        title: Text(
          'Vet Member', // TODO: Get actual vet name from UserProfile
          style: const TextStyle(fontWeight: FontWeight.w600),
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
                  color: Colors.red.withOpacity(0.1),
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
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit Permissions'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
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
      case 'edit':
        _showEditPermissionsDialog(vet, userProvider);
        break;
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
    final selectedPermissions = <String>{'appointments', 'chat'};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                  const SizedBox(height: 16),
                  const Text(
                    'Permissions',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ..._buildPermissionCheckboxes(selectedPermissions, setState),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _addVet(
                    emailController.text.trim(),
                    selectedPermissions.toList(),
                    userProvider,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Vet'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPermissionCheckboxes(
    Set<String> selectedPermissions,
    StateSetter setState,
  ) {
    final permissions = {
      'appointments': 'Manage Appointments',
      'chat': 'Chat with Pet Owners',
      'records': 'Access Medical Records',
      'reports': 'View Reports',
    };

    return permissions.entries.map((entry) {
      return CheckboxListTile(
        title: Text(entry.value),
        value: selectedPermissions.contains(entry.key),
        onChanged: (value) {
          setState(() {
            if (value == true) {
              selectedPermissions.add(entry.key);
            } else {
              selectedPermissions.remove(entry.key);
            }
          });
        },
        contentPadding: EdgeInsets.zero,
      );
    }).toList();
  }

  Future<void> _addVet(
    String email,
    List<String> permissions,
    UserProvider userProvider,
  ) async {
    setState(() => _isLoading = true);

    try {
      final success = await userProvider.inviteVetByEmail(email, permissions);

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

  void _showEditPermissionsDialog(ClinicMember vet, UserProvider userProvider) {
    final selectedPermissions = Set<String>.from(vet.permissions);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Permissions'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User ID: ${vet.userId}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Permissions',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._buildPermissionCheckboxes(selectedPermissions, setState),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateVetPermissions(
                  vet,
                  selectedPermissions.toList(),
                  userProvider,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateVetPermissions(
    ClinicMember vet,
    List<String> newPermissions,
    UserProvider userProvider,
  ) async {
    try {
      // TODO: Implement permission update
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissions updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update permissions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleVetStatus(
    ClinicMember vet,
    UserProvider userProvider,
  ) async {
    try {
      // TODO: Implement status toggle
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
