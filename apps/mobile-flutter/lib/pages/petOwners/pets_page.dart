import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:getwidget/getwidget.dart';
import '../../theme/app_theme.dart';
import '../../providers/user_provider.dart';
import 'pet_details_page.dart';
import 'pet_form_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';

class PetsPage extends StatelessWidget {
  const PetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            title: Text('My Pets'),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SettingsPage(injectedUserProvider: userProvider),
                    ),
                  );
                },
                tooltip: 'Settings',
              ),
              IconButton(
                icon: Icon(Icons.person_outline),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfilePage(injectedUserProvider: userProvider),
                    ),
                  );
                },
                tooltip: 'Profile',
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PetFormPage(),
                    ),
                  );
                },
                tooltip: 'Add Pet',
              ),
            ],
          ),
          body: const _ModernPetsPageContent(),
        );
      },
    );
  }
}

class _ModernPetsPageContent extends StatefulWidget {
  const _ModernPetsPageContent();

  @override
  State<_ModernPetsPageContent> createState() => _ModernPetsPageContentState();
}

class _ModernPetsPageContentState extends State<_ModernPetsPageContent> {
  final _searchController = TextEditingController();
  final String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.sp,
              color: context.textSecondary,
            ),
            Gap(AppTheme.spacing4),
            Text(
              'Please log in to view your pets',
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('pets')
                .orderBy('order')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: GFLoader(type: GFLoaderType.circle));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading pets',
                    style: TextStyle(color: context.textSecondary),
                  ),
                );
              }

              final pets = snapshot.data?.docs ?? [];

              final filteredPets = pets.where((pet) {
                if (_searchQuery.isEmpty) return true;
                final petData = pet.data();
                final name = petData['name']?.toString().toLowerCase() ?? '';
                final species =
                    petData['species']?.toString().toLowerCase() ?? '';
                final breed = petData['breed']?.toString().toLowerCase() ?? '';
                final query = _searchQuery.toLowerCase();
                return name.contains(query) ||
                    species.contains(query) ||
                    breed.contains(query);
              }).toList();

              if (filteredPets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pets_outlined,
                        size: 64.sp,
                        color: context.textSecondary,
                      ),
                      Gap(AppTheme.spacing4),
                      Text(
                        _searchQuery.isEmpty ? 'No pets yet' : 'No pets found',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      Gap(AppTheme.spacing2),
                      if (_searchQuery.isEmpty)
                        GFButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PetFormPage(),
                              ),
                            );
                          },
                          text: 'Add Your First Pet',
                          icon: Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                          color: AppTheme.primary,
                        ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(AppTheme.spacing4),
                itemCount: filteredPets.length,
                itemBuilder: (context, index) {
                  final petDoc = filteredPets[index];
                  final pet = petDoc.data();
                  return Padding(
                    padding: EdgeInsets.only(bottom: AppTheme.spacing3),
                    child: _PetCard(petId: petDoc.id, petData: pet),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing4),
      color: context.surface,
      child: GFSearchBar(
        searchList: [],
        searchQueryBuilder: (query, list) => [],
        overlaySearchListItemBuilder: (item) => Container(),
        onItemSelected: (item) {},
        searchBoxInputDecoration: InputDecoration(
          hintText: 'Search pets...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius2),
            borderSide: BorderSide(color: context.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius2),
            borderSide: BorderSide(color: context.border),
          ),
          prefixIcon: Icon(Icons.search, color: context.textSecondary),
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final String petId;
  final Map<String, dynamic> petData;

  const _PetCard({required this.petId, required this.petData});

  @override
  Widget build(BuildContext context) {
    final name = petData['name'] ?? 'Unknown';
    final species = petData['species'] ?? '';
    final breed = petData['breed'] ?? '';
    final age = petData['age'];
    final imageUrl = petData['imageUrl'];

    return GFCard(
      elevation: 0,
      color: context.surface,
      borderOnForeground: true,
      boxFit: BoxFit.cover,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        side: BorderSide(color: context.border),
      ),
      content: GFListTile(
        avatar: GFAvatar(
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
          backgroundColor: context.isDark
              ? Color(0xFF2F2F2F)
              : AppTheme.neutral100,
          size: GFSize.LARGE,
          child: imageUrl == null
              ? Icon(Icons.pets, size: 24.sp, color: context.textPrimary)
              : null,
        ),
        title: Text(
          name,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        subTitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (breed.isNotEmpty || species.isNotEmpty) ...[
              Gap(AppTheme.spacing1),
              Text(
                breed.isNotEmpty ? breed : species,
                style: TextStyle(fontSize: 14.sp, color: context.textSecondary),
              ),
            ],
            if (age != null) ...[
              Gap(AppTheme.spacing1),
              Row(
                children: [
                  Icon(
                    Icons.cake_outlined,
                    size: 14.sp,
                    color: context.textSecondary,
                  ),
                  Gap(AppTheme.spacing1),
                  Text(
                    '$age ${age == 1 ? 'year' : 'years'} old',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        icon: Icon(Icons.chevron_right, color: context.textSecondary),
        onTap: () {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            final petRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('pets')
                .doc(petId);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PetDetailsPage(petRef: petRef),
              ),
            );
          }
        },
      ),
    );
  }
}
