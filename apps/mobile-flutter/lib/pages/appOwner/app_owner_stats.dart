import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/user_provider.dart';
import '../../models/clinic_models.dart';
import '../../theme/app_theme.dart';

class AppOwnerStats extends StatefulWidget {
  const AppOwnerStats({super.key});

  @override
  State<AppOwnerStats> createState() => _AppOwnerStatsState();
}

class _AppOwnerStatsState extends State<AppOwnerStats> {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Only app owners can access this stats page
        if (!userProvider.isAppOwner) {
          return const Scaffold(
            body: Center(
              child: Text('Access denied. App owner privileges required.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('System Statistics'),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                onPressed: () => _refreshStats(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshStats,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // System Overview
                  _buildSystemOverviewCard(),

                  const SizedBox(height: 24),

                  // Clinics Statistics
                  Text(
                    'Clinic Statistics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildClinicsStatsGrid(),

                  const SizedBox(height: 24),

                  // Users Statistics
                  Text(
                    'User Statistics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildUsersStatsGrid(),

                  const SizedBox(height: 24),

                  // Recent Activity
                  Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildRecentActivity(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemOverviewCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      color: isDark ? Colors.grey[900] : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
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
              AppTheme.primaryGreen,
              AppTheme.primaryGreen.withOpacity(0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Analytics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Real-time VetPlus Platform Statistics',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicsStatsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clinics').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Card(
            color: isDark ? Colors.grey[900] : Colors.grey[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading clinic stats: ${snapshot.error}'),
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

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildStatCard(
              title: 'Total Clinics',
              value: totalClinics.toString(),
              icon: Icons.business,
              color: AppTheme.primaryBlue,
            ),
            _buildStatCard(
              title: 'Active Clinics',
              value: activeClinics.toString(),
              icon: Icons.check_circle,
              color: AppTheme.primaryGreen,
            ),
            _buildStatCard(
              title: 'Inactive Clinics',
              value: inactiveClinics.toString(),
              icon: Icons.pause_circle,
              color: AppTheme.warningAmber,
            ),
            _buildStatCard(
              title: 'This Month',
              value: '0', // TODO: Implement monthly new clinics count
              icon: Icons.trending_up,
              color: AppTheme.accentCoral,
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsersStatsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Card(
            color: isDark ? Colors.grey[900] : Colors.grey[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading user stats: ${snapshot.error}'),
            ),
          );
        }

        final users = snapshot.data?.docs ?? [];
        final totalUsers = users.length;

        // Count by user type
        final petOwners = users.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          return userData['userType'] == 0; // UserType.petOwner
        }).length;

        final vets = users.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          return userData['userType'] == 1; // UserType.vet
        }).length;

        final clinicAdmins = users.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          return userData['userType'] == 2; // UserType.clinicAdmin
        }).length;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildStatCard(
              title: 'Total Users',
              value: totalUsers.toString(),
              icon: Icons.people,
              color: AppTheme.primaryBlue,
            ),
            _buildStatCard(
              title: 'Pet Owners',
              value: petOwners.toString(),
              icon: Icons.pets,
              color: AppTheme.primaryGreen,
            ),
            _buildStatCard(
              title: 'Veterinarians',
              value: vets.toString(),
              icon: Icons.medical_services,
              color: AppTheme.warningAmber,
            ),
            _buildStatCard(
              title: 'Clinic Admins',
              value: clinicAdmins.toString(),
              icon: Icons.admin_panel_settings,
              color: AppTheme.accentCoral,
            ),
          ],
        );
      },
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
      elevation: 3,
      color: isDark ? Colors.grey[900] : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
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
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? Colors.grey[900] : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent System Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Recent Clinics
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clinics')
                  .orderBy('createdAt', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                final recentClinics = snapshot.data?.docs ?? [];

                if (recentClinics.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.timeline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No recent clinic activity',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: recentClinics.map((doc) {
                    final clinicData = doc.data() as Map<String, dynamic>;
                    final clinic = Clinic.fromJson(clinicData, doc.id);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryGreen,
                        child: const Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        clinic.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'New clinic registered',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: Text(
                        _formatDate(clinic.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _refreshStats() async {
    // Trigger a rebuild by calling setState
    setState(() {});

    // You could also trigger other refresh operations here
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
