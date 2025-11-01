import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/symptom_models.dart';
import '../../services/pet_service.dart';
import '../../widgets/modern_modals.dart';

class AddSymptomSheet extends StatefulWidget {
  const AddSymptomSheet({super.key, required this.petId});
  final String petId;

  @override
  State<AddSymptomSheet> createState() => _AddSymptomSheetState();
}

class _AddSymptomSheetState extends State<AddSymptomSheet> {
  final _petService = PetService();
  SymptomType _type = SymptomType.vomiting;
  DateTime _timestamp = DateTime.now();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModernBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ModernModalHeader(
            title: 'Add Symptom',
            icon: Icons.healing,
            iconColor: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 24),
          ModernModalDropdown<SymptomType>(
            label: 'Symptom Type',
            value: _type,
            icon: Icons.medical_information,
            items: SymptomType.values
                .map(
                  (t) => DropdownMenuItem(value: t, child: Text(_labelFor(t))),
                )
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 16),
          ModernModalTextField(
            readOnly: true,
            label: 'When',
            hint: DateFormat('MMM dd, yyyy • h:mm a').format(_timestamp),
            icon: Icons.calendar_today,
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 16),
          ModernModalTextField(
            controller: _noteController,
            label: 'Additional Notes (Optional)',
            hint: 'Describe what happened...',
            icon: Icons.note_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          ModernModalButton(
            text: 'Add Symptom',
            isLoading: _saving,
            onPressed: _save,
            color: const Color(0xFFEF4444),
            icon: Icons.add,
          ),
        ],
      ),
    );
  }

  String _labelFor(SymptomType t) {
    switch (t) {
      case SymptomType.vomiting:
        return 'Vomiting';
      case SymptomType.diarrhea:
        return 'Diarrhea';
      case SymptomType.cough:
        return 'Cough';
      case SymptomType.sneezing:
        return 'Sneezing';
      case SymptomType.choking:
        return 'Choking';
      case SymptomType.seizure:
        return 'Seizure';
      case SymptomType.disorientation:
        return 'Disorientation';
      case SymptomType.circling:
        return 'Circling';
      case SymptomType.restlessness:
        return 'Restlessness';
      case SymptomType.limping:
        return 'Limping';
      case SymptomType.jointDiscomfort:
        return 'Joint discomfort';
      case SymptomType.itching:
        return 'Itching';
      case SymptomType.ocularDischarge:
        return 'Ocular discharge';
      case SymptomType.vaginalDischarge:
        return 'Vaginal discharge';
      case SymptomType.estrus:
        return 'Estrus';
      case SymptomType.other:
        return 'Other';
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
    );
    if (time == null) return;
    setState(() {
      _timestamp = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    try {
      setState(() => _saving = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');
      await _petService.addSymptom(
        ownerId: user.uid,
        petId: widget.petId,
        type: _type,
        at: _timestamp,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Symptom added successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save symptom: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
