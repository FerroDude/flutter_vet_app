import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

        return Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            title: Text(
              owner.displayName.isEmpty ? owner.email : owner.displayName,
            ),
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.neutral700,
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
            padding: const EdgeInsets.all(16),
            children: [
              _buildOwnerCard(context, owner),
              const SizedBox(height: 16),
              _buildPetsSection(context, pets),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOwnerCard(BuildContext context, UserProfile owner) {
    final name =
        owner.displayName.isNotEmpty ? owner.displayName : owner.email;

    return Card(
      color: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.neutral700.withValues(alpha: 0.08),
              child: Text(
                (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutral700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  if (owner.email.isNotEmpty)
                    Text(
                      owner.email,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey[700]),
                    ),
                  if (owner.phone != null && owner.phone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      owner.phone!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey[700]),
                    ),
                  ],
                  if (owner.address != null && owner.address!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      owner.address!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey[700]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetsSection(BuildContext context, List<Pet> pets) {
    return Card(
      color: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius3),
        ).borderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pets',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (pets.isEmpty)
              Text(
                'No pets found',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              )
            else
              ...pets.map((p) => _buildPetTile(context, p)),
          ],
        ),
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Colors.grey[200],
        child: const Icon(Icons.pets, color: Colors.black87),
      ),
      title: Text(pet.name),
      subtitle: details.isNotEmpty ? Text(details.join(' · ')) : null,
      trailing: (pet.weightKg != null)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${pet.weightKg!.toStringAsFixed(1)} kg'),
            )
          : null,
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
