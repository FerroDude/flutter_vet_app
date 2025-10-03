import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../providers/user_provider.dart';
import '../models/clinic_models.dart';
import '../theme/app_theme.dart';
import 'vet_management_page.dart';
import 'app_owner_stats.dart';
import '../main.dart' show ProfilePage;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Only app owners can access this dashboard
        if (!userProvider.isAppOwner) {
          return const Scaffold(
            body: Center(
              child: Text('Access denied. App owner privileges required.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('App Owner Dashboard'),
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.85),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => _showAllClinicsDialog(context),
                icon: const Icon(Icons.search),
                tooltip: 'Search Clinics',
              ),
              IconButton(
                onPressed: () => _showAppSettings(context),
                icon: const Icon(Icons.settings),
                tooltip: 'App Settings',
              ),
              IconButton(
                onPressed: () => _navigateToProfile(),
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
                tooltip: 'Profile',
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildActionsPage(context, userProvider),
              _buildStatsPage(context, userProvider),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.primaryBlue,
            unselectedItemColor: Colors.grey[600],
            backgroundColor: Colors.white,
            elevation: 8,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Actions',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics),
                label: 'Statistics',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionsPage(BuildContext context, UserProvider userProvider) {
    return RefreshIndicator(
      onRefresh: () async => await userProvider.refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced System Overview Card
            _buildEnhancedOverviewCard(userProvider),

            const SizedBox(height: 32),

            // Quick Actions
            Row(
              children: [
                Icon(Icons.flash_on, color: AppTheme.primaryBlue, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildImprovedQuickActions(context, userProvider),

            const SizedBox(height: 24),

            // Clinic Admins Section
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: AppTheme.accentCoral,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Clinic Admins',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentCoral,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildClinicAdminsSection(),

            const SizedBox(height: 24),

            // Quick Stats Preview
            Row(
              children: [
                Icon(Icons.trending_up, color: AppTheme.primaryGreen, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Overview',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildQuickStats(userProvider),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsPage(BuildContext context, UserProvider userProvider) {
    return RefreshIndicator(
      onRefresh: () async => await userProvider.refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Detailed Statistics Header
            Row(
              children: [
                Icon(Icons.analytics, color: AppTheme.warningAmber, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Analytics',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningAmber,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChangeNotifierProvider.value(
                          value: userProvider,
                          child: const AppOwnerStats(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Full Report'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Clinic Statistics
            _buildDetailedClinicStats(userProvider),

            const SizedBox(height: 24),

            // User Statistics
            _buildDetailedUserStats(),

            const SizedBox(height: 24),

            // Recent Activity
            _buildEnhancedRecentActivity(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAppOwnerActions(
    BuildContext context,
    UserProvider userProvider,
  ) {
    return [
      _buildActionCard(
        icon: Icons.add_business,
        title: 'Create Clinic',
        color: AppTheme.primaryBlue,
        onTap: () {
          developer.log('Create Clinic button tapped!', name: 'AdminDashboard');
          _showCreateClinicAdminDialog(context);
        },
      ),
      _buildActionCard(
        icon: Icons.business,
        title: 'Manage Clinics',
        color: AppTheme.primaryGreen,
        onTap: () => _showAllClinicsDialog(context),
      ),
      _buildActionCard(
        icon: Icons.analytics,
        title: 'Analytics',
        color: AppTheme.warningAmber,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider.value(
                value: userProvider,
                child: const AppOwnerStats(),
              ),
            ),
          );
        },
      ),
      _buildActionCard(
        icon: Icons.people_alt,
        title: 'Manage Vets',
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
    ];
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 6,
      shadowColor: color.withOpacity(0.3),
      color: isDark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.10), color.withOpacity(0.05)],
          ),
          border: Border.all(
            color: (isDark ? Colors.grey[700]! : Colors.grey[200]!).withOpacity(
              0.9,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced App Owner overview card with blue theme
  Widget _buildEnhancedOverviewCard(UserProvider userProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clinicsQuery = _clinicsQuery(userProvider, includeInactive: true);

    return Card(
      elevation: 8,
      shadowColor: AppTheme.primaryBlue.withOpacity(0.3),
      color: isDark ? Colors.grey[900] : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryBlue.withOpacity(0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PetOn Platform',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            StreamBuilder<QuerySnapshot>(
              stream: clinicsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildEnhancedOverviewStat(
                          'Total Clinics',
                          '!',
                          Icons.business,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildEnhancedOverviewStat(
                          'Active Clinics',
                          '!',
                          Icons.check_circle,
                        ),
                      ),
                    ],
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    docs.isEmpty;

                final totalClinics = docs.length;
                final activeClinics = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isActive'] == true;
                }).length;

                final totalLabel = isLoading ? '...' : totalClinics.toString();
                final activeLabel = isLoading
                    ? '...'
                    : activeClinics.toString();

                return Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedOverviewStat(
                        'Total Clinics',
                        totalLabel,
                        Icons.business,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildEnhancedOverviewStat(
                        'Active Clinics',
                        activeLabel,
                        Icons.check_circle,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedOverviewStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Get user initial for avatar
  String _getUserInitial(UserProvider userProvider) {
    final displayName = userProvider.currentUser?.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.substring(0, 1).toUpperCase();
    }
    return 'A';
  }

  // Format date helper method
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // App Owner specific methods
  void _showCreateClinicAdminDialog(BuildContext context) {
    developer.log(
      'Opening Create Clinic Admin dialog...',
      name: 'AdminDashboard',
    );
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: userProvider,
        child: const _CreateClinicAdminDialog(),
      ),
    );
  }

  void _showAppSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App settings will be implemented here.'),
            SizedBox(height: 16),
            Text('Features to come:'),
            Text('• Email notification preferences'),
            Text('• Theme customization'),
            Text('• Data export settings'),
            Text('• System configuration'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile() {
    // Navigate to the same ProfilePage that normal users use
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }

  // Temporary method to fix clinic admin linking
  void _showCheckClinicDialog(BuildContext context) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check Clinic Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter an email to check if there\'s a clinic admin profile for it:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'e.g., thisissarahbuckley@gmail.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(context);
                await _checkClinicStatus(context, email);
              }
            },
            child: const Text('Check'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkClinicStatus(BuildContext context, String email) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Checking clinic status...'),
          ],
        ),
      ),
    );

    try {
      // Add timeout to prevent infinite loading
      final timeout = Future.delayed(const Duration(seconds: 10));

      // Check for clinics with this email
      final clinicQueryFuture = FirebaseFirestore.instance
          .collection('clinics')
          .where('email', isEqualTo: email)
          .get();

      // Check for temporary admin profile
      final tempAdminId =
          'temp_admin_${email.replaceAll('@', '_').replaceAll('.', '_')}';
      final tempAdminQueryFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(tempAdminId)
          .get();

      // Check for regular user profile
      final userQueryFuture = FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      // Wait for all queries with timeout
      final results =
          await Future.wait([
            clinicQueryFuture,
            tempAdminQueryFuture,
            userQueryFuture,
          ]).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Query timeout - please try again');
            },
          );

      final clinicQuery = results[0] as QuerySnapshot;
      final tempAdminQuery = results[1] as DocumentSnapshot;
      final userQuery = results[2] as QuerySnapshot;

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show results
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Clinic Status for $email'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 Clinics found: ${clinicQuery.docs.length}'),
                  if (clinicQuery.docs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...clinicQuery.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Text('   • ${data['name']} (ID: ${doc.id})');
                    }).toList(),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '👤 Temporary admin profile: ${tempAdminQuery.exists ? 'Found' : 'Not found'}',
                  ),
                  if (tempAdminQuery.exists) ...[Text('   • ID: $tempAdminId')],
                  const SizedBox(height: 8),
                  Text(
                    '👤 Regular user profile: ${userQuery.docs.isNotEmpty ? 'Found' : 'Not found'}',
                  ),
                  if (userQuery.docs.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final userData =
                            userQuery.docs.first.data() as Map<String, dynamic>;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('   • User Type: ${userData['userType']}'),
                            Text(
                              '   • Connected Clinic: ${userData['connectedClinicId'] ?? 'None'}',
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
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
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking clinic status: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showAdminManagementDialog(BuildContext context) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.purple),
            const SizedBox(width: 8),
            const Text('Admin Management Tools'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter an email to manage admin status:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'e.g., thisissarahbuckley@gmail.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final email = emailController.text.trim();
                      if (email.isNotEmpty) {
                        Navigator.pop(context);
                        await _checkAndFixAdminStatus(context, email);
                      }
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Check Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final email = emailController.text.trim();
                      if (email.isNotEmpty) {
                        Navigator.pop(context);
                        await _forceUpdateAdminStatus(context, email);
                      }
                    },
                    icon: const Icon(Icons.update),
                    label: const Text('Force Update'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Temporarily commented out - will fix syntax error
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton.icon(
            //     onPressed: () {
            //       Navigator.pop(context);
            //       _showCreateClinicDialog(context);
            //     },
            //     icon: const Icon(Icons.add_business),
            //     label: const Text('Create New Clinic'),
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: Colors.green,
            //       foregroundColor: Colors.white,
            //     ),
            //   ),
            // ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndFixAdminStatus(
    BuildContext context,
    String email,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Checking admin status...'),
          ],
        ),
      ),
    );

    try {
      // Add timeout to prevent infinite loading
      final userQueryFuture = FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      final clinicQueryFuture = FirebaseFirestore.instance
          .collection('clinics')
          .where('email', isEqualTo: email)
          .get();

      // Wait for queries with timeout
      final results = await Future.wait([userQueryFuture, clinicQueryFuture])
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Query timeout - please try again');
            },
          );

      final userQuery = results[0] as QuerySnapshot;
      final clinicQuery = results[1] as QuerySnapshot;

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (userQuery.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No user found with email: $email'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;
      final userId = userDoc.id;

      // Show current status
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Admin Status for $email'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('👤 User ID: $userId'),
                  Text('👤 User Type: ${userData['userType']}'),
                  Text(
                    '👤 Connected Clinic: ${userData['connectedClinicId'] ?? 'None'}',
                  ),
                  Text('👤 Clinic Role: ${userData['clinicRole'] ?? 'None'}'),
                  const SizedBox(height: 8),
                  Text('📋 Clinics found: ${clinicQuery.docs.length}'),
                  if (clinicQuery.docs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...clinicQuery.docs.map((doc) {
                      final clinicData = doc.data() as Map<String, dynamic>;
                      return Text('   • ${clinicData['name']} (ID: ${doc.id})');
                    }).toList(),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💡 Analysis:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (userData['userType'] == 2) ...[
                          const Text('✅ User is already a clinic admin'),
                          if (userData['connectedClinicId'] != null)
                            const Text('✅ User is connected to a clinic'),
                          if (clinicQuery.docs.isNotEmpty)
                            const Text('✅ Clinic exists for this email'),
                        ] else ...[
                          const Text('❌ User is not a clinic admin'),
                          if (clinicQuery.docs.isNotEmpty)
                            const Text('💡 Clinic exists - can be linked'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (userData['userType'] != 2 && clinicQuery.docs.isNotEmpty)
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _linkUserToClinic(
                      context,
                      userId,
                      clinicQuery.docs.first.id,
                      email,
                    );
                  },
                  child: const Text('Link to Clinic'),
                ),
              if (userData['userType'] == 2 && userData['clinicRole'] == 0)
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _fixClinicRole(context, userId, email);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Fix Clinic Role'),
                ),
              if (userData['userType'] == 2)
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _deleteClinicAndAdmin(context, userId, email);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete Clinic & Admin'),
                ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking admin status: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _linkUserToClinic(
    BuildContext context,
    String userId,
    String clinicId,
    String email,
  ) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Linking user to clinic...'),
            ],
          ),
        ),
      );

      // Update user to be clinic admin
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'userType': 2, // Clinic Admin
        'connectedClinicId': clinicId,
        'clinicRole': 1, // Admin role
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully linked $email to clinic as admin!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error linking user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fixClinicRole(
    BuildContext context,
    String userId,
    String email,
  ) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Fixing clinic role...'),
            ],
          ),
        ),
      );

      // Update clinic role to admin
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'clinicRole': 1, // Set to admin role
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully fixed clinic role for $email'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error fixing clinic role: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _deleteClinicAndAdmin(
    BuildContext context,
    String userId,
    String email,
  ) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting clinic and admin...'),
            ],
          ),
        ),
      );

      // Get user data to find connected clinic
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>;
      final connectedClinicId = userData['connectedClinicId'];

      // Delete the clinic if it exists
      if (connectedClinicId != null) {
        await FirebaseFirestore.instance
            .collection('clinics')
            .doc(connectedClinicId)
            .delete();
      }

      // Reset user to regular user
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'userType': 0, // Regular user
        'connectedClinicId': null,
        'clinicRole': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Successfully deleted clinic and reset $email to regular user',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting clinic: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _forceUpdateAdminStatus(
    BuildContext context,
    String email,
  ) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Force updating admin status...'),
            ],
          ),
        ),
      );

      // Find user by email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No user found with email: $email'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final userDoc = userQuery.docs.first;
      final userId = userDoc.id;

      // Force update to clinic admin
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'userType': 2, // Clinic Admin
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Force updated $email to clinic admin status!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error force updating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFixClinicAdminDialog(
    BuildContext context,
    UserProvider userProvider,
  ) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Clinic Admin Linking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'If you signed up with a clinic admin email but got a regular user profile, '
              'enter the email address to fix the linking:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'e.g., thisissarahbuckley@gmail.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(context);

                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Fixing clinic admin linking...'),
                      ],
                    ),
                  ),
                );

                final success = await userProvider.fixClinicAdminLinking(email);

                Navigator.pop(context); // Close loading dialog

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Successfully linked to clinic! Please restart the app.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No clinic admin profile found for this email.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            child: const Text('Fix Linking'),
          ),
        ],
      ),
    );
  }

  void _handleProfileAction(String action, UserProvider userProvider) {
    switch (action) {
      case 'profile':
        // Navigate to the same ProfilePage that normal users use
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        );
        break;
      case 'logout':
        _showLogoutDialog(context, userProvider);
        break;
    }
  }

  void _showLogoutDialog(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement logout functionality
              developer.log('Logout requested', name: 'AdminDashboard');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAllClinicsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AllClinicsDialog(),
    );
  }

  // Enhanced UI Methods

  Widget _buildImprovedQuickActions(
    BuildContext context,
    UserProvider userProvider,
  ) {
    final actionCards = _buildAppOwnerActions(context, userProvider);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 1.1,
      children: actionCards,
    );
  }

  Widget _buildQuickStats(UserProvider userProvider) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _clinicsQuery(
            userProvider,
            includeInactive: true,
          ).snapshots(),
          builder: (context, clinicSnapshot) {
            final totalUsers = userSnapshot.data?.docs.length ?? 0;
            final clinicDocs = clinicSnapshot.data?.docs ?? [];
            final activeClinics = clinicDocs
                .where(
                  (doc) =>
                      (doc.data() as Map<String, dynamic>)['isActive'] == true,
                )
                .length;

            return Row(
              children: [
                Expanded(
                  child: _buildQuickStatCard(
                    'Users',
                    totalUsers.toString(),
                    Icons.people,
                    AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickStatCard(
                    'Clinics',
                    activeClinics.toString(),
                    Icons.business,
                    AppTheme.primaryBlue,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedClinicStats(UserProvider userProvider) {
    return StreamBuilder<QuerySnapshot>(
      stream: _clinicsQuery(userProvider, includeInactive: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Unable to load clinic statistics.'),
            ),
          );
        }

        final clinics = snapshot.data?.docs ?? [];
        final totalClinics = clinics.length;
        final activeClinics = clinics
            .where(
              (doc) => (doc.data() as Map<String, dynamic>)['isActive'] == true,
            )
            .length;
        final inactiveClinics = totalClinics - activeClinics;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.business,
                      color: AppTheme.primaryGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Clinics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.1,
                  children: [
                    _buildStatCard(
                      title: 'Total',
                      value: totalClinics.toString(),
                      icon: Icons.business,
                      color: AppTheme.primaryBlue,
                    ),
                    _buildStatCard(
                      title: 'Active',
                      value: activeClinics.toString(),
                      icon: Icons.check_circle,
                      color: AppTheme.primaryGreen,
                    ),
                    _buildStatCard(
                      title: 'Inactive',
                      value: inactiveClinics.toString(),
                      icon: Icons.pause_circle,
                      color: AppTheme.warningAmber,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Query<Map<String, dynamic>> _clinicsQuery(
    UserProvider userProvider, {
    bool includeInactive = false,
  }) {
    final base = FirebaseFirestore.instance.collection('clinics');
    if (includeInactive && userProvider.isAppOwner) {
      return base;
    }
    return base.where('isActive', isEqualTo: true);
  }

  Widget _buildDetailedUserStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?.docs ?? [];
        final totalUsers = users.length;

        final petOwners = users.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          return userData['userType'] == 0;
        }).length;

        final vets = users.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          return userData['userType'] == 1;
        }).length;

        final clinicAdmins = users.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          return userData['userType'] == 2;
        }).length;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: AppTheme.primaryBlue, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Users',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    _buildStatCard(
                      title: 'Users',
                      value: totalUsers.toString(),
                      icon: Icons.people,
                      color: AppTheme.primaryBlue,
                    ),
                    _buildStatCard(
                      title: 'Owners',
                      value: petOwners.toString(),
                      icon: Icons.pets,
                      color: AppTheme.primaryGreen,
                    ),
                    _buildStatCard(
                      title: 'Vets',
                      value: vets.toString(),
                      icon: Icons.medical_services,
                      color: AppTheme.warningAmber,
                    ),
                    _buildStatCard(
                      title: 'Admins',
                      value: clinicAdmins.toString(),
                      icon: Icons.admin_panel_settings,
                      color: AppTheme.accentCoral,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedRecentActivity() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: AppTheme.accentCoral, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentCoral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clinics')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final recentClinics = snapshot.data?.docs ?? [];

                if (recentClinics.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.timeline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No activity',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentClinics.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final clinicData =
                        recentClinics[index].data() as Map<String, dynamic>;
                    final clinic = Clinic.fromJson(
                      clinicData,
                      recentClinics[index].id,
                    );

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.business,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        clinic.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Registered',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: Text(
                        _formatDate(clinic.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicAdminsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clinics')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final clinics = snapshot.data?.docs ?? [];

        if (clinics.isEmpty) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.business, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Clinics Found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No clinics have been created yet.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: clinics.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final clinicData = clinics[index].data() as Map<String, dynamic>;
            final clinic = Clinic.fromJson(clinicData, clinics[index].id);

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: clinic.isActive
                      ? AppTheme.primaryGreen
                      : Colors.grey,
                  child: const Icon(Icons.business, color: Colors.white),
                ),
                title: Text(
                  clinic.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clinic.email),
                    const SizedBox(height: 4),
                    // Show admin information
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .where('connectedClinicId', isEqualTo: clinic.id)
                          .where('userType', isEqualTo: 2) // Clinic Admin
                          .get(),
                      builder: (context, adminsSnapshot) {
                        if (adminsSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text(
                            'Loading admins...',
                            style: TextStyle(fontSize: 12),
                          );
                        }

                        if (adminsSnapshot.hasError ||
                            !adminsSnapshot.hasData) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Error loading admins',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }

                        final admins = adminsSnapshot.data!.docs;

                        if (admins.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'No admins found',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Show primary admin (the one in clinic.adminId)
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(clinic.adminId)
                                  .get(),
                              builder: (context, primaryAdminSnapshot) {
                                if (primaryAdminSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Text(
                                    'Loading primary admin...',
                                    style: TextStyle(fontSize: 12),
                                  );
                                }

                                if (primaryAdminSnapshot.hasError ||
                                    !primaryAdminSnapshot.hasData ||
                                    !primaryAdminSnapshot.data!.exists) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Primary admin not found',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }

                                final primaryAdminData =
                                    primaryAdminSnapshot.data!.data()
                                        as Map<String, dynamic>?;
                                final primaryAdminName =
                                    primaryAdminData?['displayName'] ??
                                    'Unknown Admin';
                                final primaryAdminEmail =
                                    primaryAdminData?['email'] ?? 'No email';

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Primary: $primaryAdminName',
                                        style: TextStyle(
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      primaryAdminEmail,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            // Show additional admins if any
                            if (admins.length > 1) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${admins.length - 1} additional admin${admins.length > 2 ? 's' : ''}',
                                  style: TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: clinic.isActive
                                    ? Colors.green[100]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                clinic.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  color: clinic.isActive
                                      ? Colors.green[700]
                                      : Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Text(clinic.isActive ? 'Deactivate' : 'Activate'),
                    ),
                    const PopupMenuItem(
                      value: 'view_details',
                      child: Text('View Details'),
                    ),
                    const PopupMenuItem(
                      value: 'view_admin',
                      child: Text('View Admin'),
                    ),
                  ],
                  onSelected: (value) =>
                      _handleClinicAction(context, clinic, value.toString()),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleClinicAction(
    BuildContext context,
    Clinic clinic,
    String action,
  ) async {
    try {
      switch (action) {
        case 'toggle_status':
          await FirebaseFirestore.instance
              .collection('clinics')
              .doc(clinic.id)
              .update({
                'isActive': !clinic.isActive,
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  clinic.isActive ? 'Clinic deactivated' : 'Clinic activated',
                ),
              ),
            );
          }
          break;

        case 'view_details':
          _showClinicDetails(context, clinic);
          break;
        case 'view_admin':
          _showAdminDetails(context, clinic);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showClinicDetails(BuildContext context, Clinic clinic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.business, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Text(clinic.name),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Address', clinic.address),
            _buildDetailRow('Phone', clinic.phone),
            _buildDetailRow('Email', clinic.email),
            _buildDetailRow('Status', clinic.isActive ? 'Active' : 'Inactive'),
            _buildDetailRow('Created', _formatDate(clinic.createdAt)),
            if (clinic.website != null)
              _buildDetailRow('Website', clinic.website!),
            if (clinic.description != null)
              _buildDetailRow('Description', clinic.description!),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showAdminDetails(BuildContext context, Clinic clinic) async {
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(clinic.adminId)
          .get();

      if (!context.mounted) return;

      if (!adminDoc.exists) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Admin Not Found'),
            content: const Text(
              'The admin for this clinic could not be found.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      final adminData = adminDoc.data() as Map<String, dynamic>;
      final adminName = adminData['displayName'] ?? 'Unknown Admin';
      final adminEmail = adminData['email'] ?? 'No email';
      final adminPhone = adminData['phone'] ?? 'No phone';
      final adminAddress = adminData['address'] ?? 'No address';
      final userType = adminData['userType'] ?? 0;
      final createdAt = adminData['createdAt'];
      final isActive = adminData['isActive'] ?? true;

      String userTypeText;
      switch (userType) {
        case 0:
          userTypeText = 'Pet Owner';
          break;
        case 1:
          userTypeText = 'Vet';
          break;
        case 2:
          userTypeText = 'Clinic Admin';
          break;
        case 3:
          userTypeText = 'App Owner';
          break;
        default:
          userTypeText = 'Unknown';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text('Admin Details'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Name', adminName),
              _buildDetailRow('Email', adminEmail),
              _buildDetailRow('Phone', adminPhone),
              _buildDetailRow('Address', adminAddress),
              _buildDetailRow('User Type', userTypeText),
              _buildDetailRow('Status', isActive ? 'Active' : 'Inactive'),
              if (createdAt != null)
                _buildDetailRow(
                  'Created',
                  _formatDate(DateTime.fromMillisecondsSinceEpoch(createdAt)),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Managing Clinic:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(clinic.name),
                    Text(clinic.email),
                  ],
                ),
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading admin details: $e')),
        );
      }
    }
  }
}

/// Dialog for app owners to create clinic admin accounts
class _CreateClinicAdminDialog extends StatefulWidget {
  const _CreateClinicAdminDialog();

  @override
  State<_CreateClinicAdminDialog> createState() =>
      _CreateClinicAdminDialogState();
}

class _CreateClinicAdminDialogState extends State<_CreateClinicAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _clinicNameController = TextEditingController();
  final _clinicAddressController = TextEditingController();
  final _clinicPhoneController = TextEditingController();
  final _clinicEmailController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _useAdminEmailForClinic = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Clinic Admin'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clinic Information
                const Text(
                  'Clinic Information',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _clinicNameController,
                  decoration: const InputDecoration(
                    labelText: 'Clinic Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _clinicAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _clinicPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Email Options
                CheckboxListTile(
                  title: const Text('Use admin email as clinic contact email'),
                  subtitle: const Text(
                    'Admin email will be used for both login and business contact',
                  ),
                  value: _useAdminEmailForClinic,
                  onChanged: (value) {
                    setState(() {
                      _useAdminEmailForClinic = value ?? true;
                      if (_useAdminEmailForClinic) {
                        _clinicEmailController.clear();
                      }
                    });
                  },
                ),

                if (!_useAdminEmailForClinic) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _clinicEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Clinic Business Email',
                      hintText: 'Different from admin email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (!_useAdminEmailForClinic) {
                        if (value?.isEmpty == true) return 'Required';
                        if (!value!.contains('@')) return 'Invalid email';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // Admin Information
                const Text(
                  'Admin Information',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _adminNameController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _adminEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Required';
                    if (!value!.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _adminPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Required';
                    if (value!.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  developer.log(
                    'Create button pressed in dialog!',
                    name: 'CreateClinicDialog',
                  );
                  _createClinicAdmin();
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createClinicAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      developer.log('Starting clinic creation...', name: 'CreateClinicDialog');
      await _createClinicAdminAccount();
      developer.log(
        'Clinic creation completed successfully',
        name: 'CreateClinicDialog',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Clinic and admin profile created successfully!\n\nClinic: ${_clinicNameController.text}\nAdmin Email: ${_adminEmailController.text}',
            ),
            duration: const Duration(seconds: 8),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      developer.log('Error creating clinic: $e', name: 'CreateClinicDialog');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating clinic: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createClinicAdminAccount() async {
    try {
      developer.log(
        'Starting clinic creation process...',
        name: 'CreateClinicDialog',
      );
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Validate user permissions
      if (!userProvider.isAppOwner) {
        throw Exception('Only app owners can create clinics');
      }

      developer.log(
        'User is app owner, proceeding with clinic creation',
        name: 'CreateClinicDialog',
      );
      developer.log('Clinic details:', name: 'CreateClinicDialog');
      developer.log(
        '  - Name: ${_clinicNameController.text.trim()}',
        name: 'CreateClinicDialog',
      );
      developer.log(
        '  - Address: ${_clinicAddressController.text.trim()}',
        name: 'CreateClinicDialog',
      );
      developer.log(
        '  - Admin: ${_adminNameController.text.trim()} (${_adminEmailController.text.trim()})',
        name: 'CreateClinicDialog',
      );

      // Determine which email to use for clinic
      final clinicEmail = _useAdminEmailForClinic
          ? _adminEmailController.text.trim()
          : _clinicEmailController.text.trim();

      // Create the clinic and admin profile
      final clinicId = await userProvider.createClinicForAdmin(
        name: _clinicNameController.text.trim(),
        address: _clinicAddressController.text.trim(),
        phone: _clinicPhoneController.text.trim(),
        email: clinicEmail,
        adminEmail: _adminEmailController.text.trim(),
        adminName: _adminNameController.text.trim(),
      );

      developer.log(
        'Clinic creation result: $clinicId',
        name: 'CreateClinicDialog',
      );

      if (clinicId == null || clinicId.isEmpty) {
        throw Exception('Failed to create clinic - no clinic ID returned');
      }

      developer.log(
        'Clinic created successfully with ID: $clinicId',
        name: 'CreateClinicDialog',
      );

      // Send email notifications
      await _sendClinicCreationEmails(
        clinicEmail,
        _adminEmailController.text.trim(),
      );

      // Close the creation dialog first
      Navigator.of(context).pop();

      // Show enhanced success dialog
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                const Text('Clinic Created Successfully!'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🏥 Clinic Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('• Name: ${_clinicNameController.text}'),
                          Text('• Address: ${_clinicAddressController.text}'),
                          Text('• Phone: ${_clinicPhoneController.text}'),
                          Text('• Email: $clinicEmail'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '👤 Admin Account Created',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('• Name: ${_adminNameController.text}'),
                          Text('• Login Email: ${_adminEmailController.text}'),
                          if (_useAdminEmailForClinic)
                            Text('• Also serves as clinic contact email')
                          else
                            Text('• Clinic contact: $clinicEmail'),
                          const SizedBox(height: 12),
                          Text(
                            'Next Steps:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('1. Admin downloads PetOn app'),
                          Text(
                            '2. Signs up with: ${_adminEmailController.text}',
                          ),
                          Text('3. Verifies email address'),
                          Text('4. Automatically becomes clinic admin'),
                          Text('5. Can start managing vets and appointments'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📧 Email Notifications Sent',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('• Welcome email sent to admin'),
                          Text('• Clinic registration confirmation sent'),
                          Text('• Instructions for next steps included'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Perfect!'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      developer.log(
        'Error in _createClinicAdminAccount: $e',
        name: 'CreateClinicDialog',
      );
      rethrow;
    }
  }

  /// Send email notifications for clinic creation
  Future<void> _sendClinicCreationEmails(
    String clinicEmail,
    String adminEmail,
  ) async {
    try {
      developer.log(
        'Sending email notifications...',
        name: 'CreateClinicDialog',
      );

      // Send welcome email to admin
      await _sendAdminWelcomeEmail(adminEmail);

      // Send clinic registration confirmation
      await _sendClinicRegistrationEmail(clinicEmail);

      developer.log(
        'Email notifications sent successfully',
        name: 'CreateClinicDialog',
      );
    } catch (e) {
      developer.log(
        'Error sending email notifications: $e',
        name: 'CreateClinicDialog',
      );
      // Don't throw - email failure shouldn't break clinic creation
    }
  }

  /// Send welcome email to new clinic admin
  Future<void> _sendAdminWelcomeEmail(String adminEmail) async {
    try {
      // TODO: Implement actual email sending logic
      // For now, just log the email that would be sent
      developer.log(
        'Would send welcome email to admin: $adminEmail',
        name: 'CreateClinicDialog',
      );
      developer.log(
        '   Subject: Welcome to PetOn - Your Clinic Admin Account',
        name: 'CreateClinicDialog',
      );
      developer.log(
        '   Content: Welcome! Your clinic has been created. Please sign up with this email to access your admin dashboard.',
        name: 'CreateClinicDialog',
      );

      // In a real implementation, you would use a service like:
      // - Firebase Functions with SendGrid
      // - AWS SES
      // - EmailJS
      // - Or any other email service
    } catch (e) {
      developer.log(
        'Error sending admin welcome email: $e',
        name: 'CreateClinicDialog',
      );
    }
  }

  /// Send clinic registration confirmation
  Future<void> _sendClinicRegistrationEmail(String clinicEmail) async {
    try {
      // TODO: Implement actual email sending logic
      developer.log(
        'Would send clinic registration email to: $clinicEmail',
        name: 'CreateClinicDialog',
      );
      developer.log(
        '   Subject: PetOn Clinic Registration Confirmation',
        name: 'CreateClinicDialog',
      );
      developer.log(
        '   Content: Your clinic has been successfully registered on PetOn platform.',
        name: 'CreateClinicDialog',
      );
    } catch (e) {
      developer.log(
        'Error sending clinic registration email: $e',
        name: 'CreateClinicDialog',
      );
    }
  }

  @override
  void dispose() {
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _clinicPhoneController.dispose();
    _clinicEmailController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }
}

/// Dialog to show all clinics for app owners
class _AllClinicsDialog extends StatelessWidget {
  const _AllClinicsDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('All Clinics'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clinics')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final clinics = snapshot.data?.docs ?? [];

            if (clinics.isEmpty) {
              return const Center(child: Text('No clinics found.'));
            }

            return ListView.separated(
              itemCount: clinics.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final clinicData =
                    clinics[index].data() as Map<String, dynamic>;
                final clinic = Clinic.fromJson(clinicData, clinics[index].id);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: clinic.isActive
                        ? AppTheme.primaryGreen
                        : Colors.grey,
                    child: const Icon(Icons.business, color: Colors.white),
                  ),
                  title: Text(clinic.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clinic.email),
                      Text(
                        clinic.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: clinic.isActive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle_status',
                        child: Text(
                          clinic.isActive ? 'Deactivate' : 'Activate',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'view_details',
                        child: Text('View Details'),
                      ),
                      const PopupMenuItem(
                        value: 'manage_admins',
                        child: Text('Manage Admins'),
                      ),
                    ],
                    onSelected: (value) =>
                        _handleClinicAction(context, clinic, value.toString()),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _handleClinicAction(
    BuildContext context,
    Clinic clinic,
    String action,
  ) async {
    try {
      switch (action) {
        case 'toggle_status':
          await FirebaseFirestore.instance
              .collection('clinics')
              .doc(clinic.id)
              .update({
                'isActive': !clinic.isActive,
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  clinic.isActive ? 'Clinic deactivated' : 'Clinic activated',
                ),
              ),
            );
          }
          break;

        case 'view_details':
          _showClinicDetails(context, clinic);
          break;
        case 'manage_admins':
          _showManageAdminsDialog(context, clinic);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showClinicDetails(BuildContext context, Clinic clinic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clinic.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address: ${clinic.address}'),
            Text('Phone: ${clinic.phone}'),
            Text('Email: ${clinic.email}'),
            Text('Status: ${clinic.isActive ? 'Active' : 'Inactive'}'),
            Text('Created: ${clinic.createdAt}'),
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

  void _showManageAdminsDialog(BuildContext context, Clinic clinic) {
    showDialog(
      context: context,
      builder: (context) => _ManageAdminsDialog(clinic: clinic),
    );
  }
}

/// Dialog for managing clinic admins
class _ManageAdminsDialog extends StatefulWidget {
  final Clinic clinic;

  const _ManageAdminsDialog({required this.clinic});

  @override
  State<_ManageAdminsDialog> createState() => _ManageAdminsDialogState();
}

class _ManageAdminsDialogState extends State<_ManageAdminsDialog> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: AppTheme.primaryBlue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Manage Admins - ${widget.clinic.name}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Admin Section
                    _buildSectionHeader(
                      'Current Admin',
                      Icons.person,
                      AppTheme.primaryBlue,
                    ),
                    const SizedBox(height: 12),
                    _buildCurrentAdminCard(),

                    const SizedBox(height: 24),

                    // Add New Admin Section
                    _buildSectionHeader(
                      'Add Additional Admin',
                      Icons.person_add,
                      AppTheme.primaryGreen,
                    ),
                    const SizedBox(height: 12),
                    _buildAddAdminCard(),

                    const SizedBox(height: 24),

                    // Additional Admins Section
                    _buildSectionHeader(
                      'Additional Admins',
                      Icons.people,
                      AppTheme.warningAmber,
                    ),
                    const SizedBox(height: 12),
                    _buildAdditionalAdminsCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentAdminCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.clinic.adminId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                !snapshot.data!.exists) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Admin not found',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    ),
                  ],
                ),
              );
            }

            final adminData = snapshot.data!.data() as Map<String, dynamic>;
            final adminName = adminData['displayName'] ?? 'Unknown Admin';
            final adminEmail = adminData['email'] ?? 'No email';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryBlue,
                      child: Text(
                        adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adminName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            adminEmail,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Primary Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddAdminCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the email of an existing user to make them an admin of this clinic:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'User Email',
                hintText: 'Enter user email address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _addAdminToClinic,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_isLoading ? 'Adding...' : 'Add Admin'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalAdminsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .where('connectedClinicId', isEqualTo: widget.clinic.id)
                  .where('userType', isEqualTo: 2) // Clinic Admin
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Error loading additional admins',
                            style: TextStyle(color: Colors.orange[700]),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final admins = snapshot.data!.docs;
                final additionalAdmins = admins
                    .where((doc) => doc.id != widget.clinic.adminId)
                    .toList();

                if (additionalAdmins.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No additional admins found. Add admins using the form above.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${additionalAdmins.length} additional admin${additionalAdmins.length > 1 ? 's' : ''}:',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ...additionalAdmins.map((adminDoc) {
                      final adminData = adminDoc.data() as Map<String, dynamic>;
                      final adminName =
                          adminData['displayName'] ?? 'Unknown Admin';
                      final adminEmail = adminData['email'] ?? 'No email';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.primaryGreen,
                              child: Text(
                                adminName.isNotEmpty
                                    ? adminName[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    adminName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    adminEmail,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  _removeAdmin(adminDoc.id, adminName),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              tooltip: 'Remove admin',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAdminToClinic() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Find user by email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No user found with email: $email'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      final userId = userDoc.id;

      // Check if user is already an admin of this clinic
      if (userData['connectedClinicId'] == widget.clinic.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This user is already an admin of this clinic'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Update user to be clinic admin
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'userType': 2, // Clinic Admin
        'connectedClinicId': widget.clinic.id,
        'clinicRole': 0, // Admin role
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) {
        _emailController.clear();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully added ${userData['displayName']} as admin to ${widget.clinic.name}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding admin: $e'),
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

  Future<void> _removeAdmin(String userId, String adminName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Admin'),
        content: Text(
          'Are you sure you want to remove $adminName as an admin of this clinic?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Reset user to regular user type
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'userType': 0, // Pet Owner
        'connectedClinicId': null,
        'clinicRole': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully removed $adminName as admin'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing admin: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Temporarily removed to fix syntax error

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
