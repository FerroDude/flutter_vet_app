import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/vet_provider.dart';
import '../../services/chat_service.dart';
import '../../models/clinic_models.dart';
import '../../models/pet_model.dart';
import '../../models/symptom_models.dart';
import '../../theme/app_theme.dart';
import '../petOwners/chat_room_page.dart';

class PatientDetailPage extends StatefulWidget {
  final String ownerId;
  final String? initialExpandedPetId;
  
  const PatientDetailPage({
    super.key, 
    required this.ownerId,
    this.initialExpandedPetId,
  });

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  // Track which pets are expanded to show symptoms
  late Set<String> _expandedPets;
  // Cache symptoms for each pet
  final Map<String, List<PetSymptom>> _petSymptoms = {};
  final Map<String, bool> _loadingSymptoms = {};
  
  @override
  void initState() {
    super.initState();
    // Initialize with the pet to expand if provided
    _expandedPets = widget.initialExpandedPetId != null 
        ? {widget.initialExpandedPetId!} 
        : {};
    
    // Load symptoms for the initially expanded pet after first frame
    if (widget.initialExpandedPetId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInitialSymptoms();
      });
    }
  }

  void _loadInitialSymptoms() {
    if (widget.initialExpandedPetId == null) return;
    
    final vetProvider = context.read<VetProvider>();
    final pets = vetProvider.petsForOwner(widget.ownerId);
    
    try {
      final pet = pets.firstWhere((p) => p.id == widget.initialExpandedPetId);
      _loadSymptoms(pet, vetProvider);
    } catch (_) {
      // Pet not found yet, will load when data arrives
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<VetProvider, UserProvider>(
      builder: (context, vetProvider, userProvider, child) {
        final owner = vetProvider.patients.firstWhere(
          (u) => u.id == widget.ownerId,
          orElse: () => UserProfile(
            id: widget.ownerId,
            email: '',
            displayName: '',
            userType: UserType.petOwner,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final pets = vetProvider.petsForOwner(widget.ownerId);

        // Load symptoms for initially expanded pet if not loaded yet
        if (widget.initialExpandedPetId != null && 
            !_petSymptoms.containsKey(widget.initialExpandedPetId) &&
            _loadingSymptoms[widget.initialExpandedPetId] != true) {
          final pet = pets.where((p) => p.id == widget.initialExpandedPetId).firstOrNull;
          if (pet != null) {
            // Use post-frame callback to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_petSymptoms.containsKey(widget.initialExpandedPetId)) {
                _loadSymptoms(pet, vetProvider);
              }
            });
          }
        }

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
                _buildPetsSection(context, pets, vetProvider),
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

  Widget _buildPetsSection(BuildContext context, List<Pet> pets, VetProvider vetProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: AppTheme.spacing1, bottom: AppTheme.spacing2),
          child: Text(
            'Pets (${pets.length})',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        if (pets.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Center(
              child: Text(
                'No pets registered',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          )
        else
          ...pets.map((p) => Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacing3),
            child: _buildPetCard(context, p, vetProvider),
          )),
      ],
    );
  }

  Widget _buildPetCard(BuildContext context, Pet pet, VetProvider vetProvider) {
    final isExpanded = _expandedPets.contains(pet.id);
    final symptoms = _petSymptoms[pet.id] ?? [];
    final isLoading = _loadingSymptoms[pet.id] ?? false;
    
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Pet header - tappable to expand
          InkWell(
            onTap: () => _togglePetExpansion(pet, vetProvider),
            borderRadius: BorderRadius.circular(AppTheme.radius3),
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacing4),
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
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
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
                  if (pet.weightKg != null) ...[
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
                    Gap(AppTheme.spacing2),
                  ],
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.neutral700,
                    size: 24.sp,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded section with symptoms
          if (isExpanded) ...[
            Divider(height: 1, color: AppTheme.neutral700.withValues(alpha: 0.1)),
            Padding(
              padding: EdgeInsets.all(AppTheme.spacing4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.monitor_heart,
                        size: 16.sp,
                        color: AppTheme.primary,
                      ),
                      Gap(AppTheme.spacing2),
                      Text(
                        'Recent Symptoms',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Gap(AppTheme.spacing3),
                  if (isLoading)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacing3),
                        child: SizedBox(
                          width: 24.w,
                          height: 24.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          ),
                        ),
                      ),
                    )
                  else if (symptoms.isEmpty)
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacing3),
                      decoration: BoxDecoration(
                        color: AppTheme.neutral100,
                        borderRadius: BorderRadius.circular(AppTheme.radius2),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18.sp,
                            color: AppTheme.brandTeal,
                          ),
                          Gap(AppTheme.spacing2),
                          Text(
                            'No symptoms recorded',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppTheme.neutral700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...symptoms.map((symptom) => Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.spacing2),
                      child: _buildSymptomTile(symptom),
                    )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSymptomTile(PetSymptom symptom) {
    final timeAgo = _formatTimeAgo(symptom.timestamp);
    
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: _getSymptomColor(symptom.type).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius2),
        border: Border.all(
          color: _getSymptomColor(symptom.type).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: _getSymptomColor(symptom.type).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius2),
            ),
            child: Icon(
              _getSymptomIcon(symptom.type),
              color: _getSymptomColor(symptom.type),
              size: 16.sp,
            ),
          ),
          Gap(AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      getSymptomLabel(symptom.type),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppTheme.neutral700,
                      ),
                    ),
                  ],
                ),
                if (symptom.note != null && symptom.note!.isNotEmpty) ...[
                  Gap(4.h),
                  Text(
                    symptom.note!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.neutral700,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _togglePetExpansion(Pet pet, VetProvider vetProvider) async {
    setState(() {
      if (_expandedPets.contains(pet.id)) {
        _expandedPets.remove(pet.id);
      } else {
        _expandedPets.add(pet.id);
        // Load symptoms if not already loaded
        if (!_petSymptoms.containsKey(pet.id)) {
          _loadSymptoms(pet, vetProvider);
        }
      }
    });
  }

  Future<void> _loadSymptoms(Pet pet, VetProvider vetProvider) async {
    setState(() {
      _loadingSymptoms[pet.id] = true;
    });
    
    final symptoms = await vetProvider.getSymptomsForPet(pet.ownerId, pet.id, limit: 10);
    
    if (mounted) {
      setState(() {
        _petSymptoms[pet.id] = symptoms;
        _loadingSymptoms[pet.id] = false;
      });
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  IconData _getSymptomIcon(SymptomType type) {
    switch (type) {
      case SymptomType.vomiting:
        return Icons.sick;
      case SymptomType.diarrhea:
        return Icons.report_problem;
      case SymptomType.cough:
        return Icons.air;
      case SymptomType.sneezing:
        return Icons.masks;
      case SymptomType.choking:
        return Icons.warning;
      case SymptomType.seizure:
        return Icons.emergency;
      case SymptomType.disorientation:
        return Icons.psychology;
      case SymptomType.circling:
        return Icons.rotate_right;
      case SymptomType.restlessness:
        return Icons.run_circle;
      case SymptomType.limping:
        return Icons.accessible;
      case SymptomType.jointDiscomfort:
        return Icons.healing;
      case SymptomType.itching:
        return Icons.pets;
      case SymptomType.ocularDischarge:
        return Icons.visibility;
      case SymptomType.vaginalDischarge:
        return Icons.female;
      case SymptomType.estrus:
        return Icons.favorite;
      case SymptomType.other:
        return Icons.monitor_heart;
    }
  }

  Color _getSymptomColor(SymptomType type) {
    switch (type) {
      case SymptomType.vomiting:
      case SymptomType.diarrhea:
        return Colors.red;
      case SymptomType.choking:
      case SymptomType.seizure:
        return Colors.red.shade700;
      case SymptomType.cough:
      case SymptomType.sneezing:
        return Colors.blue;
      case SymptomType.disorientation:
      case SymptomType.circling:
      case SymptomType.restlessness:
        return Colors.orange;
      case SymptomType.limping:
      case SymptomType.jointDiscomfort:
        return Colors.purple;
      case SymptomType.itching:
      case SymptomType.ocularDischarge:
        return Colors.pink;
      case SymptomType.vaginalDischarge:
      case SymptomType.estrus:
        return Colors.teal;
      case SymptomType.other:
        return Colors.grey;
    }
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
