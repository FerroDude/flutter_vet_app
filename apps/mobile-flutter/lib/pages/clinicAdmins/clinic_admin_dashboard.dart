import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

import '../../theme/app_theme.dart';
import '../vets/vet_management_page.dart';
import '../../main.dart' show ProfilePage, SettingsPage;

class ClinicAdminDashboard extends StatefulWidget {
  const ClinicAdminDashboard({super.key});

  @override
  State<ClinicAdminDashboard> createState() => _ClinicAdminDashboardState();
}

class _ClinicAdminDashboardState extends State<ClinicAdminDashboard> {
  @override
  void initState() {
    super.initState();
    // Post-frame ensure clinic is loaded once the widget has a context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      if (userProvider.isClinicAdmin) {
        userProvider.loadClinicIfMissing();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Only clinic admins can access this dashboard
        if (!userProvider.isClinicAdmin) {
          return const Scaffold(
            body: Center(
              child: Text('Access denied. Clinic admin privileges required.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Clinic Admin Dashboard'),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Profile',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfilePage(injectedUserProvider: userProvider),
                    ),
                  );
                },
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Text(
                    _getUserInitial(userProvider),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await userProvider.refresh();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClinicOverviewCard(userProvider),
                  const SizedBox(height: 24),
                  _buildQuickActionsSection(context, userProvider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClinicOverviewCard(UserProvider userProvider) {
    final connectedClinic = userProvider.connectedClinic;
    final hasClinicConnection =
        userProvider.currentUser?.connectedClinicId != null;

    if (connectedClinic == null) {
      if (hasClinicConnection) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: const [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Loading clinic info...'),
              ],
            ),
          ),
        );
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No Clinic Connected',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Please contact support to connect your clinic.'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: AppTheme.primaryBlue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    connectedClinic.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildClinicStatRow('Address', connectedClinic.address),
            _buildClinicStatRow('Phone', connectedClinic.phone),
            _buildClinicStatRow('Email', connectedClinic.email),
            _buildClinicStatRow(
              'Created',
              _formatDate(connectedClinic.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(
    BuildContext context,
    UserProvider userProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildQuickActions(context, userProvider),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, UserProvider userProvider) {
    final actionCards = _buildClinicAdminActions(context, userProvider);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.05,
      children: actionCards,
    );
  }

  List<Widget> _buildClinicAdminActions(
    BuildContext context,
    UserProvider userProvider,
  ) {
    return [
      _buildActionCard(
        icon: Icons.people,
        title: 'Manage Vets',
        subtitle: 'Invite and manage vets',
        color: AppTheme.primaryGreen,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider.value(
                value: userProvider,
                child: const VetManagementPage(),
              ),
            ),
          );
        },
      ),
      _buildActionCard(
        icon: Icons.analytics,
        title: 'Clinic Reports',
        subtitle: 'Track analytics',
        color: AppTheme.warningAmber,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clinic reports coming soon')),
          );
        },
      ),
      _buildActionCard(
        icon: Icons.people_outline,
        title: 'Pet Owners',
        subtitle: 'Connected owners',
        color: AppTheme.accentCoral,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet owner management coming soon')),
          );
        },
      ),
      _buildActionCard(
        icon: Icons.settings,
        title: 'Clinic Settings',
        subtitle: 'Clinic details',
        color: AppTheme.primaryBlue,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clinic settings coming soon')),
          );
        },
      ),
    ];
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getUserInitial(UserProvider userProvider) {
    final displayName = userProvider.currentUser?.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.substring(0, 1).toUpperCase();
    }

    final email = userProvider.currentUser?.email;
    if (email != null && email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }

    return 'C';
  }

  void _showClinicInfo(BuildContext context, UserProvider userProvider) {
    final clinic = userProvider.connectedClinic;

    if (clinic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No clinic information available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clinic.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Address', clinic.address),
            _buildInfoRow('Phone', clinic.phone),
            _buildInfoRow('Email', clinic.email),
            _buildInfoRow('Created', _formatDate(clinic.createdAt)),
            if (clinic.description?.isNotEmpty == true)
              _buildInfoRow('Description', clinic.description!),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
