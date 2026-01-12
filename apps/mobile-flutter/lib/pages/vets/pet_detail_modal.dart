import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/pet_model.dart';
import '../../models/symptom_models.dart';
import '../../models/event_model.dart';
import '../../models/medication_model.dart';

/// A detailed pet information modal for vets to view pet data in chat context.
/// Shows pet info, symptoms, appointments, and medications.
class PetDetailModal extends StatefulWidget {
  final String petOwnerId;
  final String petId;

  const PetDetailModal({
    super.key,
    required this.petOwnerId,
    required this.petId,
  });

  /// Show the modal as a full-screen dialog
  static Future<void> show(
    BuildContext context, {
    required String petOwnerId,
    required String petId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) =>
            PetDetailModal(petOwnerId: petOwnerId, petId: petId),
      ),
    );
  }

  @override
  State<PetDetailModal> createState() => _PetDetailModalState();
}

class _PetDetailModalState extends State<PetDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.backgroundGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          _buildHandle(),
          // Pet info header
          _buildPetHeader(),
          // Tab bar
          _buildTabBar(),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SymptomsTab(
                  petOwnerId: widget.petOwnerId,
                  petId: widget.petId,
                ),
                _AppointmentsTab(
                  petOwnerId: widget.petOwnerId,
                  petId: widget.petId,
                ),
                _MedicationsTab(
                  petOwnerId: widget.petOwnerId,
                  petId: widget.petId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
      width: 40.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildPetHeader() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.petOwnerId)
          .collection('pets')
          .doc(widget.petId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Padding(
            padding: EdgeInsets.all(AppTheme.spacing4),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final petData = snapshot.data!.data()!;
        final pet = Pet.fromJson(petData, widget.petId, widget.petOwnerId);

        return Container(
          padding: EdgeInsets.all(AppTheme.spacing4),
          child: Row(
            children: [
              _buildPetAvatar(pet),
              Gap(AppTheme.spacing4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (pet.species != null || pet.breed != null) ...[
                      Gap(4.h),
                      Text(
                        [
                          pet.species,
                          pet.breed,
                        ].where((s) => s != null && s.isNotEmpty).join(' • '),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    Gap(8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 4.h,
                      children: [
                        if (pet.birthDate != null)
                          _buildInfoChip(
                            Icons.cake_outlined,
                            _calculateAge(pet.birthDate!),
                          ),
                        if (pet.sex != null)
                          _buildInfoChip(
                            pet.sex == 'Male' ? Icons.male : Icons.female,
                            pet.sex!,
                          ),
                        if (pet.weightKg != null)
                          _buildInfoChip(
                            Icons.monitor_weight_outlined,
                            '${pet.weightKg!.toStringAsFixed(1)} kg',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPetAvatar(Pet pet) {
    final size = 70.w;
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
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          pet.name.isNotEmpty ? pet.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: Colors.white),
          Gap(4.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            icon: Icon(Icons.healing_outlined, size: 20.sp),
            text: 'Symptoms',
          ),
          Tab(
            icon: Icon(Icons.calendar_today_outlined, size: 20.sp),
            text: 'Appointments',
          ),
          Tab(
            icon: Icon(Icons.medication_outlined, size: 20.sp),
            text: 'Medications',
          ),
        ],
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
      return '< 1 month';
    } else if (totalMonths < 12) {
      return '$totalMonths mo';
    } else {
      final y = totalMonths ~/ 12;
      final m = totalMonths % 12;
      if (m == 0) {
        return '$y yr${y == 1 ? '' : 's'}';
      }
      return '$y yr, $m mo';
    }
  }
}

/// Tab showing pet symptoms
class _SymptomsTab extends StatelessWidget {
  final String petOwnerId;
  final String petId;

  const _SymptomsTab({required this.petOwnerId, required this.petId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(petOwnerId)
          .collection('pets')
          .doc(petId)
          .collection('symptoms')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final symptoms = snapshot.data?.docs ?? [];

        if (symptoms.isEmpty) {
          return _buildEmptyState(
            icon: Icons.healing_outlined,
            title: 'No symptoms recorded',
            subtitle: 'Symptoms logged by the pet owner will appear here',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(AppTheme.spacing4),
          itemCount: symptoms.length,
          separatorBuilder: (_, __) => Gap(AppTheme.spacing2),
          itemBuilder: (context, index) {
            final doc = symptoms[index];
            final symptom = PetSymptom.fromJson(
              doc.data(),
              doc.id,
              petOwnerId,
              petId,
            );
            return _buildSymptomCard(symptom);
          },
        );
      },
    );
  }

  Widget _buildSymptomCard(PetSymptom symptom) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        border: Border.all(color: AppTheme.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: _getSymptomColor(symptom.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius2),
            ),
            child: Icon(
              _getSymptomIcon(symptom.type),
              color: _getSymptomColor(symptom.type),
              size: 20.sp,
            ),
          ),
          Gap(AppTheme.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getSymptomLabel(symptom.type),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
                Gap(4.h),
                Text(
                  '${dateFormat.format(symptom.timestamp)} at ${timeFormat.format(symptom.timestamp)}',
                  style: TextStyle(fontSize: 12.sp, color: AppTheme.neutral600),
                ),
                if (symptom.note != null && symptom.note!.isNotEmpty) ...[
                  Gap(8.h),
                  Text(
                    symptom.note!,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.neutral700,
                    ),
                    maxLines: 3,
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

  IconData _getSymptomIcon(SymptomType type) {
    switch (type) {
      case SymptomType.vomiting:
        return Icons.sick_outlined;
      case SymptomType.diarrhea:
        return Icons.water_drop_outlined;
      case SymptomType.cough:
      case SymptomType.sneezing:
        return Icons.air;
      case SymptomType.choking:
        return Icons.warning_amber;
      case SymptomType.seizure:
        return Icons.flash_on;
      case SymptomType.disorientation:
      case SymptomType.circling:
        return Icons.psychology_outlined;
      case SymptomType.restlessness:
        return Icons.directions_run;
      case SymptomType.limping:
      case SymptomType.jointDiscomfort:
        return Icons.accessibility_new;
      case SymptomType.itching:
        return Icons.pan_tool_outlined;
      case SymptomType.ocularDischarge:
        return Icons.visibility_outlined;
      case SymptomType.vaginalDischarge:
      case SymptomType.estrus:
        return Icons.favorite_outline;
      default:
        return Icons.help_outline;
    }
  }

  Color _getSymptomColor(SymptomType type) {
    switch (type) {
      case SymptomType.seizure:
      case SymptomType.choking:
        return Colors.red;
      case SymptomType.vomiting:
      case SymptomType.diarrhea:
        return Colors.orange;
      case SymptomType.cough:
      case SymptomType.sneezing:
        return Colors.blue;
      case SymptomType.limping:
      case SymptomType.jointDiscomfort:
        return Colors.purple;
      default:
        return AppTheme.primary;
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48.sp, color: Colors.white.withValues(alpha: 0.4)),
            Gap(AppTheme.spacing3),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(AppTheme.spacing2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab showing pet appointments
class _AppointmentsTab extends StatelessWidget {
  final String petOwnerId;
  final String petId;

  const _AppointmentsTab({required this.petOwnerId, required this.petId});

  @override
  Widget build(BuildContext context) {
    // Query only by petId to avoid composite index requirement
    // Filter by type client-side
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(petOwnerId)
          .collection('events')
          .where('petId', isEqualTo: petId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error loading appointments',
            subtitle: snapshot.error.toString(),
          );
        }

        // Filter appointments client-side and sort
        final allDocs = snapshot.data?.docs ?? [];
        final appointments =
            allDocs.where((doc) {
              final data = doc.data();
              return data['type'] == EventType.appointment.index;
            }).toList()..sort((a, b) {
              final aTime = a.data()['dateTime'] as int? ?? 0;
              final bTime = b.data()['dateTime'] as int? ?? 0;
              return bTime.compareTo(aTime); // Descending
            });

        if (appointments.isEmpty) {
          return _buildEmptyState(
            icon: Icons.calendar_today_outlined,
            title: 'No appointments',
            subtitle: 'Scheduled appointments will appear here',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(AppTheme.spacing4),
          itemCount: appointments.length,
          separatorBuilder: (_, __) => Gap(AppTheme.spacing2),
          itemBuilder: (context, index) {
            final doc = appointments[index];
            final data = doc.data();
            data['id'] = doc.id;
            final appointment = AppointmentEvent.fromJson(data);
            return _buildAppointmentCard(appointment);
          },
        );
      },
    );
  }

  Widget _buildAppointmentCard(AppointmentEvent appointment) {
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final isPast = appointment.dateTime.isBefore(DateTime.now());

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        border: Border.all(
          color: isPast ? AppTheme.neutral200 : AppTheme.brandTeal,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: isPast
                      ? AppTheme.neutral200
                      : AppTheme.brandTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius2),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: isPast ? AppTheme.neutral500 : AppTheme.brandTeal,
                  size: 20.sp,
                ),
              ),
              Gap(AppTheme.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: isPast ? AppTheme.neutral600 : AppTheme.primary,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      dateFormat.format(appointment.dateTime),
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppTheme.neutral700,
                      ),
                    ),
                    Text(
                      timeFormat.format(appointment.dateTime),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPast)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.brandTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Upcoming',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.brandTeal,
                    ),
                  ),
                ),
            ],
          ),
          if (appointment.description.isNotEmpty) ...[
            Gap(AppTheme.spacing3),
            Text(
              appointment.description,
              style: TextStyle(fontSize: 13.sp, color: AppTheme.neutral700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (appointment.location != null ||
              appointment.vetName != null ||
              appointment.appointmentType != null) ...[
            Gap(AppTheme.spacing2),
            Wrap(
              spacing: 12.w,
              runSpacing: 4.h,
              children: [
                if (appointment.appointmentType != null)
                  _buildDetailChip(
                    Icons.medical_services_outlined,
                    appointment.appointmentType!,
                  ),
                if (appointment.vetName != null)
                  _buildDetailChip(Icons.person_outline, appointment.vetName!),
                if (appointment.location != null)
                  _buildDetailChip(
                    Icons.location_on_outlined,
                    appointment.location!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: AppTheme.neutral600),
        Gap(4.w),
        Text(
          text,
          style: TextStyle(fontSize: 12.sp, color: AppTheme.neutral600),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48.sp, color: Colors.white.withValues(alpha: 0.4)),
            Gap(AppTheme.spacing3),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(AppTheme.spacing2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab showing pet medications (using new Medication model)
class _MedicationsTab extends StatelessWidget {
  final String petOwnerId;
  final String petId;

  const _MedicationsTab({required this.petOwnerId, required this.petId});

  @override
  Widget build(BuildContext context) {
    // Query the new medications subcollection under pets
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(petOwnerId)
          .collection('pets')
          .doc(petId)
          .collection('medications')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error loading medications',
            subtitle: snapshot.error.toString(),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        
        // Parse medications
        final medications = allDocs.map((doc) {
          return Medication.fromJson(doc.data(), doc.id);
        }).toList();

        // Separate active and past medications
        final activeMedications = medications
            .where((m) => m.status == MedicationStatus.active)
            .toList();
        final pastMedications = medications
            .where((m) => m.status != MedicationStatus.active)
            .toList();

        if (medications.isEmpty) {
          return _buildEmptyState(
            icon: Icons.medication_outlined,
            title: 'No medications',
            subtitle: 'Medication schedules will appear here',
          );
        }

        return ListView(
          padding: EdgeInsets.all(AppTheme.spacing4),
          children: [
            // Active medications section
            if (activeMedications.isNotEmpty) ...[
              _buildSectionHeader('Current Medications', activeMedications.length),
              Gap(AppTheme.spacing2),
              ...activeMedications.map((med) => Padding(
                padding: EdgeInsets.only(bottom: AppTheme.spacing2),
                child: _buildMedicationCard(med),
              )),
            ],
            
            // Past medications section
            if (pastMedications.isNotEmpty) ...[
              Gap(AppTheme.spacing4),
              _buildSectionHeader('Medication History', pastMedications.length),
              Gap(AppTheme.spacing2),
              ...pastMedications.map((med) => Padding(
                padding: EdgeInsets.only(bottom: AppTheme.spacing2),
                child: _buildMedicationCard(med),
              )),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        Gap(8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationCard(Medication medication) {
    final isActive = medication.isActive;
    final dateFormat = DateFormat('MMM d, yyyy');
    final progress = medication.progress;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        border: Border.all(
          color: isActive ? AppTheme.brandTeal : AppTheme.neutral200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.brandTeal.withValues(alpha: 0.1)
                      : AppTheme.neutral200,
                  borderRadius: BorderRadius.circular(AppTheme.radius2),
                ),
                child: Icon(
                  Icons.medication_rounded,
                  color: isActive
                      ? AppTheme.brandTeal
                      : AppTheme.neutral500,
                  size: 20.sp,
                ),
              ),
              Gap(AppTheme.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppTheme.primary
                            : AppTheme.neutral600,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      medication.dosage,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppTheme.neutral700,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(medication.status),
            ],
          ),
          Gap(AppTheme.spacing3),
          // Medication details
          Wrap(
            spacing: 16.w,
            runSpacing: 8.h,
            children: [
              _buildDetailItem(
                Icons.repeat,
                'Frequency',
                medication.frequencyDisplay,
              ),
              _buildDetailItem(
                Icons.calendar_today_outlined,
                'Started',
                dateFormat.format(medication.startDate),
              ),
              if (medication.calculatedEndDate != null)
                _buildDetailItem(
                  Icons.event_outlined,
                  'Ends',
                  dateFormat.format(medication.calculatedEndDate!),
                ),
              if (medication.nextDoseDescription != null)
                _buildDetailItem(
                  Icons.schedule_outlined,
                  'Next Dose',
                  medication.nextDoseDescription!.replaceFirst('Next: ', ''),
                ),
            ],
          ),
          // Progress bar for time-limited medications
          if (isActive && progress != null) ...[
            Gap(AppTheme.spacing3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.neutral200,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandTeal),
                minHeight: 6.h,
              ),
            ),
            if (medication.totalExpectedDoses != null) ...[
              Gap(AppTheme.spacing2),
              Text(
                '${medication.totalDosesTaken} of ${medication.totalExpectedDoses} doses taken',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppTheme.neutral500,
                ),
              ),
            ],
          ],
          // For "as needed" medications - show doses logged
          if (isActive && medication.frequency == MedicationFrequency.asNeeded) ...[
            Gap(AppTheme.spacing3),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacing3,
                vertical: AppTheme.spacing2,
              ),
              decoration: BoxDecoration(
                color: AppTheme.brandTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 16.sp,
                    color: AppTheme.brandTeal,
                  ),
                  Gap(8.w),
                  Text(
                    medication.totalDosesTaken > 0
                        ? '${medication.totalDosesTaken} dose${medication.totalDosesTaken == 1 ? '' : 's'} logged'
                        : 'No doses logged yet',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.brandTeal,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (medication.instructions != null &&
              medication.instructions!.isNotEmpty) ...[
            Gap(AppTheme.spacing3),
            Container(
              padding: EdgeInsets.all(AppTheme.spacing2),
              decoration: BoxDecoration(
                color: AppTheme.neutral100,
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16.sp,
                    color: AppTheme.neutral600,
                  ),
                  Gap(8.w),
                  Expanded(
                    child: Text(
                      medication.instructions!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.neutral700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(MedicationStatus status) {
    Color color;
    String label;

    switch (status) {
      case MedicationStatus.active:
        color = AppTheme.success;
        label = 'Active';
        break;
      case MedicationStatus.paused:
        color = AppTheme.warning;
        label = 'Paused';
        break;
      case MedicationStatus.completed:
        color = AppTheme.neutral600;
        label = 'Completed';
        break;
      case MedicationStatus.discontinued:
        color = AppTheme.error;
        label = 'Stopped';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14.sp, color: AppTheme.neutral500),
            Gap(4.w),
            Text(
              label,
              style: TextStyle(fontSize: 11.sp, color: AppTheme.neutral500),
            ),
          ],
        ),
        Gap(2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: AppTheme.neutral800,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48.sp, color: Colors.white.withValues(alpha: 0.4)),
            Gap(AppTheme.spacing3),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(AppTheme.spacing2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
