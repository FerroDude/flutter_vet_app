import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../models/clinic_models.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';

/// Initial onboarding page for new users to select their role
class ClinicOnboardingPage extends StatefulWidget {
  const ClinicOnboardingPage({super.key});

  @override
  State<ClinicOnboardingPage> createState() => _ClinicOnboardingPageState();
}

class _ClinicOnboardingPageState extends State<ClinicOnboardingPage> {
  UserType _selectedUserType = UserType.petOwner;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                // Welcome header
                Text(
                  'Welcome to VetPlus!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Text(
                  'Let us know how you\'ll be using the app',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 60),

                // Role selection cards - Public registration only for Pet Owners
                _buildRoleCard(
                  title: 'Pet Owner',
                  description:
                      'I want to manage my pet\'s health and appointments',
                  icon: Icons.pets,
                  userType: UserType.petOwner,
                  color: AppTheme.primary,
                ),

                const SizedBox(height: 32),

                // Info text for other user types
                Container(
                  padding: EdgeInsets.all(AppTheme.spacing3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Veterinarian or Clinic Administrator?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vet and clinic admin accounts are created by your clinic administrator. Contact your clinic for access.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Continue button
                ElevatedButton(
                  onPressed: _isLoading ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String description,
    required IconData icon,
    required UserType userType,
    required Color color,
  }) {
    final isSelected = _selectedUserType == userType;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
        border: isSelected
            ? Border.all(color: AppTheme.primary, width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedUserType = userType),
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),

                SizedBox(width: AppTheme.spacing3),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.neutral700,
                        ),
                      ),
                    ],
                  ),
                ),

                if (isSelected)
                  Icon(Icons.check_circle, color: AppTheme.primary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continue() async {
    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();

      // The UserProvider will automatically create the user profile
      // We just need to wait for it to complete and then update the user type
      await userProvider.updateProfile();

      // After profile is created, the AuthWrapper will handle the next step
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

/// Page for pet owners to select or create a clinic connection
class ClinicSelectionPage extends StatefulWidget {
  const ClinicSelectionPage({super.key});

  @override
  State<ClinicSelectionPage> createState() => _ClinicSelectionPageState();
}

class _ClinicSelectionPageState extends State<ClinicSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Clinic> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNearbyClinicsSample();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Choose Your Clinic',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark, // For iOS
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppTheme.primary),
                    decoration: InputDecoration(
                      hintText: 'Search for a clinic...',
                      hintStyle: TextStyle(color: AppTheme.neutral400),
                      prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                      suffixIcon: _isSearching
                          ? UnconstrainedBox(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary,
                                ),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing3,
                        vertical: AppTheme.spacing3,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),

                SizedBox(height: AppTheme.spacing4),

                // Section header
                Text(
                  _searchController.text.isEmpty
                      ? 'Available Clinics'
                      : 'Search Results',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: AppTheme.spacing3),

                // Clinic list
                Expanded(
                  child: _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchController.text.isEmpty
                                    ? Icons.local_hospital_outlined
                                    : Icons.search_off,
                                size: 64,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Loading clinics...'
                                    : 'No clinics found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              if (_searchController.text.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final clinic = _searchResults[index];
                            return _buildClinicCard(clinic);
                          },
                        ),
                ),

                SizedBox(height: AppTheme.spacing3),

                // Skip button
                OutlinedButton(
                  onPressed: _skipForNow,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                  ),
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClinicCard(Clinic clinic) {
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacing3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectClinic(clinic),
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacing3),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                  ),
                  child: const Icon(
                    Icons.local_hospital,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppTheme.spacing3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinic.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clinic.address,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.neutral700,
                        ),
                      ),
                      if (clinic.phone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            clinic.phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.neutral500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppTheme.neutral400,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _isSearching = false);
      _loadNearbyClinicsSample();
      return;
    }

    setState(() => _isSearching = true);

    // Debounce search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _searchController.text == query) {
        _searchClinics(query);
      }
    });
  }

  Future<void> _loadNearbyClinicsSample() async {
    try {
      final userProvider = context.read<UserProvider>();
      final clinics = await userProvider.searchClinics();

      if (mounted) {
        setState(() {
          _searchResults = clinics;
        });
      }
    } catch (e) {
      developer.log('Error loading clinics: $e', name: 'OnboardingPages');
    }
  }

  Future<void> _searchClinics(String query) async {
    try {
      final userProvider = context.read<UserProvider>();
      final clinics = await userProvider.searchClinics(query: query);

      if (mounted) {
        setState(() {
          _searchResults = clinics;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching clinics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectClinic(Clinic clinic) async {
    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      final success = await userProvider.connectToClinic(clinic.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${clinic.name}'),
            backgroundColor: Colors.green,
          ),
        );
        // AuthWrapper will handle navigation after connection
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to clinic: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _skipForNow() async {
    try {
      final userProvider = context.read<UserProvider>();
      final success = await userProvider.skipClinicSelection();

      if (success) {
        // The AuthWrapper will automatically navigate to the main app
        // once the user profile is updated with the skip flag
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can connect to a clinic later from settings'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                userProvider.error ?? 'Failed to skip clinic selection',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
