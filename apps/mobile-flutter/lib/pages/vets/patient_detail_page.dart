import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../providers/user_provider.dart';
import '../../providers/vet_provider.dart';
import '../../services/chat_service.dart';
import '../../models/clinic_models.dart';
import '../../models/pet_model.dart';
import '../../theme/app_theme.dart';
import '../petOwners/chat_room_page.dart';

class PatientDetailPage extends StatelessWidget {
  final String ownerId;
  const PatientDetailPage({super.key, required this.ownerId});

  @override
  Widget build(BuildContext context) {
    return Consumer2<VetProvider, UserProvider>(
      builder: (context, vetProvider, userProvider, child) {
        final owner = vetProvider.patients.firstWhere(
          (u) => u.id == ownerId,
          orElse: () => UserProfile(
            id: ownerId,
            email: '',
            displayName: '',
            userType: UserType.petOwner,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final pets = vetProvider.petsForOwner(ownerId);

        return Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                owner.displayName.isEmpty ? owner.email : owner.displayName,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble),
                  tooltip: 'Chat with owner',
                  onPressed:
                      (userProvider.connectedClinic?.id != null &&
                          userProvider.currentUser != null)
                      ? () => _startChat(context, userProvider, owner)
                      : null,
                ),
              ],
            ),
            body: ListView(
              padding: EdgeInsets.all(AppTheme.spacing4),
              children: [
                _buildOwnerCard(context, owner),
                Gap(AppTheme.spacing4),
                _buildPetsSection(context, pets),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOwnerCard(BuildContext context, UserProfile owner) {
    final name =
        owner.displayName.isNotEmpty ? owner.displayName : owner.email;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: EdgeInsets.all(AppTheme.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Text(
              (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
          Gap(AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
                Gap(AppTheme.spacing1),
                if (owner.email.isNotEmpty)
                  Text(
                    owner.email,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.neutral700,
                    ),
                  ),
                if (owner.phone != null && owner.phone!.isNotEmpty) ...[
                  Gap(2),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 14.sp, color: AppTheme.neutral700),
                      Gap(AppTheme.spacing1),
                      Text(
                        owner.phone!,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppTheme.neutral700,
                        ),
                      ),
                    ],
                  ),
                ],
                if (owner.address != null && owner.address!.isNotEmpty) ...[
                  Gap(AppTheme.spacing2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14.sp, color: AppTheme.neutral700),
                      Gap(AppTheme.spacing1),
                      Expanded(
                        child: Text(
                          owner.address!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppTheme.neutral700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetsSection(BuildContext context, List<Pet> pets) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: EdgeInsets.all(AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pets',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
          Gap(AppTheme.spacing3),
          if (pets.isEmpty)
            Text(
              'No pets found',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.neutral700,
              ),
            )
          else
            ...pets.map((p) => _buildPetTile(context, p)),
        ],
      ),
    );
  }

  Widget _buildPetTile(BuildContext context, Pet pet) {
    final details = <String>[];
    if (pet.species != null && pet.species!.isNotEmpty) {
      details.add(pet.species!);
    }
    if (pet.breed != null && pet.breed!.isNotEmpty) {
      details.add(pet.breed!);
    }
    if (pet.sex != null && pet.sex!.isNotEmpty) {
      details.add(pet.sex!);
    }
    if (pet.birthDate != null) {
      final now = DateTime.now();
      var years = now.year - pet.birthDate!.year;
      if (now.month < pet.birthDate!.month ||
          (now.month == pet.birthDate!.month &&
              now.day < pet.birthDate!.day)) {
        years--;
      }
      if (years > 0) {
        details.add('$years years old');
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing2),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.brandTeal.withValues(alpha: 0.1),
            child: Icon(Icons.pets, color: AppTheme.brandTeal, size: 20.sp),
          ),
          Gap(AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details.join(' · '),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.neutral700,
                    ),
                  ),
              ],
            ),
          ),
          if (pet.weightKg != null)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacing2,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${pet.weightKg!.toStringAsFixed(1)} kg',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startChat(
    BuildContext context,
    UserProvider userProvider,
    UserProfile owner,
  ) async {
    try {
      final clinicId = userProvider.connectedClinic!.id;
      final vetId = userProvider.currentUser!.id;
      final vetName = userProvider.currentUser!.displayName;
      final petIds = const <String>[]; // could derive from owner pets if needed

      final chatService = ChatService();
      final chatRoomId = await chatService.findOrCreateOneOnOneChat(
        clinicId: clinicId,
        petOwnerId: owner.id,
        petOwnerName: owner.displayName.isEmpty
            ? owner.email
            : owner.displayName,
        vetId: vetId,
        vetName: vetName,
        petIds: petIds,
      );

      final chatRoom = await chatService.getChatRoom(chatRoomId);
      if (chatRoom != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatRoomPage(chatRoom: chatRoom)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
