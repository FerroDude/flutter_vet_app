import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/event_provider.dart';
import '../../shared/widgets/list_placeholder.dart';
import '../../main.dart' show PetDetailsPage, PetFormPage;

class PetsPage extends StatelessWidget {
  const PetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pets'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PetFormPage()),
              );
            },
          ),
        ],
      ),
      body: const PetsPageContent(),
    );
  }
}

class PetsPageContent extends StatefulWidget {
  const PetsPageContent({super.key});

  @override
  State<PetsPageContent> createState() => _PetsPageContentState();
}

class _PetsPageContentState extends State<PetsPageContent> {
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
      return const Center(child: Text('Please log in to view your pets'));
    }

    return Column(
      children: [
        // Search Bar - Outside StreamBuilder to prevent rebuilds
        _buildSearchBar(),
        // Rest of content with StreamBuilder
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
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final allDocs = snapshot.data?.docs ?? [];
              final speciesSet = _extractSpecies(allDocs);
              final filteredDocs = _filterPets(allDocs);

              return Column(
                children: [
                  if (speciesSet.isNotEmpty) _buildSpeciesFilter(speciesSet),
                  Expanded(child: _buildPetsList(filteredDocs)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      key: const ValueKey('search_bar'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.05),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(seconds: 1), () {
            setState(() => _searchQuery = value);
          });
        },
        decoration: InputDecoration(
          hintText: 'Search pets...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue),
          suffixIcon:
              _searchQuery.isNotEmpty || _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _debounceTimer?.cancel();
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _searchFocusNode.unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSpeciesFilter(List<String> speciesSet) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', _selectedSpecies == null, null),
            const SizedBox(width: 8),
            ...speciesSet.map(
              (species) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  species,
                  _selectedSpecies == species,
                  species,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, String? value) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedSpecies = value),
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryBlue : AppTheme.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildPetsList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs,
  ) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: filteredDocs.isEmpty
          ? ListPlaceholder(
              key: const ValueKey('empty'),
              icon: Icons.pets_outlined,
              text: _searchQuery.isNotEmpty || _selectedSpecies != null
                  ? 'No pets match your filters'
                  : 'No pets yet',
            )
          : ListView.builder(
              key: ValueKey('list_${filteredDocs.length}'),
              padding: const EdgeInsets.all(16),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                return _buildPetCard(filteredDocs[index]);
              },
            ),
    );
  }

  Widget _buildPetCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final pet = doc.data();
    final species = pet['species'] as String? ?? 'Unknown';
    final breed = pet['breed'] as String? ?? 'Unknown';
    final age = _calculateAge(pet['dateOfBirth']);

    return Container(
      key: ValueKey(doc.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToPetDetails(doc.reference),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildPetAvatar(pet['name'] as String? ?? 'P'),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPetInfo(pet['name'], species, breed, age),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPetAvatar(String name) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildPetInfo(
    String? name,
    String species,
    String breed,
    String? age,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name ?? 'Unknown',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '$species • $breed',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
        ),
        if (age != null) ...[
          const SizedBox(height: 4),
          Text(
            age,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
          ),
        ],
      ],
    );
  }

  void _navigateToPetDetails(DocumentReference<Map<String, dynamic>> petRef) {
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
      return '$ageYears year${ageYears > 1 ? 's' : ''} old';
    } else if (ageMonths > 0) {
      return '$ageMonths month${ageMonths > 1 ? 's' : ''} old';
    } else {
      return 'Less than a month old';
    }
  }
}
