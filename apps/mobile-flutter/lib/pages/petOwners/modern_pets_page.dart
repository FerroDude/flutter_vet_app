import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/event_provider.dart';
import '../../main.dart' show PetDetailsPage, PetFormPage;

/// Modern, redesigned pets page with smooth animations and better UX
class ModernPetsPage extends StatelessWidget {
  const ModernPetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfacePrimary,
      appBar: AppBar(
        title: Text('My Pets'),
        backgroundColor: context.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PetFormPage()),
              );
            },
            tooltip: 'Add Pet',
          ),
        ],
      ),
      body: const _ModernPetsPageContent(),
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
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String? _selectedSpecies;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
              size: 64,
              color: context.secondaryTextColor,
            ),
            SizedBox(height: AppTheme.spacing4),
            Text(
              'Please log in to view your pets',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.secondaryTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Modern Search Bar
        _buildModernSearchBar(context),

        // Pets List with StreamBuilder
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
                return _buildLoadingState(context);
              }

              if (snapshot.hasError) {
                return _buildErrorState(context, snapshot.error.toString());
              }

              final allDocs = snapshot.data?.docs ?? [];
              final speciesSet = _extractSpecies(allDocs);
              final filteredDocs = _filterPets(allDocs);

              return Column(
                children: [
                  if (speciesSet.isNotEmpty)
                    _buildSpeciesFilter(context, speciesSet),
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? _buildEmptyState(context)
                        : _buildPetsGrid(context, filteredDocs),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModernSearchBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        border: Border(
          bottom: BorderSide(color: context.borderLight, width: 1),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: _searchFocusNode.hasFocus
                ? context.primaryColor
                : context.borderMedium,
            width: 1,
          ),
          boxShadow: _searchFocusNode.hasFocus
              ? [
                  BoxShadow(
                    color: context.primaryColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (value) {
            _debounceTimer?.cancel();
            _debounceTimer = Timer(Duration(milliseconds: 300), () {
              setState(() => _searchQuery = value);
            });
          },
          decoration: InputDecoration(
            hintText: 'Search by name or breed...',
            hintStyle: TextStyle(color: context.secondaryTextColor),
            prefixIcon: Icon(Icons.search_rounded, color: context.primaryColor),
            suffixIcon:
                _searchQuery.isNotEmpty || _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: context.secondaryTextColor),
                    onPressed: () {
                      _debounceTimer?.cancel();
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _searchFocusNode.unfocus();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacing4,
              vertical: AppTheme.spacing4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeciesFilter(BuildContext context, List<String> speciesSet) {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing2,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: context.surfaceSecondary,
        border: Border(
          bottom: BorderSide(color: context.borderLight, width: 1),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        children: [
          SizedBox(width: AppTheme.spacing2),
          _buildFilterChip(context, 'All', _selectedSpecies == null, null),
          ...speciesSet.map(
            (species) => _buildFilterChip(
              context,
              species,
              _selectedSpecies == species,
              species,
            ),
          ),
          SizedBox(width: AppTheme.spacing2),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    bool selected,
    String? value,
  ) {
    return Padding(
      padding: EdgeInsets.only(right: AppTheme.spacing2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedSpecies = value),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacing4,
              vertical: AppTheme.spacing2,
            ),
            decoration: BoxDecoration(
              color: selected ? context.primaryColor : context.surfaceTertiary,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: selected ? context.primaryColor : context.borderMedium,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? Colors.white : context.textColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPetsGrid(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pets,
  ) {
    return GridView.builder(
      padding: EdgeInsets.all(AppTheme.spacing4),
      physics: BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: AppTheme.spacing4,
        mainAxisSpacing: AppTheme.spacing4,
      ),
      itemCount: pets.length,
      itemBuilder: (context, index) {
        return _buildModernPetCard(context, pets[index], index);
      },
    );
  }

  Widget _buildModernPetCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int index,
  ) {
    final pet = doc.data();
    final petName = pet['name'] as String? ?? 'Unknown';
    final species = pet['species'] as String? ?? '';
    final age = _calculateAge(pet['dateOfBirth']);

    // Generate a consistent color based on pet name
    final colors = [
      context.primaryColor,
      context.accentPrimary,
      context.accentSecondary,
      context.accentTertiary,
    ];
    final color = colors[petName.hashCode.abs() % colors.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToPetDetails(context, doc.reference),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pet Avatar/Header
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusLarge),
                    topRight: Radius.circular(AppTheme.radiusLarge),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        petName[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Pet Info
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacing3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            petName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: context.textColor,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: AppTheme.spacing1),
                          Text(
                            species,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),

                      if (age != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing2,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: Text(
                            age,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(AppTheme.spacing4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: AppTheme.spacing4,
        mainAxisSpacing: AppTheme.spacing4,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: context.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: context.errorColor),
            SizedBox(height: AppTheme.spacing4),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
            SizedBox(height: AppTheme.spacing2),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty || _selectedSpecies != null
                  ? Icons.search_off
                  : Icons.pets_outlined,
              size: 80,
              color: context.secondaryTextColor.withOpacity(0.5),
            ),
            SizedBox(height: AppTheme.spacing4),
            Text(
              _searchQuery.isNotEmpty || _selectedSpecies != null
                  ? 'No pets match your filters'
                  : 'No pets yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
            SizedBox(height: AppTheme.spacing2),
            Text(
              _searchQuery.isNotEmpty || _selectedSpecies != null
                  ? 'Try adjusting your search or filters'
                  : 'Add your first pet to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty && _selectedSpecies == null) ...[
              SizedBox(height: AppTheme.spacing6),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PetFormPage(),
                    ),
                  );
                },
                icon: Icon(Icons.add),
                label: Text('Add Your First Pet'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing6,
                    vertical: AppTheme.spacing4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToPetDetails(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> petRef,
  ) {
    final eventProvider = context.read<EventProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: eventProvider,
          child: PetDetailsPage(petRef: petRef),
        ),
      ),
    );
  }

  List<String> _extractSpecies(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) => doc.data()['species'] as String?)
        .where((s) => s != null && s.isNotEmpty)
        .map((s) => s!)
        .toSet()
        .toList()
      ..sort();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterPets(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final pet = doc.data();
      final name = (pet['name'] as String? ?? '').toLowerCase();
      final species = pet['species'] as String? ?? '';
      final breed = (pet['breed'] as String? ?? '').toLowerCase();

      final matchesSearch =
          _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          breed.contains(_searchQuery.toLowerCase());

      final matchesSpecies =
          _selectedSpecies == null || species == _selectedSpecies;

      return matchesSearch && matchesSpecies;
    }).toList();
  }

  String? _calculateAge(dynamic dateOfBirth) {
    if (dateOfBirth == null) return null;

    DateTime birthDate;
    if (dateOfBirth is Timestamp) {
      birthDate = dateOfBirth.toDate();
    } else if (dateOfBirth is DateTime) {
      birthDate = dateOfBirth;
    } else {
      return null;
    }

    final now = DateTime.now();
    final years = now.year - birthDate.year;
    final months = now.month - birthDate.month;
    final days = now.day - birthDate.day;

    int ageYears = years;
    int ageMonths = months;

    if (days < 0) {
      ageMonths--;
    }
    if (ageMonths < 0) {
      ageYears--;
      ageMonths += 12;
    }

    if (ageYears > 0) {
      return '$ageYears yr${ageYears > 1 ? 's' : ''}';
    } else if (ageMonths > 0) {
      return '$ageMonths mo${ageMonths > 1 ? 's' : ''}';
    } else {
      return '< 1 mo';
    }
  }
}
