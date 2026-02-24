import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/user_provider.dart';
import '../../models/clinic_models.dart';
import '../../shared/widgets/app_components.dart';
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
          return Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Access denied',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'App owner privileges required',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text('System Statistics'),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
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
                      const Text(
                        'Clinic Statistics',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildClinicsStatsGrid(),

                      const SizedBox(height: 24),

                      // Users Statistics
                      const Text(
                        'User Statistics',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildUsersStatsGrid(),

                      const SizedBox(height: 24),

                      // Recent Activity
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildRecentActivity(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemOverviewCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.8)],
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
                    color: Colors.white.withValues(alpha: 0.2),
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
          return const AppLoadingIndicator();
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius3),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Text(
              'Error loading clinic stats: ${snapshot.error}',
              style: TextStyle(color: AppTheme.primary),
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
              color: AppTheme.primary,
            ),
            _buildStatCard(
              title: 'Active Clinics',
              value: activeClinics.toString(),
              icon: Icons.check_circle,
              color: AppTheme.primary,
            ),
            _buildStatCard(
              title: 'Inactive Clinics',
              value: inactiveClinics.toString(),
              icon: Icons.pause_circle,
              color: AppTheme.primary,
            ),
            _buildStatCard(
              title: 'This Month',
              value: '0',
              icon: Icons.trending_up,
              color: AppTheme.primary,
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
          return const AppLoadingIndicator();
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius3),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Text(
              'Error loading user stats: ${snapshot.error}',
              style: TextStyle(color: AppTheme.primary),
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
              color: AppTheme.primary,
            ),
            _buildStatCard(
              title: 'Pet Owners',
              value: petOwners.toString(),
              icon: Icons.pets,
              color: AppTheme.primary,
            ),
            _buildStatCard(
              title: 'Veterinarians',
              value: vets.toString(),
              icon: Icons.medical_services,
              color: AppTheme.primary,
            ),
            _buildStatCard(
              title: 'Clinic Admins',
              value: clinicAdmins.toString(),
              icon: Icons.admin_panel_settings,
              color: AppTheme.primary,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.primary, size: 28),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.neutral600,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent System Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
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
                return Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: AppTheme.error),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingIndicator();
              }

              final recentClinics = snapshot.data?.docs ?? [];

              if (recentClinics.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.timeline,
                        size: 48,
                        color: AppTheme.neutral400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recent clinic activity',
                        style: TextStyle(
                          color: AppTheme.neutral600,
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
                      backgroundColor: AppTheme.primary,
                      child: const Icon(
                        Icons.business,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      clinic.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primary,
                      ),
                    ),
                    subtitle: Text(
                      'New clinic registered',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.neutral600,
                      ),
                    ),
                    trailing: Text(
                      _formatDate(clinic.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.neutral500,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
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
