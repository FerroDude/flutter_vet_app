import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import 'modern_modals.dart';
import 'medication_widgets.dart';

/// Modern event type selection dialog
class ModernEventTypeDialog extends StatelessWidget {
  final DateTime selectedDate;
  final String? petId;

  const ModernEventTypeDialog({
    super.key,
    required this.selectedDate,
    this.petId,
  });

  @override
  Widget build(BuildContext context) {
    return ModernModal(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ModernModalHeader(
            title: 'Add New Event',
            icon: Icons.add_circle_outline,
          ),
          const SizedBox(height: 20),
          ModernActionCard(
            title: 'Appointment',
            subtitle: 'Schedule vet visits, grooming, checkups',
            icon: Icons.event_outlined,
            color: const Color(0xFF3B82F6),
            onTap: () => _showAppointmentForm(context),
          ),
          ModernActionCard(
            title: 'Medication',
            subtitle: 'Track medicines and supplements',
            icon: Icons.medication_outlined,
            color: const Color(0xFF10B981),
            onTap: () => _showMedicationForm(context),
          ),
          ModernActionCard(
            title: 'Quick Note',
            subtitle: 'Add a reminder or note',
            icon: Icons.note_outlined,
            color: const Color(0xFF8B5CF6),
            onTap: () => _showNoteForm(context),
          ),
        ],
      ),
    );
  }

  void _showAppointmentForm(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: eventProvider,
        child: ModernAppointmentForm(selectedDate: selectedDate, petId: petId),
      ),
    );
  }

  void _showMedicationForm(BuildContext context) {
    Navigator.pop(context);
    showMedicationForm(context, petId: petId);
  }

  void _showNoteForm(BuildContext context) {
    final eventProvider = context.read<EventProvider>();
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: eventProvider,
        child: ModernNoteForm(selectedDate: selectedDate, petId: petId),
      ),
    );
  }
}

/// Modern Appointment Form
class ModernAppointmentForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final AppointmentEvent? existingEvent;

  const ModernAppointmentForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
  });

  @override
  State<ModernAppointmentForm> createState() => _ModernAppointmentFormState();
}

class _ModernAppointmentFormState extends State<ModernAppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _vetNameController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
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
    _notesController = TextEditingController(
      text: widget.existingEvent?.description ?? '',
    );
    _selectedDateTime = widget.existingEvent?.dateTime ?? widget.selectedDate;
    _selectedPetId = widget.petId ?? widget.existingEvent?.petId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _vetNameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModernModal(
      width: MediaQuery.of(context).size.width * 0.95,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ModernModalHeader(
                title: widget.existingEvent == null
                    ? 'Add Appointment'
                    : 'Edit Appointment',
                icon: Icons.event_outlined,
                iconColor: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 24),
              ModernModalTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'Vet visit, grooming, checkup',
                icon: Icons.title,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildPetSelector(),
              const SizedBox(height: 16),
              ModernModalTextField(
                controller: _vetNameController,
                label: 'Vet Name (Optional)',
                hint: 'Dr. Smith',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              ModernModalTextField(
                controller: _locationController,
                label: 'Location (Optional)',
                hint: 'Pet Clinic',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),
              ModernModalTextField(
                readOnly: true,
                label: 'Date & Time',
                hint: DateFormat(
                  'MMM dd, yyyy • h:mm a',
                ).format(_selectedDateTime),
                icon: Icons.calendar_today,
                onTap: _selectDateTime,
              ),
              const SizedBox(height: 16),
              ModernModalTextField(
                controller: _notesController,
                label: 'Notes (Optional)',
                hint: 'Additional details...',
                icon: Icons.note_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (widget.existingEvent != null)
                    Expanded(
                      child: ModernModalButton(
                        text: 'Delete',
                        isPrimary: false,
                        onPressed: _deleteEvent,
                        icon: Icons.delete_outline,
                      ),
                    ),
                  if (widget.existingEvent != null) const SizedBox(width: 12),
                  Expanded(
                    flex: widget.existingEvent != null ? 2 : 1,
                    child: ModernModalButton(
                      text: widget.existingEvent == null ? 'Add' : 'Update',
                      isLoading: _isLoading,
                      onPressed: _saveEvent,
                      color: const Color(0xFF3B82F6),
                      icon: widget.existingEvent == null
                          ? Icons.add
                          : Icons.check,
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
          );
        }

        final pets = snapshot.data!.docs;
        if (pets.isEmpty) {
          return ModernModalTextField(
            label: 'Pet',
            hint: 'No pets found',
            icon: Icons.pets,
            readOnly: true,
          );
        }

        // Auto-select first pet if none selected
        if (_selectedPetId == null && pets.isNotEmpty) {
          Future.microtask(() {
            setState(() => _selectedPetId = pets.first.id);
          });
        }

        return ModernModalDropdown<String>(
          label: 'Pet',
          value: _selectedPetId ?? pets.first.id,
          icon: Icons.pets,
          items: pets.map((doc) {
            final pet = doc.data();
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(pet['name'] ?? 'Unknown'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedPetId = value);
          },
        );
      },
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate() || _selectedPetId == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final eventProvider = context.read<EventProvider>();
      final event = AppointmentEvent(
        id:
            widget.existingEvent?.id ??
            'apt_${DateTime.now().millisecondsSinceEpoch}',
        petId: _selectedPetId!,
        dateTime: _selectedDateTime,
        title: _titleController.text.trim(),
        description: _notesController.text.trim(),
        userId: eventProvider.currentUserId ?? '',
        createdAt: widget.existingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        vetName: _vetNameController.text.trim().isEmpty
            ? null
            : _vetNameController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
      );

      if (widget.existingEvent != null) {
        await eventProvider.updateEvent(event.id, event);
      } else {
        await eventProvider.createEvent(event);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingEvent == null
                  ? 'Appointment added!'
                  : 'Appointment updated!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteEvent() async {
    if (widget.existingEvent == null) return;

    final confirmed = await showModernConfirmDialog(
      context,
      title: 'Delete Appointment',
      message: 'Are you sure you want to delete this appointment?',
      confirmText: 'Delete',
      confirmColor: const Color(0xFFEF4444),
      icon: Icons.delete_outline,
      iconColor: const Color(0xFFEF4444),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<EventProvider>().deleteEvent(
          widget.existingEvent!.id,
        );
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment deleted'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }
}

/// Modern Note Form
class ModernNoteForm extends StatefulWidget {
  final DateTime selectedDate;
  final String? petId;
  final NoteEvent? existingEvent;

  const ModernNoteForm({
    super.key,
    required this.selectedDate,
    this.petId,
    this.existingEvent,
  });

  @override
  State<ModernNoteForm> createState() => _ModernNoteFormState();
}

class _ModernNoteFormState extends State<ModernNoteForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late DateTime _selectedDateTime;
  String? _selectedPetId;
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
    _selectedDateTime = widget.existingEvent?.dateTime ?? widget.selectedDate;
    _selectedPetId = widget.petId ?? widget.existingEvent?.petId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModernModal(
      width: MediaQuery.of(context).size.width * 0.95,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ModernModalHeader(
                title: widget.existingEvent == null ? 'Add Note' : 'Edit Note',
                icon: Icons.note_outlined,
                iconColor: const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 24),
              ModernModalTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'Quick reminder',
                icon: Icons.title,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildPetSelector(),
              const SizedBox(height: 16),
              ModernModalTextField(
                readOnly: true,
                label: 'Date',
                hint: DateFormat('MMM dd, yyyy').format(_selectedDateTime),
                icon: Icons.calendar_today,
                onTap: _selectDate,
              ),
              const SizedBox(height: 16),
              ModernModalTextField(
                controller: _contentController,
                label: 'Note Content',
                hint: 'Write your note here...',
                icon: Icons.edit_note,
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter note content';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (widget.existingEvent != null)
                    Expanded(
                      child: ModernModalButton(
                        text: 'Delete',
                        isPrimary: false,
                        onPressed: _deleteEvent,
                        icon: Icons.delete_outline,
                      ),
                    ),
                  if (widget.existingEvent != null) const SizedBox(width: 12),
                  Expanded(
                    flex: widget.existingEvent != null ? 2 : 1,
                    child: ModernModalButton(
                      text: widget.existingEvent == null ? 'Add' : 'Update',
                      isLoading: _isLoading,
                      onPressed: _saveEvent,
                      color: const Color(0xFF8B5CF6),
                      icon: widget.existingEvent == null
                          ? Icons.add
                          : Icons.check,
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
            label: 'Pet (Optional)',
            hint: 'Loading pets...',
            icon: Icons.pets,
            readOnly: true,
          );
        }

        final pets = snapshot.data!.docs;
        if (pets.isEmpty) {
          return const SizedBox.shrink();
        }

        return ModernModalDropdown<String?>(
          label: 'Pet (Optional)',
          value: _selectedPetId,
          icon: Icons.pets,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('None (General Note)'),
            ),
            ...pets.map((doc) {
              final pet = doc.data();
              return DropdownMenuItem<String?>(
                value: doc.id,
                child: Text(pet['name'] ?? 'Unknown'),
              );
            }),
          ],
          onChanged: (value) {
            setState(() => _selectedPetId = value);
          },
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null && mounted) {
      setState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final eventProvider = context.read<EventProvider>();
      final event = NoteEvent(
        id:
            widget.existingEvent?.id ??
            'note_${DateTime.now().millisecondsSinceEpoch}',
        petId: _selectedPetId,
        dateTime: _selectedDateTime,
        title: _titleController.text.trim(),
        description: _contentController.text.trim(),
        userId: eventProvider.currentUserId ?? '',
        createdAt: widget.existingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.existingEvent != null) {
        await eventProvider.updateEvent(event.id, event);
      } else {
        await eventProvider.createEvent(event);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingEvent == null ? 'Note added!' : 'Note updated!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteEvent() async {
    if (widget.existingEvent == null) return;

    final confirmed = await showModernConfirmDialog(
      context,
      title: 'Delete Note',
      message: 'Are you sure you want to delete this note?',
      confirmText: 'Delete',
      confirmColor: const Color(0xFFEF4444),
      icon: Icons.delete_outline,
      iconColor: const Color(0xFFEF4444),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<EventProvider>().deleteEvent(
          widget.existingEvent!.id,
        );
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note deleted'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }
}
