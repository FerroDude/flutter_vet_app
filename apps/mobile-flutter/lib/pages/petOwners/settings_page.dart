import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../services/clinic_service.dart';
import '../../services/media_cache_service.dart';
import '../../models/clinic_models.dart';
import 'profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.injectedUserProvider});

  final UserProvider? injectedUserProvider;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _cacheSize = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    try {
      final cacheService = MediaCacheService.instance;
      try {
        cacheService.basePath;
      } catch (_) {
        await cacheService.init();
      }
      final size = await cacheService.getFormattedCacheSize();
      if (mounted) {
        setState(() {
          _cacheSize = size;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cacheSize = 'Unknown';
        });
      }
    }
  }

  void _showCacheDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CacheDetailsSheet(
        onCacheCleared: () {
          _loadCacheSize();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final effectiveProvider =
        widget.injectedUserProvider ?? context.read<UserProvider>();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        body: ChangeNotifierProvider.value(
          value: effectiveProvider,
          child: Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                if (user != null)
                  _buildProfileHeader(context, user, userProvider),

                Gap(AppTheme.spacing3),

                // Only show clinic section for non-app owners
                // App owners are never connected to clinics
                if (!userProvider.isAppOwner)
                  _buildSection(context, 'Account', [
                    _buildTile(
                      context,
                      icon: Icons.local_hospital_outlined,
                      title: 'Connected Clinic',
                      subtitle:
                          userProvider.connectedClinic?.name ?? 'Not connected',
                      onTap: () => _showClinicDetails(context, userProvider),
                    ),
                  ]),

                _buildSection(context, 'Preferences', [
                  _buildSwitchTile(
                    context,
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Appointments and reminders',
                    value: true,
                    onChanged: (value) {},
                  ),
                  _buildTile(
                    context,
                    icon: Icons.language_outlined,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () {},
                  ),
                ]),

                _buildSection(context, 'Storage', [
                  _buildTile(
                    context,
                    icon: Icons.folder_outlined,
                    title: 'Cache',
                    subtitle: _cacheSize,
                    onTap: _showCacheDetails,
                  ),
                ]),

                _buildSection(context, 'Support', [
                  _buildTile(
                    context,
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    onTap: () {},
                  ),
                  _buildTile(
                    context,
                    icon: Icons.chat_bubble_outline,
                    title: 'Contact Us',
                    onTap: () {},
                  ),
                  _buildTile(
                    context,
                    icon: Icons.star_outline,
                    title: 'Rate App',
                    onTap: () {},
                  ),
                ]),

                _buildSection(context, 'About', [
                  _buildTile(
                    context,
                    icon: Icons.policy_outlined,
                    title: 'Privacy Policy',
                    onTap: () {},
                  ),
                  _buildTile(
                    context,
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () {},
                  ),
                  _buildTile(
                    context,
                    icon: Icons.info_outline,
                    title: 'App Version',
                    subtitle: '1.0.0',
                    onTap: null,
                  ),
                ]),

                Padding(
                  padding: EdgeInsets.all(AppTheme.spacing4),
                  child: ElevatedButton(
                    onPressed: () async {
                      final shouldSignOut = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text(
                            'Are you sure you want to sign out?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.error,
                              ),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );

                      if (shouldSignOut == true && context.mounted) {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.error,
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                      padding: EdgeInsets.symmetric(
                        vertical: AppTheme.spacing3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius2),
                        side: BorderSide(color: AppTheme.error, width: 1.5),
                      ),
                    ),
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

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
    User user,
    UserProvider userProvider,
  ) {
    final rawName = user.displayName ?? '';
    final email = user.email ?? '';
    final displayName =
        rawName.isNotEmpty ? rawName : (email.isNotEmpty ? email : 'User');
    final initialSource = displayName.isNotEmpty ? displayName : 'U';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProfilePage(injectedUserProvider: userProvider),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacing4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius4),
          boxShadow: AppTheme.cardShadow,
        ),
        margin: EdgeInsets.all(AppTheme.spacing4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32.r,
              backgroundColor: AppTheme.neutral800.withValues(alpha:0.1),
              child: Text(
                initialSource[0].toUpperCase(),
                style: TextStyle(
                  color: AppTheme.neutral800,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Gap(AppTheme.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  Gap(AppTheme.spacing1),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.neutral700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.neutral700, size: 20.sp),
          ],
        ),
      ),
    );
  }

  void _showClinicDetails(BuildContext context, UserProvider userProvider) {
    final clinic = userProvider.connectedClinic;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacing4),
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
                    'Connected Clinic',
                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing4),
                  
                  if (clinic != null) ...[
                    // Clinic details card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(AppTheme.spacing4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radius3),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(AppTheme.spacing3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radius2),
                                ),
                                child: Icon(
                                  Icons.local_hospital,
                                  color: AppTheme.primary,
                                  size: 28.sp,
                                ),
                              ),
                              Gap(AppTheme.spacing3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      clinic.name,
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    Gap(4),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Connected',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (clinic.address.isNotEmpty) ...[
                            Gap(AppTheme.spacing3),
                            Divider(color: AppTheme.neutral200),
                            Gap(AppTheme.spacing2),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, 
                                  size: 18.sp, 
                                  color: AppTheme.neutral700,
                                ),
                                Gap(AppTheme.spacing2),
                                Expanded(
                                  child: Text(
                                    clinic.address,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: AppTheme.neutral700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (clinic.phone.isNotEmpty) ...[
                            Gap(AppTheme.spacing2),
                            Row(
                              children: [
                                Icon(Icons.phone_outlined, 
                                  size: 18.sp, 
                                  color: AppTheme.neutral700,
                                ),
                                Gap(AppTheme.spacing2),
                                Text(
                                  clinic.phone,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: AppTheme.neutral700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (clinic.email.isNotEmpty) ...[
                            Gap(AppTheme.spacing2),
                            Row(
                              children: [
                                Icon(Icons.email_outlined, 
                                  size: 18.sp, 
                                  color: AppTheme.neutral700,
                                ),
                                Gap(AppTheme.spacing2),
                                Text(
                                  clinic.email,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: AppTheme.neutral700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing4),
                    // Change clinic button - only show for pet owners
                    // Vets and clinic admins are bound to their clinic
                    if (!userProvider.isVet && !userProvider.isClinicAdmin)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _showChangeClinicDialog(context, userProvider);
                          },
                          icon: Icon(Icons.swap_horiz),
                          label: Text('Connect to Different Clinic'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radius2),
                            ),
                          ),
                        ),
                      ),
                  ] else ...[
                    // No clinic connected - only show connect option for pet owners
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(AppTheme.spacing4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radius3),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_hospital_outlined,
                            size: 48.sp,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          Gap(AppTheme.spacing3),
                          Text(
                            'No clinic connected',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          Gap(AppTheme.spacing2),
                          Text(
                            userProvider.isVet 
                              ? 'Please contact your clinic administrator'
                              : 'Connect to a veterinary clinic to access their services',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing4),
                    // Connect button - only show for pet owners
                    if (!userProvider.isVet)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _showChangeClinicDialog(context, userProvider);
                          },
                          icon: Icon(Icons.add),
                          label: Text('Connect to Clinic'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primary,
                            padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radius2),
                            ),
                          ),
                        ),
                      ),
                  ],
                  SizedBox(height: AppTheme.spacing4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChangeClinicDialog(BuildContext context, UserProvider userProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ClinicSearchSheet(
          userProvider: userProvider,
          onClinicSelected: (clinic) async {
            Navigator.pop(sheetContext);
            
            // Show loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connecting to ${clinic.name}...'),
                duration: Duration(seconds: 1),
              ),
            );
            
            // Try to connect
            final success = await userProvider.connectToClinic(clinic.id);
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success 
                      ? 'Successfully connected to ${clinic.name}!' 
                      : 'Failed to connect. Please try again.',
                  ),
                  backgroundColor: success ? AppTheme.success : AppTheme.error,
                ),
              );
            }
          },
        );
      },
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
            boxShadow: AppTheme.cardShadow,
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
        Gap(AppTheme.spacing3),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacing4,
          vertical: AppTheme.spacing3,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22.sp, color: AppTheme.neutral800),
            Gap(AppTheme.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.primary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    Gap(2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppTheme.neutral700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: AppTheme.neutral700,
                size: 20.sp,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing4,
        vertical: AppTheme.spacing3,
      ),
      child: Row(
        children: [
          Icon(icon, size: 22.sp, color: AppTheme.neutral800),
          Gap(AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.primary,
                  ),
                ),
                if (subtitle != null) ...[
                  Gap(2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.neutral700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.neutral800,
          ),
        ],
      ),
    );
  }
}

class _ClinicSearchSheet extends StatefulWidget {
  final UserProvider userProvider;
  final Function(Clinic) onClinicSelected;

  const _ClinicSearchSheet({
    required this.userProvider,
    required this.onClinicSelected,
  });

  @override
  State<_ClinicSearchSheet> createState() => _ClinicSearchSheetState();
}

class _ClinicSearchSheetState extends State<_ClinicSearchSheet> {
  final _searchController = TextEditingController();
  final _clinicService = ClinicService();
  List<Clinic> _clinics = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClinics([String? query]) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clinics = await _clinicService.searchClinics(
        nameQuery: query,
        limit: 50,
      );
      
      // Filter out the currently connected clinic
      final currentClinicId = widget.userProvider.connectedClinic?.id;
      final filteredClinics = clinics.where((c) => c.id != currentClinicId).toList();
      
      setState(() {
        _clinics = filteredClinics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load clinics';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        gradient: AppTheme.backgroundGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: AppTheme.spacing4, bottom: AppTheme.spacing3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Title and search
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a Clinic',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: AppTheme.spacing2),
                Text(
                  'Search and select a veterinary clinic to connect with',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: AppTheme.spacing4),
                
                // Search field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppTheme.primary, fontSize: 16),
                    onChanged: (value) {
                      _loadClinics(value.isEmpty ? null : value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search clinics...',
                      hintStyle: TextStyle(
                        color: AppTheme.neutral700.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(AppTheme.spacing3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: AppTheme.spacing4),
          
          // Clinic list
          Expanded(
            child: _buildClinicList(),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: Colors.white.withValues(alpha: 0.5)),
            Gap(AppTheme.spacing3),
            Text(
              _error!,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            Gap(AppTheme.spacing3),
            TextButton(
              onPressed: () => _loadClinics(_searchController.text.isEmpty ? null : _searchController.text),
              child: Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_clinics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_hospital_outlined, size: 48.sp, color: Colors.white.withValues(alpha: 0.5)),
            Gap(AppTheme.spacing3),
            Text(
              _searchController.text.isEmpty
                  ? 'No clinics available'
                  : 'No clinics found',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
      itemCount: _clinics.length,
      itemBuilder: (context, index) {
        final clinic = _clinics[index];
        return _buildClinicTile(clinic);
      },
    );
  }

  Widget _buildClinicTile(Clinic clinic) {
    return GestureDetector(
      onTap: () => widget.onClinicSelected(clinic),
      child: Container(
        margin: EdgeInsets.only(bottom: AppTheme.spacing3),
        padding: EdgeInsets.all(AppTheme.spacing4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacing2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
              child: Icon(
                Icons.local_hospital,
                color: AppTheme.primary,
                size: 24.sp,
              ),
            ),
            Gap(AppTheme.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clinic.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  if (clinic.address.isNotEmpty) ...[
                    Gap(4),
                    Text(
                      clinic.address,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppTheme.neutral700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.neutral700,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cache details bottom sheet with breakdown by type
class _CacheDetailsSheet extends StatefulWidget {
  final VoidCallback onCacheCleared;

  const _CacheDetailsSheet({required this.onCacheCleared});

  @override
  State<_CacheDetailsSheet> createState() => _CacheDetailsSheetState();
}

class _CacheDetailsSheetState extends State<_CacheDetailsSheet> {
  Map<String, CacheTypeInfo>? _cacheInfo;
  bool _isLoading = true;
  String? _clearingType; // null = not clearing, 'all' = clearing all, or specific type

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cacheService = MediaCacheService.instance;
      try {
        cacheService.basePath;
      } catch (_) {
        await cacheService.init();
      }
      final info = await cacheService.getDetailedCacheInfo();
      if (mounted) {
        setState(() {
          _cacheInfo = info;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearCacheType(String type) async {
    setState(() {
      _clearingType = type;
    });

    try {
      final cacheService = MediaCacheService.instance;
      await cacheService.clearCacheType(type);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getCacheTypeName(type)} cache cleared'),
            backgroundColor: AppTheme.success,
          ),
        );
        await _loadCacheInfo();
        widget.onCacheCleared();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cache: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _clearingType = null;
        });
      }
    }
  }

  Future<void> _clearAllCache() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Cache'),
        content: const Text(
          'This will delete all cached videos, thumbnails, voice messages, and images. '
          'They will be re-downloaded when needed.\n\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (shouldClear != true || !mounted) return;

    setState(() {
      _clearingType = 'all';
    });

    try {
      await MediaCacheService.instance.clearAllCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All cache cleared successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        await _loadCacheInfo();
        widget.onCacheCleared();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cache: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _clearingType = null;
        });
      }
    }
  }

  String _getCacheTypeName(String type) {
    switch (type) {
      case MediaCacheService.videosDir:
        return 'Videos';
      case MediaCacheService.thumbnailsDir:
        return 'Thumbnails';
      case MediaCacheService.voiceDir:
        return 'Voice Messages';
      case MediaCacheService.imagesDir:
        return 'Images';
      default:
        return type;
    }
  }

  IconData _getCacheTypeIcon(String type) {
    switch (type) {
      case MediaCacheService.videosDir:
        return Icons.videocam_outlined;
      case MediaCacheService.thumbnailsDir:
        return Icons.image_outlined;
      case MediaCacheService.voiceDir:
        return Icons.mic_outlined;
      case MediaCacheService.imagesDir:
        return Icons.photo_library_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  int get _totalSize {
    if (_cacheInfo == null) return 0;
    return _cacheInfo!.values.fold(0, (sum, info) => sum + info.size);
  }

  String get _formattedTotalSize {
    final bytes = _totalSize;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.backgroundGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing4),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cache Storage',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (!_isLoading)
                    Text(
                      'Total: $_formattedTotalSize',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),

              Gap(AppTheme.spacing2),
              Text(
                'Cached files are stored locally for faster loading',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),

              Gap(AppTheme.spacing4),

              // Cache breakdown
              if (_isLoading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacing6),
                    child: const CircularProgressIndicator(color: Colors.white),
                  ),
                )
              else if (_cacheInfo != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius3),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      _buildCacheTypeTile(MediaCacheService.videosDir),
                      _buildDivider(),
                      _buildCacheTypeTile(MediaCacheService.thumbnailsDir),
                      _buildDivider(),
                      _buildCacheTypeTile(MediaCacheService.voiceDir),
                      _buildDivider(),
                      _buildCacheTypeTile(MediaCacheService.imagesDir),
                    ],
                  ),
                ),

                Gap(AppTheme.spacing4),

                // Clear all button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _clearingType != null ? null : _clearAllCache,
                    icon: _clearingType == 'all'
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_sweep),
                    label: Text(
                      _clearingType == 'all' ? 'Clearing...' : 'Clear All Cache',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius2),
                      ),
                    ),
                  ),
                ),
              ],

              Gap(AppTheme.spacing4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      color: AppTheme.neutral200,
      indent: 56.w,
    );
  }

  Widget _buildCacheTypeTile(String type) {
    final info = _cacheInfo![type]!;
    final isClearing = _clearingType == type;
    final hasFiles = info.fileCount > 0;

    return InkWell(
      onTap: (isClearing || !hasFiles || _clearingType != null)
          ? null
          : () => _clearCacheType(type),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacing4,
          vertical: AppTheme.spacing3,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacing2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
              child: Icon(
                _getCacheTypeIcon(type),
                color: AppTheme.primary,
                size: 22.sp,
              ),
            ),
            Gap(AppTheme.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getCacheTypeName(type),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primary,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    '${info.fileCount} ${info.fileCount == 1 ? 'file' : 'files'} • ${info.formattedSize}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.neutral700,
                    ),
                  ),
                ],
              ),
            ),
            if (isClearing)
              SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              )
            else if (hasFiles)
              Icon(
                Icons.delete_outline,
                color: AppTheme.neutral700,
                size: 20.sp,
              )
            else
              Text(
                'Empty',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.neutral500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
