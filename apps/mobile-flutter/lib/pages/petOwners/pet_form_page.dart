import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

class PetFormPage extends StatefulWidget {
  const PetFormPage({super.key, this.petRef, this.initialData});
  final DocumentReference<Map<String, dynamic>>? petRef;
  final Map<String, dynamic>? initialData;

  @override
  State<PetFormPage> createState() => _PetFormPageState();
}

class _PetFormPageState extends State<PetFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _speciesController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _colorController = TextEditingController();
  final _microchipController = TextEditingController();
  final _veterinarianController = TextEditingController();
  final _medicalNotesController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  DateTime? _dateOfBirth;
  String _gender = 'Unknown';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _speciesController.text = widget.initialData!['species'] ?? '';
      _breedController.text = widget.initialData!['breed'] ?? '';
      _weightController.text = widget.initialData!['weight'] ?? '';
      _colorController.text = widget.initialData!['color'] ?? '';
      _microchipController.text = widget.initialData!['microchip'] ?? '';
      _veterinarianController.text = widget.initialData!['veterinarian'] ?? '';
      _medicalNotesController.text = widget.initialData!['medicalNotes'] ?? '';
      _emergencyContactController.text =
          widget.initialData!['emergencyContact'] ?? '';
      _gender = widget.initialData!['gender'] ?? 'Unknown';

      if (widget.initialData!['dateOfBirth'] != null) {
        _dateOfBirth = (widget.initialData!['dateOfBirth'] as Timestamp)
            .toDate();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _colorController.dispose();
    _microchipController.dispose();
    _veterinarianController.dispose();
    _medicalNotesController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _savePet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final petData = {
        'name': _nameController.text.trim(),
        'species': _speciesController.text.trim(),
        'breed': _breedController.text.trim(),
        'weight': _weightController.text.trim(),
        'color': _colorController.text.trim(),
        'microchip': _microchipController.text.trim(),
        'veterinarian': _veterinarianController.text.trim(),
        'medicalNotes': _medicalNotesController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'gender': _gender,
        'dateOfBirth': _dateOfBirth != null
            ? Timestamp.fromDate(_dateOfBirth!)
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.petRef == null) {
        // Creating new pet - get current pet count to assign proper order
        final existingPets = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('pets')
            .get();

        petData['createdAt'] = FieldValue.serverTimestamp();
        petData['order'] = existingPets.docs.length; // Assign next order number

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('pets')
            .add(petData);
      } else {
        // Updating existing pet
        await widget.petRef!.update(petData);
      }

      if (mounted && context.mounted) {
        Navigator.pop(context);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.petRef == null
                  ? 'Pet added successfully!'
                  : 'Pet updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.petRef == null ? 'Add Pet' : 'Edit Pet'),
        backgroundColor: AppTheme.neutral700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information Section
              Text(
                'Basic Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral700,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Pet Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _speciesController,
                      decoration: const InputDecoration(
                        labelText: 'Species *',
                        hintText: 'Dog, Cat, Bird, etc.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the species';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _breedController,
                      decoration: const InputDecoration(
                        labelText: 'Breed *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_florist),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the breed';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date of Birth and Gender
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              _dateOfBirth ??
                              DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null && mounted && context.mounted) {
                          setState(() {
                            _dateOfBirth = date;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.cake),
                        ),
                        child: Text(
                          _dateOfBirth != null
                              ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                              : 'Select date',
                          style: TextStyle(
                            color: _dateOfBirth != null
                                ? null
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.wc),
                      ),
                      items: ['Male', 'Female', 'Unknown'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _gender = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Weight and Color
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        hintText: 'e.g., 15 kg, 3.5 lbs',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.monitor_weight),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _colorController,
                      decoration: const InputDecoration(
                        labelText: 'Color/Markings',
                        hintText: 'Brown, White spots, etc.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.palette),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Medical Information Section
              Text(
                'Medical Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral700,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _microchipController,
                decoration: const InputDecoration(
                  labelText: 'Microchip Number',
                  hintText: 'ID number if microchipped',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.memory),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _veterinarianController,
                decoration: const InputDecoration(
                  labelText: 'Veterinarian',
                  hintText: 'Primary vet name or clinic',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_hospital),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _medicalNotesController,
                decoration: const InputDecoration(
                  labelText: 'Medical Notes',
                  hintText: 'Allergies, conditions, medications',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medical_information),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Emergency Contact Section
              Text(
                'Emergency Contact',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral700,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact',
                  hintText: 'Name and phone number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.emergency),
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neutral700,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.petRef == null ? 'Add Pet' : 'Update Pet',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
