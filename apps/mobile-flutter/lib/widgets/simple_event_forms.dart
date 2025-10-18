import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import '../theme/app_theme.dart';
import '../pages/add_symptom_sheet.dart';

class SimpleAddEventDialog extends StatelessWidget {
  final DateTime selectedDate;
  final String? petId;

  const SimpleAddEventDialog({
    super.key,
    required this.selectedDate,
    this.petId,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add New Event',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _EventTypeButton(
              icon: Icons.event,
              label: 'Appointment',
              color: AppTheme.primaryBlue,
              onTap: () => _showAppointmentForm(context),
            ),
            const SizedBox(height: 12),
            _EventTypeButton(
              icon: Icons.medication,
              label: 'Medication',
              color: AppTheme.primaryGreen,
              onTap: () => _showMedicationForm(context),
            ),
            const SizedBox(height: 12),
            _EventTypeButton(
              icon: Icons.note,
              label: 'Quick Note',
              color: AppTheme.accentCoral,
              onTap: () => _showNoteForm(context),
            ),
            const SizedBox(height: 12),
            _EventTypeButton(
              icon: Icons.monitor_heart,
              label: 'Symptom',
              color: Colors.orange,
              onTap: () => _showSymptomForm(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showSymptomForm(BuildContext context) async {
    Navigator.pop(context);
    // Get first pet or let user choose
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final petsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('pets')
        .limit(1)
        .get();
    if (petsSnap.docs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please add a pet first')));
      }
      return;
    }
    final petIdToUse = petId ?? petsSnap.docs.first.id;
    if (context.mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AddSymptomSheet(petId: petIdToUse),
        ),
      );
    }
  }

  void _showAppointmentForm(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: eventProvider,
        child: SimpleAppointmentForm(selectedDate: selectedDate, petId: petId),
      ),
    );
  }

  void _showMedicationForm(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: eventProvider,
        child: SimpleMedicationForm(selectedDate: selectedDate, petId: petId),
      ),
    );
  }

  void _showNoteForm(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: eventProvider,
        child: SimpleNoteForm(selectedDate: selectedDate, petId: petId),
      ),
    );
  }
}

class _EventTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _EventTypeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class SimpleAppointmentForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final AppointmentEvent? existingEvent;

  const SimpleAppointmentForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
  });

  @override
  State<SimpleAppointmentForm> createState() => _SimpleAppointmentFormState();
}

class _SimpleAppointmentFormState extends State<SimpleAppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _vetNameController;
  late final TextEditingController _locationController;
  late DateTime _selectedDateTime;
  String? _selectedPetId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingEvent?.title ?? '',
    );
    _vetNameController = TextEditingController(
      text: widget.existingEvent?.vetName ?? '',
    );
    _locationController = TextEditingController(
      text: widget.existingEvent?.location ?? '',
    );
    _selectedDateTime = widget.existingEvent?.dateTime ?? widget.selectedDate;
    _selectedPetId = widget.petId ?? widget.existingEvent?.petId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _vetNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxWidth: 800, minWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with aligned close button
                  Row(
                    children: [
                      Icon(Icons.event, size: 18, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.existingEvent == null
                              ? 'Add Appointment'
                              : 'Edit Appointment',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title field
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        hintText: 'Vet visit, grooming, checkup',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.primaryBlue.withValues(alpha: 0.05),
                        prefixIcon: const Icon(
                          Icons.title,
                          color: AppTheme.primaryBlue,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter appointment title';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pet selection for appointment
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .collection('pets')
                          .orderBy('order')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: const Text('Loading pets...'),
                          );
                        }

                        final pets = snapshot.data!.docs;
                        if (pets.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: const Text(
                              'No pets found. Add a pet first.',
                            ),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedPetId,
                          decoration: InputDecoration(
                            labelText: 'Pet *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: AppTheme.primaryBlue.withValues(
                              alpha: 0.05,
                            ),
                            prefixIcon: const Icon(
                              Icons.pets,
                              color: AppTheme.primaryBlue,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          items: pets.map((doc) {
                            final pet = doc.data();
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppTheme.primaryBlue,
                                    child: Text(
                                      (pet['name'] ?? 'P')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(pet['name'] ?? 'Unknown'),
                                ],
                              ),
                            );
                          }).toList(),
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a pet';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              _selectedPetId = value;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Schedule Section
                  Text(
                    'Schedule',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date and Time
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _selectDateTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: AppTheme.primaryBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date & Time',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy • h:mm a',
                                    ).format(_selectedDateTime),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: AppTheme.primaryBlue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Details Section
                  Text(
                    'Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Location field
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextFormField(
                      controller: _vetNameController,
                      decoration: InputDecoration(
                        labelText: 'Location (Optional)',
                        hintText: 'Downtown Vet, Grooming Salon',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.primaryBlue.withValues(alpha: 0.05),
                        prefixIcon: const Icon(
                          Icons.location_on,
                          color: AppTheme.primaryBlue,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes field
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextFormField(
                      controller: _locationController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText:
                            'Bring vaccination records, special instructions',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.primaryBlue.withValues(alpha: 0.05),
                        prefixIcon: const Icon(
                          Icons.notes,
                          color: AppTheme.primaryBlue,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  if (widget.existingEvent != null) ...[
                    // Delete and Save buttons for editing
                    Row(
                      children: [
                        // Delete button (icon only)
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _deleteAppointment,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.errorRed,
                              side: BorderSide(
                                color: AppTheme.errorRed,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.delete, size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Save button
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _saveAppointment,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Icon(Icons.save, size: 20),
                                label: const Text(
                                  'Update',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Save button for new appointments
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveAppointment,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.save, size: 20),
                          label: const Text(
                            'Save Appointment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (time != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final eventProvider = context.read<EventProvider>();
      print('DEBUG: Saving appointment...');
      print('DEBUG: Current user ID: ${eventProvider.currentUserId}');

      final appointment = AppointmentEvent(
        id: widget.existingEvent?.id ?? CalendarEvent.generateId(),
        title: _titleController.text.trim(),
        description: '',
        dateTime: _selectedDateTime,
        petId: _selectedPetId,
        userId: eventProvider.currentUserId ?? '',
        createdAt: widget.existingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        vetName: _vetNameController.text.trim().isEmpty
            ? null
            : _vetNameController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        appointmentType: null,
        isConfirmed: widget.existingEvent?.isConfirmed ?? false,
        contactInfo: null,
      );

      print('DEBUG: Created appointment object: ${appointment.toJson()}');

      if (widget.existingEvent == null) {
        print('DEBUG: Creating new event...');
        final result = await eventProvider.createEvent(appointment);
        print('DEBUG: Create result: $result');
      } else {
        print('DEBUG: Updating existing event...');
        await eventProvider.updateEvent(appointment.id, appointment);
      }

      if (mounted) {
        print('DEBUG: Event saved successfully, closing dialog');
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('DEBUG: Error saving appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving appointment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAppointment() async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: Text(
          'Are you sure you want to delete "${_titleController.text}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && widget.existingEvent != null) {
      setState(() => _isLoading = true);

      try {
        final eventProvider = context.read<EventProvider>();
        await eventProvider.deleteEvent(widget.existingEvent!.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment deleted successfully!'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete appointment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class SimpleMedicationForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final MedicationEvent? existingEvent;

  const SimpleMedicationForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
  });

  @override
  State<SimpleMedicationForm> createState() => _SimpleMedicationFormState();
}

class _SimpleMedicationFormState extends State<SimpleMedicationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _instructionsController;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  String? _selectedPetId;
  // Recurrence controls
  String _recurrencePattern = 'daily'; // 'daily' | 'weekly' | 'monthly'
  int _recurrenceInterval = 1; // every N units
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingEvent?.medicationName ?? '',
    );
    _dosageController = TextEditingController(
      text: widget.existingEvent?.dosage ?? '',
    );
    _instructionsController = TextEditingController(
      text: widget.existingEvent?.instructions ?? '',
    );
    _startDate = widget.existingEvent?.dateTime ?? widget.selectedDate;
    _startTime = TimeOfDay.fromDateTime(_startDate);
    _selectedPetId = widget.petId ?? widget.existingEvent?.petId;
    _recurrencePattern = widget.existingEvent?.recurrencePattern ?? 'daily';
    _recurrenceInterval = widget.existingEvent?.recurrenceInterval ?? 1;
    _endDate =
        widget.existingEvent?.endDate ??
        _startDate.add(const Duration(days: 7));
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxWidth: 800, minWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with aligned close button
                  Row(
                    children: [
                      Icon(
                        Icons.medication,
                        size: 18,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.existingEvent == null
                              ? 'Add Medication'
                              : 'Edit Medication',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Medication name
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name *',
                        hintText: 'e.g., Heartworm pill, Flea drops',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.primaryGreen.withValues(
                          alpha: 0.05,
                        ),
                        prefixIcon: const Icon(
                          Icons.medical_services,
                          color: AppTheme.primaryGreen,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter medication name';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dosage
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextFormField(
                      controller: _dosageController,
                      decoration: InputDecoration(
                        labelText: 'Amount *',
                        hintText: '1 tablet, 5mg, 2ml',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.primaryGreen.withValues(
                          alpha: 0.05,
                        ),
                        prefixIcon: const Icon(
                          Icons.local_pharmacy,
                          color: AppTheme.primaryGreen,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter dosage';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Instructions field
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextFormField(
                      controller: _instructionsController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'With food, morning only, etc.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.primaryGreen.withValues(
                          alpha: 0.05,
                        ),
                        prefixIcon: const Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryGreen,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pet selection for medication
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .collection('pets')
                          .orderBy('order')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: const Text('Loading pets...'),
                          );
                        }

                        final pets = snapshot.data!.docs;
                        if (pets.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: const Text(
                              'No pets found. Add a pet first.',
                            ),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedPetId,
                          decoration: InputDecoration(
                            labelText: 'Pet *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: AppTheme.primaryGreen.withValues(
                              alpha: 0.05,
                            ),
                            prefixIcon: const Icon(
                              Icons.pets,
                              color: AppTheme.primaryGreen,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          items: pets.map((doc) {
                            final pet = doc.data();
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppTheme.primaryGreen,
                                    child: Text(
                                      (pet['name'] ?? 'P')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(pet['name'] ?? 'Unknown'),
                                ],
                              ),
                            );
                          }).toList(),
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a pet';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              _selectedPetId = value;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Schedule Section
                  Text(
                    'Schedule',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Start date and time
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _selectStartDateTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: AppTheme.primaryBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Time',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateFormat('MMM dd, yyyy').format(_startDate)} at ${_startTime.format(context)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: AppTheme.primaryBlue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recurrence pattern with enhanced styling
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _recurrencePattern,
                            decoration: InputDecoration(
                              labelText: 'Frequency *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: AppTheme.primaryBlue.withValues(
                                alpha: 0.05,
                              ),
                              prefixIcon: const Icon(
                                Icons.repeat,
                                color: AppTheme.primaryBlue,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'daily',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.today,
                                      size: 18,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Daily'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'weekly',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.date_range,
                                      size: 18,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Weekly'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'monthly',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month,
                                      size: 18,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Monthly'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _recurrencePattern = value);
                            },
                          ),
                        ),
                      ),
                      if (_recurrencePattern != 'daily') ...[
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: TextFormField(
                              initialValue: _recurrenceInterval.toString(),
                              decoration: InputDecoration(
                                labelText: 'Every',
                                hintText: '1',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: AppTheme.primaryBlue.withValues(
                                  alpha: 0.05,
                                ),
                                prefixIcon: const Icon(
                                  Icons.numbers,
                                  color: AppTheme.primaryBlue,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final parsed = int.tryParse(value ?? '');
                                if (parsed == null || parsed <= 0) {
                                  return 'Enter a positive number';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                final parsed = int.tryParse(value);
                                if (parsed != null && parsed > 0) {
                                  setState(() => _recurrenceInterval = parsed);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // End date selection
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _selectEndDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_available,
                              color: AppTheme.primaryGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Date',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: AppTheme.primaryGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _endDate == null
                                        ? 'When to stop'
                                        : DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(_endDate!),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: _endDate == null
                                              ? AppTheme.textSecondary
                                              : null,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: AppTheme.primaryGreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Preview section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.preview,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Preview',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _buildPreviewText(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Enhanced save button
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveMedication,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save, size: 20),
                        label: Text(
                          widget.existingEvent == null
                              ? 'Create Schedule'
                              : 'Update Schedule',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buildPreviewText() {
    if (_endDate == null) return 'Select an end date to see schedule preview';

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final occurrences = _generateOccurrences(
      startDateTime,
      _endDate!,
      _recurrencePattern,
      _recurrenceInterval,
    );
    final String intervalText = _recurrencePattern == 'daily'
        ? 'daily'
        : _recurrencePattern == 'weekly'
        ? (_recurrenceInterval == 1
              ? 'weekly'
              : 'every $_recurrenceInterval weeks')
        : (_recurrenceInterval == 1
              ? 'monthly'
              : 'every $_recurrenceInterval months');

    return '${occurrences.length} reminders $intervalText at ${_startTime.format(context)} from ${DateFormat('MMM dd').format(_startDate)} to ${DateFormat('MMM dd').format(_endDate!)}.';
  }

  Future<void> _selectStartDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: _startTime,
      );

      if (time != null && mounted) {
        setState(() {
          _startDate = date;
          _startTime = time;
        });
      }
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (date != null && mounted) {
      setState(() {
        _endDate = date;
      });
    }
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final eventProvider = context.read<EventProvider>();
      print('DEBUG: Saving medication...');

      // Build a human-readable frequency string
      String frequencyString = 'Every ';
      frequencyString +=
          '$_recurrenceInterval ${_recurrencePattern == 'daily'
              ? (_recurrenceInterval == 1 ? 'day' : 'days')
              : _recurrencePattern == 'weekly'
              ? (_recurrenceInterval == 1 ? 'week' : 'weeks')
              : (_recurrenceInterval == 1 ? 'month' : 'months')}';

      // Generate all occurrences between start and end
      final DateTime effectiveEnd = _endDate ?? _startDate;
      final DateTime startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final occurrences = _generateOccurrences(
        startDateTime,
        effectiveEnd,
        _recurrencePattern,
        _recurrenceInterval,
      );

      // Create each occurrence as a separate event
      final String seriesId = CalendarEvent.generateId();
      for (final dt in occurrences) {
        final medication = MedicationEvent(
          id: CalendarEvent.generateId(),
          title: _nameController.text.trim(),
          description: '${_dosageController.text.trim()} - $frequencyString',
          dateTime: dt,
          petId: _selectedPetId,
          userId: eventProvider.currentUserId ?? '',
          seriesId: seriesId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          medicationName: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          frequency: frequencyString,
          endDate: effectiveEnd,
          isRecurring: true,
          recurrencePattern: _recurrencePattern,
          recurrenceInterval: _recurrenceInterval,
          customIntervalMinutes: null,
          remainingDoses: null,
          requiresNotification: true,
          lastTaken: null,
          nextDose: dt,
          instructions: _instructionsController.text.trim().isEmpty
              ? null
              : _instructionsController.text.trim(),
        );
        await eventProvider.createEvent(medication);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('DEBUG: Error saving medication: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving medication: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<DateTime> _generateOccurrences(
    DateTime start,
    DateTime end,
    String pattern,
    int interval,
  ) {
    final List<DateTime> result = [];
    DateTime current = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
      start.minute,
    );
    final DateTime endDay = DateTime(
      end.year,
      end.month,
      end.day,
      end.hour,
      end.minute,
    );

    while (!current.isAfter(endDay)) {
      result.add(current);
      if (pattern == 'daily') {
        current = current.add(Duration(days: interval));
      } else if (pattern == 'weekly') {
        current = current.add(Duration(days: 7 * interval));
      } else {
        // monthly
        int y = current.year;
        int m = current.month + interval;
        while (m > 12) {
          y += 1;
          m -= 12;
        }
        final int day = current.day;
        final int lastDayOfTarget = DateTime(y, m + 1, 0).day;
        final int d = day > lastDayOfTarget ? lastDayOfTarget : day;
        current = DateTime(y, m, d, current.hour, current.minute);
      }
    }

    return result;
  }
}

class SimpleNoteForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final NoteEvent? existingEvent;

  const SimpleNoteForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
  });

  @override
  State<SimpleNoteForm> createState() => _SimpleNoteFormState();
}

class _SimpleNoteFormState extends State<SimpleNoteForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingEvent?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.existingEvent?.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.note, color: AppTheme.accentCoral),
                  const SizedBox(width: 8),
                  Text(
                    widget.existingEvent == null ? 'Quick Note' : 'Edit Note',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Note title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Note Title *',
                  hintText: 'e.g., Grooming reminder',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter note title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Note content
              TextFormField(
                controller: _contentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Details (Optional)',
                  hintText: 'Additional notes...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCoral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          widget.existingEvent == null
                              ? 'Save Note'
                              : 'Update Note',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final eventProvider = context.read<EventProvider>();
      print('DEBUG: Saving note...');

      final note = NoteEvent(
        id: widget.existingEvent?.id ?? CalendarEvent.generateId(),
        title: _titleController.text.trim(),
        description: _contentController.text.trim().isEmpty
            ? ''
            : _contentController.text.trim(),
        dateTime: widget.existingEvent?.dateTime ?? widget.selectedDate,
        petId: widget.petId,
        userId: eventProvider.currentUserId ?? '',
        createdAt: widget.existingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        isCompleted: widget.existingEvent?.isCompleted ?? false,
        priority:
            widget.existingEvent?.priority ?? 3, // 1=high, 2=medium, 3=low
        category: widget.existingEvent?.category,
        reminderDateTime: widget.existingEvent?.reminderDateTime,
      );

      print('DEBUG: Created note object: ${note.toJson()}');

      if (widget.existingEvent == null) {
        print('DEBUG: Creating new note...');
        final result = await eventProvider.createEvent(note);
        print('DEBUG: Create result: $result');
      } else {
        print('DEBUG: Updating existing note...');
        await eventProvider.updateEvent(note.id, note);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('DEBUG: Error saving note: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
