import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../providers/vet_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import 'patient_detail_page.dart';
import '../petOwners/profile_page.dart';
import '../petOwners/settings_page.dart';

class VetPatientsPage extends StatefulWidget {
  const VetPatientsPage({super.key});

  @override
  State<VetPatientsPage> createState() => _VetPatientsPageState();
}

class _VetPatientsPageState extends State<VetPatientsPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final up = context.read<UserProvider>();
      final vp = context.read<VetProvider>();
      final clinicId = up.connectedClinic?.id;
      if (clinicId != null) {
        vp.initialize(clinicId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<VetProvider, UserProvider>(
      builder: (context, vetProvider, userProvider, child) {
        final clinic = userProvider.connectedClinic;
        return Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                'Patients',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SettingsPage(injectedUserProvider: userProvider),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline),
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
                ),
              ],
            ),
            body: clinic == null
                ? _buildNoClinic()
                : Column(
                    children: [
                      _buildSearchBar(vetProvider),
                      Expanded(child: _buildPatientsList(vetProvider)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildNoClinic() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_hospital_outlined,
            size: 64.sp,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          Gap(AppTheme.spacing4),
          Text(
            'No clinic linked',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Gap(AppTheme.spacing2),
          Text(
            'Vets must be linked to a clinic to view patients.',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(VetProvider vetProvider) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacing4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          boxShadow: AppTheme.cardShadow,
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: AppTheme.primary, fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: 'Search by name…',
            hintStyle: TextStyle(color: AppTheme.neutral700.withValues(alpha: 0.5)),
            prefixIcon: Icon(Icons.search, color: AppTheme.primary),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacing3,
              vertical: AppTheme.spacing3,
            ),
          ),
          onChanged: vetProvider.updateSearchText,
        ),
      ),
    );
  }

  Widget _buildPatientsList(VetProvider vetProvider) {
    if (vetProvider.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    if (vetProvider.error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing4),
          child: Text(
            vetProvider.error!,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.error,
            ),
          ),
        ),
      );
    }
    final patients = vetProvider.patients;
    if (patients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets,
              size: 64.sp,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            Gap(AppTheme.spacing4),
            Text(
              'No patients yet',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
      itemCount: patients.length,
      separatorBuilder: (_, __) => Gap(AppTheme.spacing2),
      itemBuilder: (context, index) {
        final owner = patients[index];
        final pets = vetProvider.petsForOwner(owner.id);

        return Container(
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
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Text(
                (owner.displayName.isNotEmpty
                        ? owner.displayName[0]
                        : owner.email[0])
                    .toUpperCase(),
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            title: Text(
              owner.displayName.isEmpty ? owner.email : owner.displayName,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
            ),
            subtitle: Text(
              owner.email,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.neutral700,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pets.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing2,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brandTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pets.length} pets',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.brandTeal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Gap(AppTheme.spacing2),
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.neutral700,
                  size: 20.sp,
                ),
              ],
            ),
            onTap: () {
              final userProvider = context.read<UserProvider>();
              final vetProv = context.read<VetProvider>();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MultiProvider(
                    providers: [
                      ChangeNotifierProvider.value(value: userProvider),
                      ChangeNotifierProvider.value(value: vetProv),
                    ],
                    child: PatientDetailPage(ownerId: owner.id),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
