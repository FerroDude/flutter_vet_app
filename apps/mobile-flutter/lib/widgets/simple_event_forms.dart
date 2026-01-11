import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import '../theme/app_theme.dart';

class SimpleAddEventDialog extends StatelessWidget {
  final DateTime selectedDate;
  final String? petId;
  final VoidCallback? onShowAppointment;
  final VoidCallback? onShowMedication;
  final VoidCallback? onShowSymptom;

  const SimpleAddEventDialog({
    super.key,
    required this.selectedDate,
    this.petId,
    this.onShowAppointment,
    this.onShowMedication,
    this.onShowSymptom,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacing5),
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
          borderRadius: BorderRadius.circular(AppTheme.radius4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add New Event',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(AppTheme.spacing5),
            _buildEventOption(
              context: context,
              icon: Icons.event,
              title: 'Appointment',
              onTap: () {
                Navigator.pop(context);
                onShowAppointment?.call();
              },
            ),
            Gap(AppTheme.spacing3),
            _buildEventOption(
              context: context,
              icon: Icons.medication,
              title: 'Medication',
              onTap: () {
                Navigator.pop(context);
                onShowMedication?.call();
              },
            ),
            Gap(AppTheme.spacing3),
            _buildEventOption(
              context: context,
              icon: Icons.healing,
              title: 'Symptom',
              onTap: () {
                Navigator.pop(context);
                onShowSymptom?.call();
              },
            ),
            Gap(AppTheme.spacing4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacing4,
            vertical: AppTheme.spacing3,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius3),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              Gap(AppTheme.spacing3),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.primary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// APPOINTMENT FORM
// ============================================================================

class SimpleAppointmentForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final AppointmentEvent? existingEvent;
  final String? clinicName;

  const SimpleAppointmentForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
    this.clinicName,
  });

  @override
  State<SimpleAppointmentForm> createState() => _SimpleAppointmentFormState();
}

class _SimpleAppointmentFormState extends State<SimpleAppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _selectedTime = TimeOfDay.fromDateTime(widget.selectedDate);
    
    if (widget.existingEvent != null) {
      _titleController.text = widget.existingEvent!.title;
      _locationController.text = widget.existingEvent!.location ?? '';
      _notesController.text = widget.existingEvent!.description;
      _selectedDate = widget.existingEvent!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.existingEvent!.dateTime);
    } else if (widget.clinicName != null && widget.clinicName!.isNotEmpty) {
      _locationController.text = widget.clinicName!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.backgroundGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius4)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppTheme.spacing4),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: AppTheme.spacing4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Title
                Text(
                  widget.existingEvent == null ? 'New Appointment' : 'Edit Appointment',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                Gap(AppTheme.spacing5),

                // Title field
                _buildTextField(
                  controller: _titleController,
                  label: 'Title',
                  hint: 'e.g., Vet Checkup',
                  icon: Icons.event,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                Gap(AppTheme.spacing3),

                // Location field
                _buildTextField(
                  controller: _locationController,
                  label: 'Location',
                  hint: 'Clinic name or address',
                  icon: Icons.location_on,
                ),
                Gap(AppTheme.spacing3),

                // Date & Time row
                Row(
                  children: [
                    Expanded(child: _buildDatePicker()),
                    Gap(AppTheme.spacing3),
                    Expanded(child: _buildTimePicker()),
                  ],
                ),
                Gap(AppTheme.spacing3),

                // Notes field
                _buildTextField(
                  controller: _notesController,
                  label: 'Notes',
                  hint: 'Optional notes',
                  icon: Icons.notes,
                  maxLines: 2,
                ),
                Gap(AppTheme.spacing5),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildButton(
                        text: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                        isOutlined: true,
                      ),
                    ),
                    Gap(AppTheme.spacing3),
                    Expanded(
                      child: _buildButton(
                        text: widget.existingEvent == null ? 'Add' : 'Update',
                        onPressed: _isSubmitting ? null : _submitForm,
                        isLoading: _isSubmitting,
                      ),
                    ),
                  ],
                ),

                if (widget.existingEvent != null) ...[
                  Gap(AppTheme.spacing3),
                  _buildButton(
                    text: 'Delete',
                    onPressed: _confirmDelete,
                    isDestructive: true,
                  ),
                ],
                Gap(AppTheme.spacing2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Gap(AppTheme.spacing2),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            maxLines: maxLines,
            style: TextStyle(color: AppTheme.primary, fontSize: 16.sp),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.neutral700.withValues(alpha: 0.5)),
              prefixIcon: icon != null ? Icon(icon, color: AppTheme.primary, size: 20) : null,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Gap(AppTheme.spacing2),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now().subtract(Duration(days: 30)),
              lastDate: DateTime.now().add(Duration(days: 365 * 2)),
            );
            if (date != null) setState(() => _selectedDate = date);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius2),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: AppTheme.primary, size: 20),
                Gap(AppTheme.spacing2),
                Text(
                  DateFormat('MMM d, yyyy').format(_selectedDate),
                  style: TextStyle(color: AppTheme.primary, fontSize: 16.sp),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Gap(AppTheme.spacing2),
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _selectedTime,
            );
            if (time != null) setState(() => _selectedTime = time);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius2),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: AppTheme.primary, size: 20),
                Gap(AppTheme.spacing2),
                Text(
                  _selectedTime.format(context),
                  style: TextStyle(color: AppTheme.primary, fontSize: 16.sp),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    VoidCallback? onPressed,
    bool isOutlined = false,
    bool isDestructive = false,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive
              ? Colors.red.withValues(alpha: 0.2)
              : isOutlined
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white,
          foregroundColor: isDestructive
              ? Colors.red
              : isOutlined
                  ? Colors.white
                  : AppTheme.primary,
          elevation: isOutlined ? 0 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius2),
            side: isOutlined
                ? BorderSide(color: Colors.white.withValues(alpha: 0.3))
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: const Text('Are you sure you want to delete this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteEvent();
    }
  }

  Future<void> _deleteEvent() async {
    if (widget.existingEvent == null) return;

    setState(() => _isSubmitting = true);
    try {
      final eventProvider = context.read<EventProvider>();
      await eventProvider.deleteEvent(widget.existingEvent!.id);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();

      final event = AppointmentEvent(
        id: widget.existingEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _notesController.text.trim().isEmpty
            ? 'Appointment'
            : _notesController.text.trim(),
        dateTime: dateTime,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        petId: widget.petId ?? widget.existingEvent?.petId,
        userId: userId,
        createdAt: widget.existingEvent?.createdAt ?? now,
        updatedAt: now,
      );

      final eventProvider = context.read<EventProvider>();
      if (widget.existingEvent == null) {
        await eventProvider.createEvent(event);
      } else {
        await eventProvider.updateEvent(event.id, event);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment ${widget.existingEvent == null ? 'added' : 'updated'}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
