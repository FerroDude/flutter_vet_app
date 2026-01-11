import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/event_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/medication_provider.dart';
import '../../models/event_model.dart';
import '../../widgets/simple_event_forms.dart';
import '../../widgets/medication_widgets.dart';
import 'pet_form_page.dart';
import 'add_symptom_sheet.dart';

class PetDetailsPage extends StatelessWidget {
  const PetDetailsPage({super.key, required this.petRef});
  final DocumentReference<Map<String, dynamic>> petRef;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Pet Details'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              final doc = await petRef.get();
              if (doc.exists && context.mounted) {
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PetFormPage(petRef: petRef, initialData: doc.data()),
                  ),
                );
              }
            },
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            onPressed: () async {
              final shouldDelete = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('Delete Pet'),
                    content: const Text(
                      'Are you sure you want to delete this pet? '
                      'This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );

              if (shouldDelete == true && context.mounted) {
                try {
                  // Delete all events linked to this pet for the current user
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId != null) {
                    final eventsQuery = FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('events')
                        .where('petId', isEqualTo: petRef.id);

                    final eventsSnapshot = await eventsQuery.get();
                    for (final doc in eventsSnapshot.docs) {
                      await doc.reference.delete();
                    }
                  }

                  await petRef.delete();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Pet deleted')));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete pet: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: petRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Pet not found'));
          }

          final pet = snapshot.data!.data()!;
          final dateOfBirth = pet['dateOfBirth'] != null
              ? (pet['dateOfBirth'] as Timestamp).toDate()
              : null;

          String getAge() {
            if (dateOfBirth == null) return 'Unknown';
            final now = DateTime.now();
            final years = now.difference(dateOfBirth).inDays ~/ 365;
            final months = (now.difference(dateOfBirth).inDays % 365) ~/ 30;
            if (years > 0) return '$years years, $months months old';
            return '$months months old';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pet Header Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius4),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: AppTheme.neutral700,
                              child: Text(
                                (pet['name'] ?? 'P')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pet['name'] ?? 'Unknown',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${pet['species'] ?? 'Unknown'} • ${pet['breed'] ?? 'Unknown'}',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                  if (dateOfBirth != null)
                                    Text(
                                      getAge(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.neutral700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Basic Information Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius4),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Basic Information',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.neutral700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Species', pet['species']),
                        _buildInfoRow('Breed', pet['breed']),
                        _buildInfoRow('Gender', pet['gender']),
                        if (dateOfBirth != null)
                          _buildInfoRow(
                            'Date of Birth',
                            '${dateOfBirth.day}/${dateOfBirth.month}/${dateOfBirth.year}',
                          ),
                        _buildInfoRow('Weight', pet['weight']),
                        _buildInfoRow('Color/Markings', pet['color']),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Medical Information Card
                if (pet['microchip']?.isNotEmpty == true ||
                    pet['veterinarian']?.isNotEmpty == true ||
                    pet['medicalNotes']?.isNotEmpty == true)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radius4),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medical Information',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.neutral700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (pet['microchip']?.isNotEmpty == true)
                            _buildInfoRow('Microchip', pet['microchip']),
                          if (pet['veterinarian']?.isNotEmpty == true)
                            _buildInfoRow('Veterinarian', pet['veterinarian']),
                          if (pet['medicalNotes']?.isNotEmpty == true)
                            _buildInfoRow(
                              'Medical Notes',
                              pet['medicalNotes'],
                              isMultiline: true,
                            ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Emergency Contact Card
                if (pet['emergencyContact']?.isNotEmpty == true)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radius4),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Contact',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.neutral700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Contact', pet['emergencyContact']),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Quick Actions Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.neutral700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final eventProvider = context
                                          .read<EventProvider>();

                                      // Try to get clinic name, but don't fail if provider is unavailable
                                      String? clinicName;
                                      try {
                                        final userProvider = context
                                            .read<UserProvider>();
                                        final clinic =
                                            userProvider.connectedClinic;
                                        clinicName = clinic?.name;
                                      } catch (e) {
                                        clinicName = null;
                                      }

                                      await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        isDismissible: true,
                                        enableDrag: true,
                                        builder: (dialogContext) =>
                                            ChangeNotifierProvider.value(
                                              value: eventProvider,
                                              child: SimpleAppointmentForm(
                                                selectedDate: DateTime.now(),
                                                petId: petRef.id,
                                                clinicName: clinicName,
                                              ),
                                            ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Add Appointment'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) =>
                                            AddSymptomSheet(petId: petRef.id),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Add Symptom'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Medications Section (New First-Class Entity)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Builder(
                      builder: (context) {
                        // Subscribe to medications for this pet
                        final medicationProvider = context.watch<MedicationProvider>();
                        // Ensure we're subscribed to this pet's medications
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          medicationProvider.subscribeToPet(petRef.id);
                        });
                        
                        return MedicationsSection(
                          petId: petRef.id,
                          showAddButton: true,
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Pet's Appointments Section (only appointments now, medications are separate)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appointments',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.neutral700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Consumer<EventProvider>(
                          builder: (context, eventProvider, _) {
                            // Only show appointments and notes, medications are separate
                            final petEvents =
                                eventProvider.events
                                    .where((event) => 
                                        event.petId == petRef.id &&
                                        event is! MedicationEvent)
                                    .toList()
                                  ..sort(
                                    (a, b) => b.dateTime.compareTo(a.dateTime),
                                  );

                            if (petEvents.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_note,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'No appointments yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Column(
                              children: petEvents.take(5).map((event) {
                                final isAppointment = event is AppointmentEvent;
                                final icon = isAppointment
                                    ? Icons.event
                                    : Icons.note;
                                final color = isAppointment
                                    ? AppTheme.neutral700
                                    : AppTheme.neutral500;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              event.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              DateFormat(
                                                'MMM dd, yyyy • h:mm a',
                                              ).format(event.dateTime),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                        ),
                                        color: Colors.redAccent,
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (dialogContext) {
                                              return AlertDialog(
                                                title: const Text(
                                                  'Delete Event',
                                                ),
                                                content: const Text(
                                                  'Are you sure you want to delete this event?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(
                                                        dialogContext,
                                                      ).pop(false);
                                                    },
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(
                                                        dialogContext,
                                                      ).pop(true);
                                                    },
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.red,
                                                    ),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );

                                          if (confirmed == true &&
                                              context.mounted) {
                                            final success = await eventProvider
                                                .deleteEvent(event.id);
                                            if (success && context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Event deleted',
                                                  ),
                                                ),
                                              );
                                            } else if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Failed to delete event',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String? value, {
    bool isMultiline = false,
  }) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}
