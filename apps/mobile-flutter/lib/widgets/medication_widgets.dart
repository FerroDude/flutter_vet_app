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

  const MedicationCard({
    super.key,
    required this.medication,
    this.petName,
    this.showPetName = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = medication.isActive;
    final progress = medication.progress;

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
                      color: isActive
                          ? AppTheme.brandTeal
                          : Colors.white.withValues(alpha: 0.6),
                      size: 24.sp,
                    ),
                  ),
                  Gap(12.w),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Name + Pet badge (if shown) + Status badge (if inactive)
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
                            if (!isActive) ...[
                              Gap(8.w),
                              _buildStatusBadge(medication.status),
                            ],
                            if (showPetName && petName != null) ...[
                              Gap(8.w),
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
                        Gap(6.h),
                        // Row 2: Dosage • Frequency
                        Text(
                          '${medication.dosage} • ${medication.frequencyDisplay}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        // Row 3: Today's dose status (for active medications)
                        if (isActive) ...[Gap(8.h), _buildTodayStatus()],
                        // Row 4: Progress bar with percentage (for time-limited medications)
                        if (isActive && progress != null) ...[
                          Gap(8.h),
                          _buildSimpleProgressBar(progress),
                        ],
                      ],
                    ),
                  ),
                  // Chevron to indicate tappable
                  Gap(8.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20.sp,
                  ),
                ],
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

  Widget _buildTodayStatus() {
    final isAsNeeded = medication.frequency == MedicationFrequency.asNeeded;
    final isOnce = medication.frequency == MedicationFrequency.once;

    // Handle medications that haven't started yet
    if (!medication.hasStarted) {
      final daysUntil = medication.daysUntilStart;
      return Row(
        children: [
          Icon(Icons.schedule_rounded, size: 14.sp, color: AppTheme.warning),
          Gap(4.w),
          Text(
            daysUntil == 1 ? 'Starts tomorrow' : 'Starts in $daysUntil days',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.warning,
            ),
          ),
        ],
      );
    }

    // Handle medications that have ended
    if (medication.hasEnded) {
      // Check if ended incomplete
      if (medication.endedIncomplete) {
        final missed = medication.missedDoses;
        return Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 14.sp,
              color: AppTheme.warning,
            ),
            Gap(4.w),
            Text(
              'Ended • $missed dose${missed == 1 ? '' : 's'} missed',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.warning,
              ),
            ),
          ],
        );
      }
      return Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 14.sp,
            color: AppTheme.success,
          ),
          Gap(4.w),
          Text(
            'Course completed',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.success,
            ),
          ),
        ],
      );
    }

    if (isOnce) {
      // One-time medication
      final isTaken = medication.totalDosesTaken >= 1;
      return Row(
        children: [
          Icon(
            isTaken ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 14.sp,
            color: isTaken
                ? AppTheme.success
                : Colors.white.withValues(alpha: 0.5),
          ),
          Gap(4.w),
          Text(
            isTaken ? 'Completed' : 'Not yet taken',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: isTaken
                  ? AppTheme.success
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    }

    if (isAsNeeded) {
      // As-needed medication
      final takenToday = medication.dosesTakenToday;
      return Row(
        children: [
          Icon(
            Icons.today_rounded,
            size: 14.sp,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          Gap(4.w),
          Text(
            takenToday > 0
                ? '$takenToday dose${takenToday == 1 ? '' : 's'} today'
                : 'Take as needed',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    }

    // Check if behind schedule (missed doses from previous days)
    if (medication.isBehindSchedule) {
      final missed = medication.missedDoses;
      final remaining = medication.dosesRemainingToday;
      return Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 14.sp,
            color: AppTheme.warning,
          ),
          Gap(4.w),
          Text(
            '$missed missed',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.warning,
            ),
          ),
          if (remaining > 0) ...[
            Text(
              ' • $remaining due today',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ] else ...[
            Text(
              ' • done today',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      );
    }

    // Scheduled medication - show dose bubbles
    final expected = medication.dosesExpectedToday;
    final taken = medication.dosesTakenToday;
    final allTaken = taken >= expected && expected > 0;

    // Handle weekly medications with no dose today
    if (expected == 0) {
      return Row(
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 14.sp,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          Gap(4.w),
          Text(
            'No dose today',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          if (medication.nextDoseDescription != null) ...[
            Text(
              ' • ${medication.nextDoseDescription}',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 4.w,
      runSpacing: 4.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Dose bubbles in a row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(expected, (index) {
            final isTaken = index < taken;
            return Padding(
              padding: EdgeInsets.only(right: 3.w),
              child: Icon(
                isTaken
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                size: 14.sp,
                color: isTaken
                    ? AppTheme.success
                    : Colors.white.withValues(alpha: 0.35),
              ),
            );
          }),
        ),
        Text(
          allTaken ? 'Done!' : '${expected - taken} left',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: allTaken ? FontWeight.w600 : FontWeight.w400,
            color: allTaken
                ? AppTheme.success
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
        // Show next dose info if applicable
        if (medication.nextDoseDescription != null && !allTaken)
          Text(
            '• ${medication.nextDoseDescription}',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }

  Widget _buildSimpleProgressBar(double progress) {
    final percentage = (progress * 100).round();
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 6.h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.brandTeal,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        Gap(8.w),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  void _showMedicationDetail(BuildContext context) {
    // Get the provider before showing the bottom sheet
    final medicationProvider = context.read<MedicationProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ChangeNotifierProvider.value(
        value: medicationProvider,
        child: MedicationDetailSheet(medication: medication),
      ),
    );
  }
}

// ============ Medication Detail Sheet ============

/// Bottom sheet showing full medication details
/// Uses Consumer to watch for medication updates from the provider
class MedicationDetailSheet extends StatelessWidget {
  final Medication medication;

  const MedicationDetailSheet({super.key, required this.medication});

  @override
  Widget build(BuildContext context) {
    // Watch the MedicationProvider for real-time updates
    return Consumer<MedicationProvider>(
      builder: (context, provider, _) {
        // Get the latest medication data from the provider
        final liveMedication = provider.getMedicationById(
          medication.petId,
          medication.id,
        ) ?? medication;
        
        return _MedicationDetailContent(medication: liveMedication);
      },
    );
  }
}

/// Internal widget that displays the medication details
class _MedicationDetailContent extends StatelessWidget {
  final Medication medication;

  const _MedicationDetailContent({required this.medication});

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
                    Gap(16.h),
                    // Schedule info - compact text
                    _buildScheduleInfo(),

                    Gap(16.h),

                    // 1. Today's status tile (first banner)
                    _buildTodayStatusTile(),

                    // 2. Dose history section (for medications with dose tracking)
                    if (medication.doseHistory.isNotEmpty)
                      _buildDoseHistorySection(),

                    // 3. Instructions tile
                    if (medication.instructions != null &&
                        medication.instructions!.isNotEmpty)
                      _buildInfoTile(
                        context,
                        icon: Icons.notes_rounded,
                        label: 'Instructions',
                        value: medication.instructions!,
                      ),

                    // 4. Progress section (if time-limited)
                    if (medication.totalDays != null) ...[
                      Gap(4.h),
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

  Widget _buildScheduleInfo() {
    final startDateStr = DateFormat('MMM d, yyyy').format(medication.startDate);
    final endDate = medication.calculatedEndDate;
    final endDateStr = endDate != null
        ? DateFormat('MMM d, yyyy').format(endDate)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dates line
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14.sp,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            Gap(6.w),
            Text(
              endDateStr != null
                  ? '$startDateStr  →  $endDateStr'
                  : 'Started $startDateStr',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        Gap(6.h),
        // Frequency line
        Row(
          children: [
            Icon(
              Icons.repeat_rounded,
              size: 14.sp,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            Gap(6.w),
            Text(
              medication.frequencyDisplay,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayStatusTile() {
    final isAsNeeded = medication.frequency == MedicationFrequency.asNeeded;
    final isOnce = medication.frequency == MedicationFrequency.once;

    String statusText;
    String? subtitleText;
    IconData statusIcon;
    Color statusColor;
    Widget? trailingWidget;

    // Handle ended incomplete medications
    if (medication.hasEnded && medication.endedIncomplete) {
      final missed = medication.missedDoses;
      statusText = 'Course ended incomplete';
      subtitleText = '$missed dose${missed == 1 ? '' : 's'} missed';
      statusIcon = Icons.warning_amber_rounded;
      statusColor = AppTheme.warning;
    }
    // Handle medications that haven't started
    else if (!medication.hasStarted) {
      final days = medication.daysUntilStart;
      statusText = days == 1 ? 'Starts tomorrow' : 'Starts in $days days';
      statusIcon = Icons.schedule_rounded;
      statusColor = AppTheme.warning;
    }
    // Handle completed medications
    else if (medication.hasEnded) {
      statusText = 'Course completed successfully';
      statusIcon = Icons.check_circle_rounded;
      statusColor = AppTheme.success;
    } else if (isOnce) {
      final isTaken = medication.totalDosesTaken >= 1;
      statusText = isTaken ? 'Medication taken' : 'Not yet taken';
      statusIcon = isTaken
          ? Icons.check_circle_rounded
          : Icons.radio_button_unchecked;
      statusColor = isTaken
          ? AppTheme.success
          : Colors.white.withValues(alpha: 0.6);
    } else if (isAsNeeded) {
      final takenToday = medication.dosesTakenToday;
      statusText = takenToday > 0
          ? '$takenToday dose${takenToday == 1 ? '' : 's'} taken today'
          : 'No doses taken today';
      statusIcon = Icons.today_rounded;
      statusColor = takenToday > 0
          ? AppTheme.brandTeal
          : Colors.white.withValues(alpha: 0.6);
    } else {
      final expected = medication.dosesExpectedToday;
      final taken = medication.dosesTakenToday;
      final allTaken = taken >= expected && expected > 0;

      // Just show today's status (missed doses warning is in Progress section)
      statusText = allTaken
          ? 'All doses taken today'
          : '$taken of $expected taken today';
      statusIcon = allTaken
          ? Icons.check_circle_rounded
          : Icons.pending_rounded;
      statusColor = allTaken ? AppTheme.success : AppTheme.brandTeal;

      // Show dose bubbles
      if (expected > 0) {
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(expected, (index) {
            final isTaken = index < taken;
            return Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: Icon(
                isTaken
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                size: 18.sp,
                color: isTaken
                    ? AppTheme.success
                    : Colors.white.withValues(alpha: 0.3),
              ),
            );
          }),
        );
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, size: 18.sp, color: statusColor),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.hasEnded ? 'Status' : 'Today',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Gap(2.h),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
                if (subtitleText != null) ...[
                  Gap(2.h),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailingWidget != null) trailingWidget,
        ],
      ),
    );
  }

  Widget _buildDoseHistorySection() {
    return _DoseHistoryDropdown(medication: medication);
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
    final isAsNeeded = medication.frequency == MedicationFrequency.asNeeded;
    final dosesTaken = medication.totalDosesTaken;
    final totalExpected = medication.totalExpectedDoses;
    final adherence = medication.adherenceRate;
    final missed = medication.missedDoses;
    final isBehind = medication.isBehindSchedule;

    // Determine color based on adherence/progress
    final Color progressColor;
    if (medication.hasEnded && medication.endedIncomplete) {
      progressColor = AppTheme.warning;
    } else if (isBehind && adherence != null && adherence < 0.7) {
      progressColor = AppTheme.warning;
    } else {
      progressColor = AppTheme.brandTeal;
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: progressColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: progressColor.withValues(alpha: 0.3)),
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
                  color: progressColor,
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
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8.h,
            ),
          ),
          Gap(12.h),
          // Main progress text - dose-based
          if (!isAsNeeded && totalExpected != null) ...[
            Text(
              '$dosesTaken of $totalExpected doses taken',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
          if (isAsNeeded) ...[
            Text(
              dosesTaken > 0
                  ? '$dosesTaken dose${dosesTaken == 1 ? '' : 's'} logged'
                  : 'No doses logged yet',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
          // Show missed doses warning if applicable
          if (missed > 0 && !isAsNeeded) ...[
            Gap(6.h),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14.sp,
                  color: AppTheme.warning,
                ),
                Gap(4.w),
                Text(
                  '$missed dose${missed == 1 ? '' : 's'} missed',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.warning,
                  ),
                ),
                if (adherence != null) ...[
                  Text(
                    ' • ${(adherence * 100).round()}% adherence',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ],
          // Next dose info - secondary
          if (medication.nextDoseDescription != null) ...[
            Gap(4.h),
            Text(
              medication.nextDoseDescription!,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ] else if (medication.hasEnded) ...[
            Gap(4.h),
            Text(
              medication.endedIncomplete ? 'Course ended' : 'Course complete',
              style: TextStyle(
                fontSize: 12.sp,
                color: medication.endedIncomplete
                    ? AppTheme.warning
                    : AppTheme.success,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final isAsNeeded = medication.frequency == MedicationFrequency.asNeeded;
    final hasDosesToUndo = medication.totalDosesTaken > 0;

    // Determine if marking a dose is possible
    final hasNotStarted = !medication.hasStarted;
    final hasEnded = medication.hasEnded;
    final allDosesToday = medication.allDosesTakenToday;
    final canMarkDose = !hasNotStarted && !hasEnded && !allDosesToday;

    return Column(
      children: [
        // Mark dose taken - primary action (or status if not available)
        SizedBox(
          width: double.infinity,
          child: canMarkDose
              ? ElevatedButton.icon(
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
                    isAsNeeded ? 'Log Dose Taken' : 'Mark Dose Taken',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : _buildStatusContainer(hasNotStarted, hasEnded),
        ),
        // Quick actions row - Undo and Log past dose
        if (medication.hasStarted) ...[
          Gap(8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Undo last dose (only if there are doses to undo)
              if (hasDosesToUndo && !hasEnded) ...[
                GestureDetector(
                  onTap: () => _undoLastDose(context),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 6.h,
                      horizontal: 8.w,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.undo_rounded,
                          size: 14.sp,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        Gap(4.w),
                        Text(
                          'Undo last',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  '•',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
              // Log past dose option
              GestureDetector(
                onTap: () => _showLogPastDoseDialog(context),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 8.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 14.sp,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      Gap(4.w),
                      Text(
                        'Log past dose',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
        Gap(16.h),
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
        // Extend option for time-limited active medications
        if (medication.totalDays != null && medication.canBeExtended) ...[
          Gap(12.h),
          _buildGlassyButton(
            onPressed: () => _showExtendDialog(context),
            icon: Icons.add_circle_outline_rounded,
            label: 'Extend Course',
            color: AppTheme.brandTeal,
            isFullWidth: true,
          ),
        ],
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

  Widget _buildStatusContainer(bool hasNotStarted, bool hasEnded) {
    IconData icon;
    String message;
    Color color;

    if (hasNotStarted) {
      icon = Icons.schedule_rounded;
      final days = medication.daysUntilStart;
      message = days == 1 ? 'Starts tomorrow' : 'Starts in $days days';
      color = AppTheme.warning;
    } else if (hasEnded) {
      icon = Icons.check_circle_rounded;
      message = 'Course completed';
      color = AppTheme.success;
    } else if (medication.frequency == MedicationFrequency.once &&
        medication.totalDosesTaken >= 1) {
      icon = Icons.check_circle_rounded;
      message = 'Medication Completed';
      color = AppTheme.success;
    } else if (medication.dosesExpectedToday == 0) {
      // Weekly medication with no dose today
      icon = Icons.event_busy_rounded;
      message = 'No dose scheduled today';
      color = Colors.white.withValues(alpha: 0.6);
    } else {
      icon = Icons.check_circle_rounded;
      message = 'All doses taken today';
      color = AppTheme.success;
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22.sp),
          Gap(8.w),
          Text(
            message,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
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
              border: Border.all(color: color.withValues(alpha: 0.3)),
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
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
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

    // For completed or discontinued medications - offer extend/restart options
    return Column(
      children: [
        // Primary action: Extend (if applicable)
        if (medication.canBeExtended) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showExtendDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandTeal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: Text(
                'Extend Medication',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Gap(12.h),
        ],
        // Log past dose option for ended medications with missed doses
        if (medication.endedIncomplete) ...[
          _buildGlassyButton(
            onPressed: () => _showLogPastDoseDialog(context),
            icon: Icons.history_rounded,
            label: 'Log Missed Dose',
            color: AppTheme.brandTeal,
            isFullWidth: true,
          ),
          Gap(12.h),
        ],
        // Secondary: Restart (different from extend - keeps history but restarts tracking)
        _buildGlassyButton(
          onPressed: () => _restartMedication(context),
          icon: Icons.refresh_rounded,
          label: medication.canBeExtended
              ? 'Restart Fresh'
              : 'Restart Medication',
          color: Colors.white,
          isFullWidth: true,
        ),
        Gap(12.h),
        _buildGlassyButton(
          onPressed: () => _deleteMedication(context),
          icon: Icons.delete_outline,
          label: 'Delete Medication',
          color: AppTheme.error,
          isFullWidth: true,
        ),
      ],
    );
  }

  void _markDoseTaken(BuildContext context) async {
    try {
      final provider = context.read<MedicationProvider>();
      final success = await provider.logDoseTaken(
        medication.petId,
        medication.id,
        DateTime.now(),
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Dose marked as taken' : 'Failed to mark dose',
            ),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showLogPastDoseDialog(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Get provider for fresh medication data
    final provider = context.read<MedicationProvider>();
    
    // Helper to get fresh medication data from provider
    Medication getFreshMedication() {
      return provider.getMedicationById(medication.petId, medication.id) ?? medication;
    }
    
    // Calculate valid date range (from start date to today or end date)
    final freshMed = getFreshMedication();
    final startDay = DateTime(
      freshMed.startDate.year,
      freshMed.startDate.month,
      freshMed.startDate.day,
    );
    final endDate = freshMed.calculatedEndDate;
    final lastValidDay =
        endDate != null &&
            DateTime(endDate.year, endDate.month, endDate.day).isBefore(today)
        ? DateTime(endDate.year, endDate.month, endDate.day)
        : today;

    // If medication started today or later, can't log past doses
    if (!startDay.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Medication started today - use "Mark Dose Taken" instead',
          ),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    
    DateTime selectedDate = now.subtract(const Duration(days: 1)); // Default to yesterday
    TimeOfDay selectedTime = freshMed.doseTimes.isNotEmpty
        ? freshMed.doseTimes.first
        : const TimeOfDay(hour: 8, minute: 0);
    
    // Helper to check if a date already has all doses taken (uses fresh data)
    bool isDateComplete(DateTime date) {
      final currentMed = getFreshMedication();
      final expected = currentMed.dosesExpectedOnDate(date);
      final taken = currentMed.dosesTakenOnDate(date);
      return expected > 0 && taken >= expected;
    }

    // Ensure default date is within valid range
    if (selectedDate.isBefore(startDay)) {
      selectedDate = startDay;
    }
    if (selectedDate.isAfter(lastValidDay)) {
      selectedDate = lastValidDay;
    }
    
    // Find a valid default date (one that doesn't have all doses taken)
    // But never go before startDay
    while (isDateComplete(selectedDate) && selectedDate.isAfter(startDay)) {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    }
    
    // Final safety check - ensure selectedDate is within valid range
    if (selectedDate.isBefore(startDay)) {
      selectedDate = startDay;
    }
    if (selectedDate.isAfter(lastValidDay)) {
      selectedDate = lastValidDay;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          String formatSelectedDate() {
            final diff = today
                .difference(
                  DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                  ),
                )
                .inDays;
            if (diff == 0) return 'Today';
            if (diff == 1) return 'Yesterday';
            return DateFormat('EEE, MMM d').format(selectedDate);
          }

          // Check if selected date already has all doses taken (uses fresh data)
          final selectedDateComplete = isDateComplete(selectedDate);
          
          return AlertDialog(
            backgroundColor: AppTheme.neutral600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Log Past Dose',
              style: TextStyle(color: Colors.white, fontSize: 18.sp),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When did you give this dose?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14.sp,
                  ),
                ),
                Gap(16.h),
                // Date selector
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: startDay,
                      lastDate: lastValidDay,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppTheme.brandTeal,
                              onPrimary: Colors.white,
                              surface: AppTheme.neutral600,
                              onSurface: Colors.white,
                            ),
                            dialogBackgroundColor: AppTheme.neutral600,
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.brandTeal,
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 14.h,
                    ),
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
                          size: 20.sp,
                          color: AppTheme.brandTeal,
                        ),
                        Gap(12.w),
                        Expanded(
                          child: Text(
                            formatSelectedDate(),
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20.sp,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                Gap(12.h),
                // Time selector
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: dialogContext,
                      initialTime: selectedTime,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppTheme.brandTeal,
                              onPrimary: Colors.white,
                              surface: AppTheme.neutral600,
                              onSurface: Colors.white,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.brandTeal,
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() => selectedTime = picked);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 14.h,
                    ),
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
                          size: 20.sp,
                          color: AppTheme.brandTeal,
                        ),
                        Gap(12.w),
                        Expanded(
                          child: Text(
                            selectedTime.format(dialogContext),
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20.sp,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                Gap(16.h),
                // Info message - changes based on whether date is complete
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: selectedDateComplete 
                        ? AppTheme.warning.withValues(alpha: 0.15)
                        : AppTheme.brandTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedDateComplete 
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline,
                        size: 16.sp,
                        color: selectedDateComplete 
                            ? AppTheme.warning
                            : AppTheme.brandTeal,
                      ),
                      Gap(8.w),
                      Expanded(
                        child: Text(
                          selectedDateComplete
                              ? 'All doses for this day have already been logged'
                              : 'This will add a dose record for the selected date and time',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: selectedDateComplete
                                ? AppTheme.warning
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
              ElevatedButton(
                onPressed: selectedDateComplete
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        _logPastDose(context, selectedDate, selectedTime);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandTeal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.neutral500,
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                ),
                child: const Text('Log Dose'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _logPastDose(BuildContext context, DateTime date, TimeOfDay time) async {
    // Combine date and time
    final doseDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    try {
      final provider = context.read<MedicationProvider>();
      final success = await provider.logDoseTaken(
        medication.petId,
        medication.id,
        doseDateTime,
      );
      if (context.mounted) {
        // Don't close the sheet - it will update automatically via Consumer
        // Just show a snackbar

        // Format the date for the message
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final doseDay = DateTime(date.year, date.month, date.day);
        final diff = today.difference(doseDay).inDays;

        String dateStr;
        if (diff == 0) {
          dateStr = 'today';
        } else if (diff == 1) {
          dateStr = 'yesterday';
        } else {
          dateStr = DateFormat('MMM d').format(date);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Dose logged for $dateStr' : 'Failed to log dose',
            ),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _undoLastDose(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.neutral600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Undo Last Dose?',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Text(
          'This will remove the most recently recorded dose. Are you sure?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Undo', style: TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final provider = context.read<MedicationProvider>();
      final success = await provider.undoLastDose(
        medication.petId,
        medication.id,
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Last dose removed' : 'No doses to undo'),
            backgroundColor: success ? AppTheme.brandTeal : AppTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _restartMedication(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.neutral600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Restart Medication?',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Text(
          'This will set the medication back to active status. Continue?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Restart', style: TextStyle(color: AppTheme.brandTeal)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final provider = context.read<MedicationProvider>();
      // Reuse resumeMedication as it sets status back to active
      final success = await provider.resumeMedication(
        medication.petId,
        medication.id,
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Medication restarted' : 'Failed to restart',
            ),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showExtendDialog(BuildContext context) {
    final isWeekly = medication.frequency == MedicationFrequency.weekly;
    int selectedAmount = 1; // Default to 1 (day or week)

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // For weekly medications, convert to days (1 week = 7 days)
          final daysToAdd = isWeekly ? selectedAmount * 7 : selectedAmount;
          final unitLabel = isWeekly ? 'week' : 'day';
          final unitLabelPlural = isWeekly ? 'weeks' : 'days';

          return AlertDialog(
            backgroundColor: AppTheme.neutral600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Extend Medication',
              style: TextStyle(color: Colors.white, fontSize: 18.sp),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.hasEnded
                      ? 'Continue "${medication.name}" for how much longer?'
                      : 'Extend the course by:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14.sp,
                  ),
                ),
                Gap(16.h),
                // Selection chips for 1, 2, 3
                Row(
                  children: [1, 2, 3].map((amount) {
                    final isSelected = selectedAmount == amount;
                    final label =
                        '$amount ${amount == 1 ? unitLabel : unitLabelPlural}';
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedAmount = amount),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.brandTeal
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.brandTeal
                                    : Colors.white.withValues(alpha: 0.2),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                Gap(16.h),
                // Info about what will happen
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppTheme.brandTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16.sp,
                        color: AppTheme.brandTeal,
                      ),
                      Gap(8.w),
                      Expanded(
                        child: Text(
                          medication.hasEnded
                              ? 'Medication will resume from today for $selectedAmount more ${selectedAmount == 1 ? unitLabel : unitLabelPlural}'
                              : 'Course will be extended by $selectedAmount ${selectedAmount == 1 ? unitLabel : unitLabelPlural}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _extendMedication(context, daysToAdd);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandTeal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Extend'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _extendMedication(BuildContext context, int days) async {
    try {
      final provider = context.read<MedicationProvider>();
      final success = await provider.extendMedication(
        medication.petId,
        medication.id,
        days,
      );
      if (context.mounted) {
        Navigator.pop(context); // Close detail sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Medication extended by $days days'
                  : 'Failed to extend',
            ),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showEditForm(BuildContext context) {
    Navigator.pop(context);
    showMedicationForm(
      context,
      petId: medication.petId,
      existingMedication: medication,
    );
  }

  void _pauseMedication(BuildContext context) async {
    try {
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _resumeMedication(BuildContext context) async {
    try {
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _stopMedication(BuildContext context) async {
    final confirmed = await showModernConfirmDialog(
      context,
      title: 'Stop Medication',
      message:
          'This will mark "${medication.name}" as discontinued. You can delete it later if needed.',
      confirmText: 'Stop',
      confirmColor: AppTheme.error,
      icon: Icons.stop_circle_outlined,
      iconColor: AppTheme.error,
    );

    if (confirmed == true && context.mounted) {
      try {
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
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  void _deleteMedication(BuildContext context) async {
    final confirmed = await showModernConfirmDialog(
      context,
      title: 'Delete Medication',
      message:
          'This will permanently delete "${medication.name}". This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: AppTheme.error,
      icon: Icons.delete_outline,
      iconColor: AppTheme.error,
    );

    if (confirmed == true && context.mounted) {
      try {
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
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }
}

// ============ Dose History Dropdown ============

/// Collapsible dose history section
class _DoseHistoryDropdown extends StatefulWidget {
  final Medication medication;

  const _DoseHistoryDropdown({required this.medication});

  @override
  State<_DoseHistoryDropdown> createState() => _DoseHistoryDropdownState();
}

class _DoseHistoryDropdownState extends State<_DoseHistoryDropdown>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Group doses by day
    final dosesGroupedByDay = <DateTime, List<DoseLog>>{};
    for (final dose in widget.medication.doseHistory) {
      if (dose.takenAt != null) {
        final day = DateTime(
          dose.takenAt!.year,
          dose.takenAt!.month,
          dose.takenAt!.day,
        );
        dosesGroupedByDay.putIfAbsent(day, () => []).add(dose);
      }
    }

    // Sort days in descending order (most recent first)
    final sortedDays = dosesGroupedByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Show all days (no limit)
    final displayDays = sortedDays;

    if (displayDays.isEmpty) return const SizedBox.shrink();

    // Count total doses being displayed (should match totalDosesTaken)
    final displayedDoseCount = displayDays.fold<int>(
      0,
      (sum, day) => sum + dosesGroupedByDay[day]!.length,
    );

    // Use the displayed count to ensure consistency
    final totalCount = displayedDoseCount;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String formatDay(DateTime day) {
      if (day == today) return 'Today';
      if (day == yesterday) return 'Yesterday';
      return DateFormat('EEE, MMM d').format(day);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - tappable to expand/collapse
          GestureDetector(
            onTap: _toggleExpanded,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: AppTheme.brandTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: 18.sp,
                      color: AppTheme.brandTeal,
                    ),
                  ),
                  Gap(12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dose History',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        Gap(2.h),
                        Text(
                          '$totalCount dose${totalCount == 1 ? '' : 's'} total',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand/collapse icon
                  RotationTransition(
                    turns: Tween(
                      begin: 0.0,
                      end: 0.5,
                    ).animate(_expandAnimation),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24.sp,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: EdgeInsets.only(left: 12.w, right: 12.w, bottom: 12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                    height: 1,
                  ),
                  Gap(12.h),
                  // Day-by-day breakdown
                  ...displayDays.map((day) {
                    final doses = dosesGroupedByDay[day]!;
                    final doseCount = doses.length;

                    // Sort doses by time within the day
                    doses.sort((a, b) => a.takenAt!.compareTo(b.takenAt!));

                    // Format times for this day
                    final times = doses
                        .map((d) => DateFormat('h:mm a').format(d.takenAt!))
                        .join(', ');

                    return Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Row(
                        children: [
                          // Day indicator
                          Container(
                            width: 28.w,
                            height: 28.w,
                            decoration: BoxDecoration(
                              color: day == today
                                  ? AppTheme.brandTeal.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$doseCount',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: day == today
                                      ? AppTheme.brandTeal
                                      : Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                          Gap(10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatDay(day),
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                    color: day == today
                                        ? AppTheme.brandTeal
                                        : Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                Text(
                                  times,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ Medication Form Sheet ============

/// Shows the medication form as a bottom sheet
void showMedicationForm(
  BuildContext context, {
  String? petId,
  Medication? existingMedication,
}) {
  final medicationProvider = context.read<MedicationProvider>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => ChangeNotifierProvider.value(
      value: medicationProvider,
      child: MedicationFormSheet(
        petId: petId,
        existingMedication: existingMedication,
      ),
    ),
  );
}

/// Bottom sheet for adding or editing a medication
class MedicationFormSheet extends StatefulWidget {
  final String? petId;
  final Medication? existingMedication;

  const MedicationFormSheet({super.key, this.petId, this.existingMedication});

  @override
  State<MedicationFormSheet> createState() => _MedicationFormSheetState();
}

/// Dialog version for backwards compatibility (wraps the sheet)
class MedicationFormDialog extends StatelessWidget {
  final String? petId;
  final Medication? existingMedication;

  const MedicationFormDialog({super.key, this.petId, this.existingMedication});

  @override
  Widget build(BuildContext context) {
    // Close the dialog and show as bottom sheet instead
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pop();
      showMedicationForm(
        context,
        petId: petId,
        existingMedication: existingMedication,
      );
    });
    return const SizedBox.shrink();
  }
}

class _MedicationFormSheetState extends State<MedicationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _instructionsController;

  String? _selectedPetId;
  MedicationFrequency _frequency = MedicationFrequency.daily;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7)); // Default 7 days
  TimeOfDay _doseTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? _secondDoseTime;
  bool _hasEndDate = true;
  bool _remindersEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingMedication;

    _nameController = TextEditingController(text: existing?.name ?? '');
    _dosageController = TextEditingController(text: existing?.dosage ?? '');
    _instructionsController = TextEditingController(
      text: existing?.instructions ?? '',
    );
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
      if (existing.totalDays != null) {
        _endDate = _startDate.add(Duration(days: existing.totalDays! - 1));
      } else {
        _endDate = _startDate.add(const Duration(days: 7));
      }
      _remindersEnabled = existing.remindersEnabled;
    } else {
      _endDate = _startDate.add(const Duration(days: 7));
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

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Row(
                  children: [
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        color: AppTheme.brandTeal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.brandTeal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.medication_rounded,
                        color: AppTheme.brandTeal,
                        size: 24.sp,
                      ),
                    ),
                    Gap(16.w),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Medication' : 'Add Medication',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Gap(16.h),
              // Form content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    children: [
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
                      Gap(16.h),

                      // Pet selector (if not pre-selected)
                      if (_selectedPetId == null) ...[
                        _buildPetSelector(),
                        Gap(16.h),
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
                      Gap(16.h),

                      // Frequency
                      _buildFrequencySelector(),
                      Gap(16.h),

                      // Dose time(s)
                      _buildTimeSelector(),
                      Gap(16.h),

                      // Start date
                      _buildStartDateSelector(),
                      Gap(16.h),

                      // Duration (hide for one-time medications)
                      if (_frequency != MedicationFrequency.once) ...[
                        _buildDurationSelector(),
                        Gap(16.h),
                      ],

                      // Instructions
                      _buildTextField(
                        controller: _instructionsController,
                        label: 'Instructions (Optional)',
                        hint: 'e.g., Take with food, avoid dairy',
                        icon: Icons.notes_rounded,
                        maxLines: 2,
                      ),
                      Gap(16.h),

                      // Reminders toggle
                      _buildRemindersToggle(),
                      Gap(24.h),

                      // Actions
                      Row(
                        children: [
                          if (isEditing) ...[
                            Expanded(
                              child: _buildActionButton(
                                onPressed: _deleteMedication,
                                label: 'Delete',
                                icon: Icons.delete_outline,
                                color: AppTheme.error,
                                isPrimary: false,
                              ),
                            ),
                            Gap(12.w),
                          ],
                          Expanded(
                            flex: isEditing ? 2 : 1,
                            child: _buildActionButton(
                              onPressed: _saveMedication,
                              label: isEditing ? 'Update' : 'Add Medication',
                              icon: isEditing ? Icons.check : Icons.add,
                              color: AppTheme.brandTeal,
                              isPrimary: true,
                              isLoading: _isLoading,
                            ),
                          ),
                        ],
                      ),
                      // Bottom padding for safe area
                      Gap(MediaQuery.of(context).padding.bottom + 16.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    required Color color,
    required bool isPrimary,
    bool isLoading = false,
  }) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        icon: isLoading
            ? SizedBox(
                width: 18.sp,
                height: 18.sp,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20.sp),
        label: Text(
          label,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 20.sp),
      label: Text(
        label,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
    final label =
        showSecondTime || _frequency == MedicationFrequency.threeTimesDaily
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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

  Widget _buildStartDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start Date',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: AppTheme.brandTeal,
                      onPrimary: Colors.white,
                      surface: AppTheme.neutral600,
                      onSurface: Colors.white,
                      secondary: AppTheme.brandTeal,
                      onSecondary: Colors.white,
                    ),
                    dialogBackgroundColor: AppTheme.neutral600,
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.brandTeal,
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                // Maintain the same duration when changing start date
                final currentDuration = _endDate.difference(_startDate).inDays;
                _startDate = picked;
                _endDate = picked.add(Duration(days: currentDuration));
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: AppTheme.brandTeal,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatDate(_startDate),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Calculate duration in days between start and end date (inclusive)
  int get _durationDays {
    return _endDate.difference(_startDate).inDays + 1;
  }

  /// Format duration as human-readable string
  String get _durationDescription {
    final days = _durationDays;
    if (days == 1) return '1 day';
    if (days < 7) return '$days days';
    if (days == 7) return '1 week';
    if (days % 7 == 0) return '${days ~/ 7} weeks';
    final weeks = days ~/ 7;
    final remainingDays = days % 7;
    if (weeks == 1) {
      return '1 week, $remainingDays day${remainingDays == 1 ? '' : 's'}';
    }
    return '$weeks weeks, $remainingDays day${remainingDays == 1 ? '' : 's'}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, MMM d, yyyy').format(date);
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
            // Limited time (now on the left)
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
            const SizedBox(width: 12),
            // Ongoing (now on the right)
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
          ],
        ),
        if (_hasEndDate) ...[
          const SizedBox(height: 12),
          // End date picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate,
                firstDate: _startDate, // Can't end before start
                lastDate: _startDate.add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: AppTheme.brandTeal,
                        onPrimary: Colors.white,
                        surface: AppTheme.neutral600,
                        onSurface: Colors.white,
                        secondary: AppTheme.brandTeal,
                        onSecondary: Colors.white,
                      ),
                      dialogBackgroundColor: AppTheme.neutral600,
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.brandTeal,
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _endDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 20,
                    color: AppTheme.brandTeal,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(_endDate),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Duration info display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.brandTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.brandTeal.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: AppTheme.brandTeal,
                ),
                const SizedBox(width: 8),
                Text(
                  'Duration: $_durationDescription',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.brandTeal,
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a pet')));
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
        startDate: _startDate,
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
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
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
      message:
          'Are you sure you want to delete "${_nameController.text}"? This action cannot be undone.',
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
              ...activeMeds.map((med) => MedicationCard(medication: med)),
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
    showMedicationForm(context, petId: petId);
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
                  itemBuilder: (context, index) =>
                      MedicationCard(medication: meds[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
