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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(color: AppTheme.primary, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.neutral700.withValues(alpha: 0.5)),
              prefixIcon: icon != null
                  ? Icon(icon, color: AppTheme.primary, size: 20)
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius2),
                borderSide: BorderSide(color: Colors.red, width: 1),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

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
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.petRef == null ? 'Add Pet' : 'Edit Pet'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _nameController,
                label: 'Pet Name *',
                icon: Icons.pets,
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
                    child: _buildTextField(
                      controller: _speciesController,
                      label: 'Species *',
                      hint: 'Dog, Cat, Bird, etc.',
                      icon: Icons.category,
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
                    child: _buildTextField(
                      controller: _breedController,
                      label: 'Breed *',
                      icon: Icons.local_florist,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date of Birth',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppTheme.radius2),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.cake, color: AppTheme.primary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _dateOfBirth != null
                                        ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                        : 'Select date',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _dateOfBirth != null
                                          ? AppTheme.primary
                                          : AppTheme.neutral700.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gender',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radius2),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              icon: Icon(Icons.wc, color: AppTheme.primary, size: 20),
                            ),
                            dropdownColor: Colors.white,
                            style: TextStyle(color: AppTheme.primary, fontSize: 16),
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
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Weight and Color
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _weightController,
                      label: 'Weight',
                      hint: 'e.g., 15 kg, 3.5 lbs',
                      icon: Icons.monitor_weight,
                      keyboardType: TextInputType.text,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _colorController,
                      label: 'Color/Markings',
                      hint: 'Brown, White spots, etc.',
                      icon: Icons.palette,
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _microchipController,
                label: 'Microchip Number',
                hint: 'ID number if microchipped',
                icon: Icons.memory,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _veterinarianController,
                label: 'Veterinarian',
                hint: 'Primary vet name or clinic',
                icon: Icons.local_hospital,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _medicalNotesController,
                label: 'Medical Notes',
                hint: 'Allergies, conditions, medications',
                icon: Icons.medical_information,
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Emergency Contact Section
              Text(
                'Emergency Contact',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _emergencyContactController,
                label: 'Emergency Contact',
                hint: 'Name and phone number',
                icon: Icons.emergency,
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius2),
                    ),
                    elevation: 4,
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
      ),
    );
  }
}
