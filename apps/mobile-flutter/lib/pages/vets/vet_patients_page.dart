import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('Patients'),
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.neutral700,
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
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No clinic linked',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Vets must be linked to a clinic to view patients.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(VetProvider vetProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name…',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: vetProvider.updateSearchText,
      ),
    );
  }

  Widget _buildPatientsList(VetProvider vetProvider) {
    if (vetProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vetProvider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            vetProvider.error!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.red),
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
            Icon(Icons.pets, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No patients yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final owner = patients[index];
        final pets = vetProvider.petsForOwner(owner.id);

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.neutral700.withValues(alpha: 0.1),
              child: const Icon(Icons.person, color: Colors.black87),
            ),
            title: Text(
              owner.displayName.isEmpty ? owner.email : owner.displayName,
            ),
            subtitle: Text(owner.email),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pets.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${pets.length} pets'),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
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
