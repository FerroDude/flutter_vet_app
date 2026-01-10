import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import '../../theme/app_theme.dart';
import '../../models/pet_model.dart';

/// A widget that fetches and displays pet information from Firestore.
/// Used to show pet details in chat requests and chat rooms.
class PetInfoWidget extends StatelessWidget {
  final String petOwnerId;
  final String petId;
  final PetInfoStyle style;
  final VoidCallback? onTap;

  const PetInfoWidget({
    super.key,
    required this.petOwnerId,
    required this.petId,
    this.style = PetInfoStyle.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(petOwnerId)
          .collection('pets')
          .doc(petId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return _buildErrorState();
        }

        final petData = snapshot.data!.data()!;
        final pet = Pet.fromJson(petData, petId, petOwnerId);

        return _buildPetInfo(context, pet);
      },
    );
  }

  Widget _buildLoadingState() {
    switch (style) {
      case PetInfoStyle.card:
      case PetInfoStyle.compact:
        return Container(
          padding: EdgeInsets.all(AppTheme.spacing3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radius3),
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
              Gap(AppTheme.spacing3),
              Container(
                width: 80.w,
                height: 12.h,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      case PetInfoStyle.header:
        return SizedBox(
          height: 24.h,
          child: Center(
            child: SizedBox(
              width: 16.w,
              height: 16.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      case PetInfoStyle.chip:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(width: 60.w, height: 14.h),
        );
    }
  }

  Widget _buildErrorState() {
    switch (style) {
      case PetInfoStyle.card:
      case PetInfoStyle.compact:
        return Container(
          padding: EdgeInsets.all(AppTheme.spacing3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radius3),
          ),
          child: Row(
            children: [
              Icon(
                Icons.pets,
                color: Colors.white.withValues(alpha: 0.5),
                size: 20.sp,
              ),
              Gap(AppTheme.spacing2),
              Text(
                'Pet info unavailable',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        );
      case PetInfoStyle.header:
      case PetInfoStyle.chip:
        return Text(
          'Pet info unavailable',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12.sp,
          ),
        );
    }
  }

  Widget _buildPetInfo(BuildContext context, Pet pet) {
    switch (style) {
      case PetInfoStyle.card:
        return _buildCardStyle(context, pet);
      case PetInfoStyle.compact:
        return _buildCompactStyle(context, pet);
      case PetInfoStyle.header:
        return _buildHeaderStyle(context, pet);
      case PetInfoStyle.chip:
        return _buildChipStyle(context, pet);
    }
  }

  Widget _buildCardStyle(BuildContext context, Pet pet) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius3),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacing3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            _buildPetAvatar(pet, size: 48.w),
            Gap(AppTheme.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    _getPetSubtitle(pet),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.neutral700,
                    ),
                  ),
                  if (pet.birthDate != null) ...[
                    Gap(2.h),
                    Text(
                      _calculateAge(pet.birthDate!),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.neutral600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: AppTheme.neutral600,
                size: 20.sp,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStyle(BuildContext context, Pet pet) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius3),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacing2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPetAvatar(pet, size: 32.w, darkMode: true),
            Gap(AppTheme.spacing2),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pet.name,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getPetSubtitle(pet),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStyle(BuildContext context, Pet pet) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius2),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pets,
              size: 14.sp,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            Gap(6.w),
            Text(
              '${pet.name}${pet.species != null ? ' • ${pet.species}' : ''}',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            if (onTap != null) ...[
              Gap(4.w),
              Icon(
                Icons.info_outline,
                size: 14.sp,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChipStyle(BuildContext context, Pet pet) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, size: 14.sp, color: AppTheme.primary),
            Gap(6.w),
            Text(
              pet.name,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetAvatar(
    Pet pet, {
    required double size,
    bool darkMode = false,
  }) {
    if (pet.photoUrl != null && pet.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: pet.photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: darkMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pets,
              size: size * 0.5,
              color: darkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppTheme.primary.withValues(alpha: 0.5),
            ),
          ),
          errorWidget: (context, url, error) =>
              _buildDefaultAvatar(pet, size, darkMode),
        ),
      );
    }
    return _buildDefaultAvatar(pet, size, darkMode);
  }

  Widget _buildDefaultAvatar(Pet pet, double size, bool darkMode) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: darkMode
            ? Colors.white.withValues(alpha: 0.2)
            : AppTheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          pet.name.isNotEmpty ? pet.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: darkMode ? Colors.white : AppTheme.primary,
          ),
        ),
      ),
    );
  }

  String _getPetSubtitle(Pet pet) {
    final parts = <String>[];
    if (pet.species != null && pet.species!.isNotEmpty) {
      parts.add(pet.species!);
    }
    if (pet.breed != null && pet.breed!.isNotEmpty) {
      parts.add(pet.breed!);
    }
    return parts.isEmpty ? 'Pet' : parts.join(' • ');
  }

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    final years = now.year - birthDate.year;
    final months = now.month - birthDate.month;

    int totalMonths = years * 12 + months;
    if (now.day < birthDate.day) {
      totalMonths--;
    }

    if (totalMonths < 1) {
      return 'Less than 1 month old';
    } else if (totalMonths < 12) {
      return '$totalMonths month${totalMonths == 1 ? '' : 's'} old';
    } else {
      final y = totalMonths ~/ 12;
      final m = totalMonths % 12;
      if (m == 0) {
        return '$y year${y == 1 ? '' : 's'} old';
      }
      return '$y year${y == 1 ? '' : 's'}, $m month${m == 1 ? '' : 's'} old';
    }
  }
}

/// Different display styles for the PetInfoWidget
enum PetInfoStyle {
  /// Full card with photo, name, species/breed, and age
  card,

  /// Compact version for inline display
  compact,

  /// Minimal header style for app bar subtitles
  header,

  /// Small chip style for tags
  chip,
}

/// A widget to select a pet from a list of the owner's pets.
/// Used in the chat request dialog.
class PetSelector extends StatelessWidget {
  final String petOwnerId;
  final String? selectedPetId;
  final ValueChanged<String?> onPetSelected;

  const PetSelector({
    super.key,
    required this.petOwnerId,
    required this.selectedPetId,
    required this.onPetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(petOwnerId)
          .collection('pets')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading pets');
        }

        final pets = snapshot.data?.docs ?? [];

        if (pets.isEmpty) {
          return _buildErrorState('No pets found. Add a pet first.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a pet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: AppTheme.spacing2),
            SizedBox(
              height: 100.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pets.length,
                separatorBuilder: (_, __) => SizedBox(width: AppTheme.spacing2),
                itemBuilder: (context, index) {
                  final petDoc = pets[index];
                  final petData = petDoc.data();
                  final pet = Pet.fromJson(petData, petDoc.id, petOwnerId);
                  final isSelected = selectedPetId == pet.id;

                  return _buildPetCard(pet, isSelected);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a pet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppTheme.spacing2),
        SizedBox(
          height: 100.h,
          child: Center(
            child: SizedBox(
              width: 24.w,
              height: 24.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20.sp),
          SizedBox(width: AppTheme.spacing2),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(Pet pet, bool isSelected) {
    return GestureDetector(
      onTap: () => onPetSelected(pet.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80.w,
        padding: EdgeInsets.all(AppTheme.spacing2),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppTheme.cardShadow : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPetAvatar(pet, isSelected),
            SizedBox(height: 6.h),
            Text(
              pet.name,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (pet.species != null) ...[
              SizedBox(height: 2.h),
              Text(
                pet.species!,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: isSelected
                      ? AppTheme.neutral700
                      : Colors.white.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPetAvatar(Pet pet, bool isSelected) {
    final size = 36.w;

    if (pet.photoUrl != null && pet.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: pet.photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              _buildDefaultAvatar(pet, size, isSelected),
          errorWidget: (context, url, error) =>
              _buildDefaultAvatar(pet, size, isSelected),
        ),
      );
    }
    return _buildDefaultAvatar(pet, size, isSelected);
  }

  Widget _buildDefaultAvatar(Pet pet, double size, bool isSelected) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primary.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          pet.name.isNotEmpty ? pet.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.primary : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// A detailed pet info panel for displaying in chat rooms.
/// Shows comprehensive pet information that vets need.
class PetInfoPanel extends StatelessWidget {
  final String petOwnerId;
  final String petId;
  final VoidCallback? onClose;

  const PetInfoPanel({
    super.key,
    required this.petOwnerId,
    required this.petId,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(petOwnerId)
          .collection('pets')
          .doc(petId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return _buildErrorState();
        }

        final petData = snapshot.data!.data()!;
        final pet = Pet.fromJson(petData, petId, petOwnerId);

        return _buildPetPanel(context, pet);
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: AppTheme.spacing2),
          Text('Unable to load pet information'),
        ],
      ),
    );
  }

  Widget _buildPetPanel(BuildContext context, Pet pet) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            children: [
              Text(
                'Pet Information',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const Spacer(),
              if (onClose != null)
                IconButton(
                  icon: Icon(Icons.close, size: 20.sp),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          Divider(height: AppTheme.spacing4),

          // Pet avatar and name
          Row(
            children: [
              _buildPetAvatar(pet, 64.w),
              SizedBox(width: AppTheme.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    if (pet.species != null || pet.breed != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        [
                          pet.species,
                          pet.breed,
                        ].where((s) => s != null && s.isNotEmpty).join(' • '),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppTheme.neutral700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacing4),

          // Details grid
          Wrap(
            spacing: AppTheme.spacing4,
            runSpacing: AppTheme.spacing3,
            children: [
              if (pet.birthDate != null)
                _buildInfoItem(
                  icon: Icons.cake_outlined,
                  label: 'Age',
                  value: _calculateAge(pet.birthDate!),
                ),
              if (pet.sex != null)
                _buildInfoItem(
                  icon: pet.sex == 'Male' ? Icons.male : Icons.female,
                  label: 'Sex',
                  value: pet.sex!,
                ),
              if (pet.weightKg != null)
                _buildInfoItem(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Weight',
                  value: '${pet.weightKg!.toStringAsFixed(1)} kg',
                ),
              if (pet.microchip != null && pet.microchip!.isNotEmpty)
                _buildInfoItem(
                  icon: Icons.qr_code,
                  label: 'Microchip',
                  value: pet.microchip!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: 140.w,
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: AppTheme.neutral600),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11.sp, color: AppTheme.neutral600),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetAvatar(Pet pet, double size) {
    if (pet.photoUrl != null && pet.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: pet.photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildDefaultAvatar(pet, size),
          errorWidget: (context, url, error) => _buildDefaultAvatar(pet, size),
        ),
      );
    }
    return _buildDefaultAvatar(pet, size);
  }

  Widget _buildDefaultAvatar(Pet pet, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          pet.name.isNotEmpty ? pet.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    final years = now.year - birthDate.year;
    final months = now.month - birthDate.month;

    int totalMonths = years * 12 + months;
    if (now.day < birthDate.day) {
      totalMonths--;
    }

    if (totalMonths < 1) {
      return 'Less than 1 month';
    } else if (totalMonths < 12) {
      return '$totalMonths month${totalMonths == 1 ? '' : 's'}';
    } else {
      final y = totalMonths ~/ 12;
      final m = totalMonths % 12;
      if (m == 0) {
        return '$y year${y == 1 ? '' : 's'}';
      }
      return '$y yr${y == 1 ? '' : 's'}, $m mo';
    }
  }
}
