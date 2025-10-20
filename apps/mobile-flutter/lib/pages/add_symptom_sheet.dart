import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/symptom_models.dart';
import '../../services/pet_service.dart';
import '../../theme/app_theme.dart';

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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Symptom',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SymptomType>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Symptom',
                border: OutlineInputBorder(),
              ),
              items: SymptomType.values
                  .map(
                    (t) =>
                        DropdownMenuItem(value: t, child: Text(_labelFor(t))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDateTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'When',
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('yyyy-MM-dd HH:mm').format(_timestamp)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save Symptom'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save symptom: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
