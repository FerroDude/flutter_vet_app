import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/medication_model.dart';
import '../providers/medication_provider.dart';
import '../theme/app_theme.dart';
import 'modern_modals.dart';

// ============ Medication Card Widget ============

/// A card displaying a medication with key info and actions
class MedicationCard extends StatelessWidget {
  final Medication medication;
  final String? petName;
  final bool showPetName;
  final VoidCallback? onTap;
  final VoidCallback? onMarkDose;

  const MedicationCard({
    super.key,
    required this.medication,
    this.petName,
    this.showPetName = false,
    this.onTap,
    this.onMarkDose,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = medication.isActive;
    final progress = medication.progress;
    final nextDose = medication.nextDose;

    return GestureDetector(
      onTap: onTap ?? () => _showMedicationDetail(context),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          // Glassy look - semi-transparent white
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radius3),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Main content
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Medication icon
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.brandTeal.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medication_rounded,
                      color: isActive ? AppTheme.brandTeal : Colors.white.withValues(alpha: 0.6),
                      size: 24.sp,
                    ),
                  ),
                  Gap(12.w),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and pet
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                medication.name,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (showPetName && petName != null) ...[
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  petName!,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Gap(4.h),
                        // Dosage and frequency
                        Text(
                          '${medication.dosage} • ${medication.frequencyDisplay}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        Gap(8.h),
                        // Status row
                        Row(
                          children: [
                            if (isActive && nextDose != null) ...[
                              Icon(
                                Icons.access_time_rounded,
                                size: 14.sp,
                                color: AppTheme.brandTeal,
                              ),
                              Gap(4.w),
                              Text(
                                _formatNextDose(nextDose),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.brandTeal,
                                ),
                              ),
                            ],
                            if (medication.totalDays != null) ...[
                              if (isActive && nextDose != null) Gap(12.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Day ${medication.currentDay} of ${medication.totalDays}',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                            if (!isActive) ...[
                              _buildStatusBadge(medication.status),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Quick action button
                  if (isActive && onMarkDose != null) ...[
                    Gap(8.w),
                    GestureDetector(
                      onTap: onMarkDose,
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: AppTheme.success,
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Progress bar for time-limited medications
            if (isActive && progress != null)
              Container(
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(AppTheme.radius3),
                  ),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.brandTeal,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(MedicationStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case MedicationStatus.completed:
        color = AppTheme.success;
        label = 'Completed';
        icon = Icons.check_circle_outline;
        break;
      case MedicationStatus.paused:
        color = AppTheme.warning;
        label = 'Paused';
        icon = Icons.pause_circle_outline;
        break;
      case MedicationStatus.discontinued:
        color = AppTheme.error;
        label = 'Stopped';
        icon = Icons.cancel_outlined;
        break;
      case MedicationStatus.active:
        color = AppTheme.brandTeal;
        label = 'Active';
        icon = Icons.play_circle_outline;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          Gap(4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNextDose(DateTime nextDose) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final doseDate = DateTime(nextDose.year, nextDose.month, nextDose.day);

    final timeFormat = DateFormat('h:mm a');
    final time = timeFormat.format(nextDose);

    if (doseDate == today) {
      return 'Next: Today at $time';
    } else if (doseDate == tomorrow) {
      return 'Next: Tomorrow at $time';
    } else {
      return 'Next: ${DateFormat('MMM d').format(nextDose)} at $time';
    }
  }

  void _showMedicationDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MedicationDetailSheet(medication: medication),
    );
  }
}

// ============ Medication Detail Sheet ============

/// Bottom sheet showing full medication details
class MedicationDetailSheet extends StatelessWidget {
  final Medication medication;

  const MedicationDetailSheet({super.key, required this.medication});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(24.w),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 56.w,
                          height: 56.w,
                          decoration: BoxDecoration(
                            color: AppTheme.brandTeal.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.brandTeal.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.medication_rounded,
                            color: AppTheme.brandTeal,
                            size: 28.sp,
                          ),
                        ),
                        Gap(16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medication.name,
                                style: TextStyle(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Gap(4.h),
                              Text(
                                medication.dosage,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Close button
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 20.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Gap(24.h),
                    // Info tiles
                    _buildInfoTile(
                      context,
                      icon: Icons.repeat_rounded,
                      label: 'Frequency',
                      value: medication.frequencyDisplay,
                    ),
                    _buildInfoTile(
                      context,
                      icon: Icons.calendar_today_rounded,
                      label: 'Started',
                      value: DateFormat('MMMM d, yyyy').format(medication.startDate),
                    ),
                    if (medication.calculatedEndDate != null)
                      _buildInfoTile(
                        context,
                        icon: Icons.event_rounded,
                        label: 'Ends',
                        value: DateFormat('MMMM d, yyyy').format(medication.calculatedEndDate!),
                      ),
                    if (medication.instructions != null && medication.instructions!.isNotEmpty)
                      _buildInfoTile(
                        context,
                        icon: Icons.notes_rounded,
                        label: 'Instructions',
                        value: medication.instructions!,
                      ),
                    if (medication.totalDays != null) ...[
                      Gap(16.h),
                      _buildProgressSection(context),
                    ],
                    Gap(24.h),
                    // Actions
                    if (medication.isActive) ...[
                      _buildActionButtons(context),
                    ] else ...[
                      _buildInactiveActions(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18.sp,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Gap(2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    final progress = medication.progress ?? 0.0;
    final daysRemaining = medication.daysRemaining ?? 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.brandTeal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.brandTeal.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.brandTeal,
                ),
              ),
            ],
          ),
          Gap(12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.brandTeal),
              minHeight: 8.h,
            ),
          ),
          Gap(12.h),
          Text(
            'Day ${medication.currentDay} of ${medication.totalDays} • $daysRemaining days remaining',
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Mark dose taken - primary action
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _markDoseTaken(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.check_rounded),
            label: Text(
              'Mark Dose Taken',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Gap(12.h),
        // Secondary actions - glassy style
        Row(
          children: [
            Expanded(
              child: _buildGlassyButton(
                onPressed: () => _showEditForm(context),
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: Colors.white,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: _buildGlassyButton(
                onPressed: () => _pauseMedication(context),
                icon: Icons.pause_rounded,
                label: 'Pause',
                color: AppTheme.warning,
              ),
            ),
          ],
        ),
        Gap(12.h),
        // Stop medication
        _buildGlassyButton(
          onPressed: () => _stopMedication(context),
          icon: Icons.stop_circle_outlined,
          label: 'Stop Medication',
          color: AppTheme.error,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildGlassyButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isFullWidth = false,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(icon, size: 18.sp, color: color),
                Gap(8.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInactiveActions(BuildContext context) {
    if (medication.status == MedicationStatus.paused) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _resumeMedication(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandTeal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                'Resume Medication',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Gap(12.h),
          _buildGlassyButton(
            onPressed: () => _deleteMedication(context),
            icon: Icons.delete_outline,
            label: 'Delete',
            color: AppTheme.error,
            isFullWidth: true,
          ),
        ],
      );
    }

    return _buildGlassyButton(
      onPressed: () => _deleteMedication(context),
      icon: Icons.delete_outline,
      label: 'Delete Medication',
      color: AppTheme.error,
      isFullWidth: true,
    );
  }

  void _markDoseTaken(BuildContext context) async {
    final provider = context.read<MedicationProvider>();
    await provider.logDoseTaken(
      medication.petId,
      medication.id,
      DateTime.now(),
    );
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dose marked as taken'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _showEditForm(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => MedicationFormDialog(
        petId: medication.petId,
        existingMedication: medication,
      ),
    );
  }

  void _pauseMedication(BuildContext context) async {
    final provider = context.read<MedicationProvider>();
    await provider.pauseMedication(medication.petId, medication.id);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medication paused'),
          backgroundColor: AppTheme.warning,
        ),
      );
    }
  }

  void _resumeMedication(BuildContext context) async {
    final provider = context.read<MedicationProvider>();
    await provider.resumeMedication(medication.petId, medication.id);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medication resumed'),
          backgroundColor: AppTheme.brandTeal,
        ),
      );
    }
  }

  void _stopMedication(BuildContext context) async {
    final confirmed = await showModernConfirmDialog(
      context,
      title: 'Stop Medication',
      message: 'This will mark "${medication.name}" as discontinued. You can delete it later if needed.',
      confirmText: 'Stop',
      confirmColor: AppTheme.error,
      icon: Icons.stop_circle_outlined,
      iconColor: AppTheme.error,
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<MedicationProvider>();
      await provider.discontinueMedication(medication.petId, medication.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medication stopped'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _deleteMedication(BuildContext context) async {
    final confirmed = await showModernConfirmDialog(
      context,
      title: 'Delete Medication',
      message: 'This will permanently delete "${medication.name}". This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: AppTheme.error,
      icon: Icons.delete_outline,
      iconColor: AppTheme.error,
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<MedicationProvider>();
      await provider.deleteMedication(medication.petId, medication.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medication deleted'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

// ============ Medication Form Dialog ============

/// Dialog for adding or editing a medication
class MedicationFormDialog extends StatefulWidget {
  final String? petId;
  final Medication? existingMedication;

  const MedicationFormDialog({
    super.key,
    this.petId,
    this.existingMedication,
  });

  @override
  State<MedicationFormDialog> createState() => _MedicationFormDialogState();
}

class _MedicationFormDialogState extends State<MedicationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _instructionsController;

  String? _selectedPetId;
  MedicationFrequency _frequency = MedicationFrequency.daily;
  DateTime _startDate = DateTime.now();
  TimeOfDay _doseTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? _secondDoseTime;
  bool _hasEndDate = false;
  int _durationDays = 7;
  bool _remindersEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingMedication;

    _nameController = TextEditingController(text: existing?.name ?? '');
    _dosageController = TextEditingController(text: existing?.dosage ?? '');
    _instructionsController = TextEditingController(text: existing?.instructions ?? '');
    _selectedPetId = widget.petId ?? existing?.petId;

    if (existing != null) {
      _frequency = existing.frequency;
      _startDate = existing.startDate;
      if (existing.doseTimes.isNotEmpty) {
        _doseTime = existing.doseTimes.first;
        if (existing.doseTimes.length > 1) {
          _secondDoseTime = existing.doseTimes[1];
        }
      }
      _hasEndDate = existing.totalDays != null;
      _durationDays = existing.totalDays ?? 7;
      _remindersEnabled = existing.remindersEnabled;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingMedication != null;

    return ModernModal(
      width: MediaQuery.of(context).size.width * 0.95,
      useGradient: true,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModernModalHeader(
                title: isEditing ? 'Edit Medication' : 'Add Medication',
                icon: Icons.medication_rounded,
                iconColor: AppTheme.brandTeal,
                useGradientStyle: true,
              ),
              const SizedBox(height: 24),

              // Medication name
              _buildTextField(
                controller: _nameController,
                label: 'Medication Name',
                hint: 'e.g., Amoxicillin, Vitamins',
                icon: Icons.medication,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter medication name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Pet selector (if not pre-selected)
              if (_selectedPetId == null) ...[
                _buildPetSelector(),
                const SizedBox(height: 16),
              ],

              // Dosage
              _buildTextField(
                controller: _dosageController,
                label: 'Dosage',
                hint: 'e.g., 250mg, 1 tablet, 5ml',
                icon: Icons.scale,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter dosage';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Frequency
              _buildFrequencySelector(),
              const SizedBox(height: 16),

              // Dose time(s)
              _buildTimeSelector(),
              const SizedBox(height: 16),

              // Duration
              _buildDurationSelector(),
              const SizedBox(height: 16),

              // Instructions
              _buildTextField(
                controller: _instructionsController,
                label: 'Instructions (Optional)',
                hint: 'e.g., Take with food, avoid dairy',
                icon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Reminders toggle
              _buildRemindersToggle(),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  if (isEditing) ...[
                    Expanded(
                      child: ModernModalButton(
                        text: 'Delete',
                        isPrimary: false,
                        useGradientStyle: true,
                        onPressed: _deleteMedication,
                        icon: Icons.delete_outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: isEditing ? 2 : 1,
                    child: ModernModalButton(
                      text: isEditing ? 'Update' : 'Add Medication',
                      isLoading: _isLoading,
                      onPressed: _saveMedication,
                      color: AppTheme.brandTeal,
                      icon: isEditing ? Icons.check : Icons.add,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return ModernModalTextField(
      controller: controller,
      label: label,
      hint: hint,
      icon: icon,
      validator: validator,
      maxLines: maxLines,
      useGradientStyle: true,
    );
  }

  Widget _buildPetSelector() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('pets')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ModernModalTextField(
            label: 'Pet',
            hint: 'Loading pets...',
            icon: Icons.pets,
            readOnly: true,
            useGradientStyle: true,
          );
        }

        final pets = snapshot.data!.docs;
        if (pets.isEmpty) {
          return ModernModalTextField(
            label: 'Pet',
            hint: 'No pets found',
            icon: Icons.pets,
            readOnly: true,
            useGradientStyle: true,
          );
        }

        // Auto-select first pet if none selected
        if (_selectedPetId == null && pets.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _selectedPetId = pets.first.id);
          });
        }

        return ModernModalDropdown<String>(
          label: 'Pet',
          value: _selectedPetId ?? pets.first.id,
          icon: Icons.pets,
          useGradientStyle: true,
          items: pets.map((doc) {
            final data = doc.data();
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(data['name'] ?? 'Unknown'),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedPetId = value),
        );
      },
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequency',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MedicationFrequency.values.map((freq) {
            final isSelected = _frequency == freq;
            return GestureDetector(
              onTap: () => setState(() => _frequency = freq),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.brandTeal
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.brandTeal
                        : Colors.white.withValues(alpha: 0.15),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  _getFrequencyLabel(freq),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getFrequencyLabel(MedicationFrequency freq) {
    switch (freq) {
      case MedicationFrequency.once:
        return 'One time';
      case MedicationFrequency.daily:
        return 'Daily';
      case MedicationFrequency.twiceDaily:
        return 'Twice daily';
      case MedicationFrequency.threeTimesDaily:
        return '3x daily';
      case MedicationFrequency.weekly:
        return 'Weekly';
      case MedicationFrequency.asNeeded:
        return 'As needed';
    }
  }

  Widget _buildTimeSelector() {
    final showSecondTime = _frequency == MedicationFrequency.twiceDaily;
    final label = showSecondTime || _frequency == MedicationFrequency.threeTimesDaily
        ? 'Dose Times'
        : 'Time';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTimePicker(
                label: showSecondTime ? 'Morning' : null,
                time: _doseTime,
                onTap: () => _selectTime(true),
              ),
            ),
            if (showSecondTime) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimePicker(
                  label: 'Evening',
                  time: _secondDoseTime ?? const TimeOfDay(hour: 20, minute: 0),
                  onTap: () => _selectTime(false),
                ),
              ),
            ],
          ],
        ),
        if (_frequency == MedicationFrequency.threeTimesDaily)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '8:00 AM, 2:00 PM, 8:00 PM',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimePicker({
    String? label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  Text(
                    time.format(context),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duration',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _hasEndDate = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: !_hasEndDate
                        ? AppTheme.brandTeal
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !_hasEndDate
                          ? AppTheme.brandTeal
                          : Colors.white.withValues(alpha: 0.15),
                      width: !_hasEndDate ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Ongoing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _hasEndDate = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _hasEndDate
                        ? AppTheme.brandTeal
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _hasEndDate
                          ? AppTheme.brandTeal
                          : Colors.white.withValues(alpha: 0.15),
                      width: _hasEndDate ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Limited time',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_hasEndDate) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Text(
                  'For',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  child: TextFormField(
                    initialValue: _durationDays.toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                    ),
                    onChanged: (value) {
                      final days = int.tryParse(value);
                      if (days != null && days > 0) {
                        setState(() => _durationDays = days);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'days',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRemindersToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.brandTeal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 20,
              color: AppTheme.brandTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminders',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Get notified when it\'s time',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _remindersEnabled,
            onChanged: (value) => setState(() => _remindersEnabled = value),
            activeThumbColor: AppTheme.brandTeal,
            activeTrackColor: AppTheme.brandTeal.withValues(alpha: 0.4),
            inactiveThumbColor: Colors.white.withValues(alpha: 0.8),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(bool isFirst) async {
    final currentTime = isFirst
        ? _doseTime
        : (_secondDoseTime ?? const TimeOfDay(hour: 20, minute: 0));

    final time = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (time != null) {
      setState(() {
        if (isFirst) {
          _doseTime = time;
        } else {
          _secondDoseTime = time;
        }
      });
    }
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pet')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<MedicationProvider>();
      final now = DateTime.now();

      // Build dose times list
      List<TimeOfDay> doseTimes = [_doseTime];
      if (_frequency == MedicationFrequency.twiceDaily) {
        doseTimes.add(_secondDoseTime ?? const TimeOfDay(hour: 20, minute: 0));
      } else if (_frequency == MedicationFrequency.threeTimesDaily) {
        doseTimes = [
          const TimeOfDay(hour: 8, minute: 0),
          const TimeOfDay(hour: 14, minute: 0),
          const TimeOfDay(hour: 20, minute: 0),
        ];
      }

      final medication = Medication(
        id: widget.existingMedication?.id ?? Medication.generateId(),
        petId: _selectedPetId!,
        ownerId: FirebaseAuth.instance.currentUser?.uid ?? '',
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        instructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        frequency: _frequency,
        doseTimes: doseTimes,
        startDate: widget.existingMedication?.startDate ?? _startDate,
        endDate: null,
        totalDays: _hasEndDate ? _durationDays : null,
        status: MedicationStatus.active,
        trackDoses: true,
        doseHistory: widget.existingMedication?.doseHistory ?? [],
        remindersEnabled: _remindersEnabled,
        createdAt: widget.existingMedication?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.existingMedication != null) {
        await provider.updateMedication(medication);
      } else {
        await provider.createMedication(medication);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingMedication != null
                  ? 'Medication updated'
                  : 'Medication added',
            ),
            backgroundColor: AppTheme.brandTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteMedication() async {
    final confirmed = await showModernConfirmDialog(
      context,
      title: 'Delete Medication',
      message: 'Are you sure you want to delete "${_nameController.text}"? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: AppTheme.error,
      icon: Icons.delete_outline,
      iconColor: AppTheme.error,
    );

    if (confirmed == true && mounted) {
      final provider = context.read<MedicationProvider>();
      await provider.deleteMedication(
        widget.existingMedication!.petId,
        widget.existingMedication!.id,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medication deleted'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

// ============ Medications Section Widget ============

/// A section widget for displaying medications list
class MedicationsSection extends StatelessWidget {
  final String petId;
  final String? petName;
  final bool showAddButton;

  const MedicationsSection({
    super.key,
    required this.petId,
    this.petName,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MedicationProvider>(
      builder: (context, provider, _) {
        final activeMeds = provider.getActiveMedicationsForPet(petId);
        final pastMeds = provider.getPastMedicationsForPet(petId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Medications',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                ),
                if (showAddButton)
                  GestureDetector(
                    onTap: () => _showAddMedicationForm(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 18.sp,
                            color: AppTheme.brandTeal,
                          ),
                          Gap(4.w),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.brandTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Gap(16.h),

            // Active medications
            if (activeMeds.isNotEmpty) ...[
              Text(
                'Active (${activeMeds.length})',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: context.secondaryTextColor,
                ),
              ),
              Gap(8.h),
              ...activeMeds.map((med) => MedicationCard(
                medication: med,
                onMarkDose: () => _markDoseTaken(context, med),
              )),
            ],

            // Empty state
            if (activeMeds.isEmpty && pastMeds.isEmpty)
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: context.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 48.sp,
                      color: context.secondaryTextColor.withValues(alpha: 0.5),
                    ),
                    Gap(12.h),
                    Text(
                      'No medications',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: context.textColor,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      'Track medications and get reminders',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

            // Past medications
            if (pastMeds.isNotEmpty) ...[
              Gap(16.h),
              GestureDetector(
                onTap: () => _showPastMedications(context, pastMeds),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 20.sp,
                        color: context.secondaryTextColor,
                      ),
                      Gap(12.w),
                      Expanded(
                        child: Text(
                          'Past medications (${pastMeds.length})',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: context.secondaryTextColor,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20.sp,
                        color: context.secondaryTextColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showAddMedicationForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => MedicationFormDialog(petId: petId),
    );
  }

  void _markDoseTaken(BuildContext context, Medication med) async {
    final provider = context.read<MedicationProvider>();
    await provider.logDoseTaken(med.petId, med.id, DateTime.now());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dose marked as taken'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _showPastMedications(BuildContext context, List<Medication> meds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, controller) => Container(
          decoration: BoxDecoration(
            color: context.surfacePrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  'Past Medications',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: meds.length,
                  itemBuilder: (context, index) => MedicationCard(
                    medication: meds[index],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
