import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/medication_model.dart';
import '../repositories/medication_repository.dart';

/// Provider for managing medication state
class MedicationProvider extends ChangeNotifier {
  final MedicationRepository _repository;

  // State
  Map<String, List<Medication>> _medicationsByPet = {};
  bool _isLoading = false;
  String? _error;

  // Stream subscriptions
  final Map<String, StreamSubscription<List<Medication>>> _subscriptions = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentUserId => _repository.currentUserId;

  MedicationProvider(this._repository);

  /// Get all medications for a specific pet
  List<Medication> getMedicationsForPet(String petId) {
    return _medicationsByPet[petId] ?? [];
  }

  /// Get active medications for a specific pet
  List<Medication> getActiveMedicationsForPet(String petId) {
    return getMedicationsForPet(petId)
        .where((m) => m.status == MedicationStatus.active)
        .toList();
  }

  /// Get past medications for a specific pet
  List<Medication> getPastMedicationsForPet(String petId) {
    return getMedicationsForPet(petId)
        .where((m) => m.status != MedicationStatus.active)
        .toList();
  }

  /// Get all active medications across all subscribed pets
  List<Medication> get allActiveMedications {
    final allMeds = <Medication>[];
    for (final meds in _medicationsByPet.values) {
      allMeds.addAll(meds.where((m) => m.status == MedicationStatus.active));
    }
    // Sort by next dose time
    allMeds.sort((a, b) {
      final aNext = a.nextDose;
      final bNext = b.nextDose;
      if (aNext == null && bNext == null) return 0;
      if (aNext == null) return 1;
      if (bNext == null) return -1;
      return aNext.compareTo(bNext);
    });
    return allMeds;
  }

  /// Get count of active medications
  int get activeMedicationCount {
    int count = 0;
    for (final meds in _medicationsByPet.values) {
      count += meds.where((m) => m.status == MedicationStatus.active).length;
    }
    return count;
  }

  /// Subscribe to medications for a pet (real-time updates)
  void subscribeToPet(String petId) {
    if (_subscriptions.containsKey(petId)) return;

    developer.log(
      'Subscribing to medications for pet $petId',
      name: 'MedicationProvider',
    );

    final subscription = _repository.streamMedicationsForPet(petId).listen(
      (medications) {
        _medicationsByPet[petId] = medications;
        notifyListeners();
      },
      onError: (e) {
        developer.log(
          'Error streaming medications for pet $petId: $e',
          name: 'MedicationProvider',
        );
        _error = e.toString();
        notifyListeners();
      },
    );

    _subscriptions[petId] = subscription;
  }

  /// Unsubscribe from a pet's medications
  void unsubscribeFromPet(String petId) {
    _subscriptions[petId]?.cancel();
    _subscriptions.remove(petId);
    _medicationsByPet.remove(petId);
  }

  /// Subscribe to multiple pets at once
  void subscribeToPets(List<String> petIds) {
    for (final petId in petIds) {
      subscribeToPet(petId);
    }
  }

  /// Load medications for a pet (one-time fetch)
  Future<void> loadMedicationsForPet(String petId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final medications = await _repository.getMedicationsForPet(petId);
      _medicationsByPet[petId] = medications;
    } catch (e) {
      _error = e.toString();
      developer.log(
        'Error loading medications for pet $petId: $e',
        name: 'MedicationProvider',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ CRUD Operations ============

  /// Create a new medication
  Future<String?> createMedication(Medication medication) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final id = await _repository.createMedication(medication);
      developer.log(
        'Created medication $id: ${medication.name}',
        name: 'MedicationProvider',
      );
      return id;
    } catch (e) {
      _error = e.toString();
      developer.log(
        'Error creating medication: $e',
        name: 'MedicationProvider',
      );
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing medication
  Future<bool> updateMedication(Medication medication) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.updateMedication(medication);
      developer.log(
        'Updated medication ${medication.id}',
        name: 'MedicationProvider',
      );
      return true;
    } catch (e) {
      _error = e.toString();
      developer.log(
        'Error updating medication: $e',
        name: 'MedicationProvider',
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a medication
  Future<bool> deleteMedication(String petId, String medicationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.deleteMedication(petId, medicationId);
      developer.log(
        'Deleted medication $medicationId',
        name: 'MedicationProvider',
      );
      return true;
    } catch (e) {
      _error = e.toString();
      developer.log(
        'Error deleting medication: $e',
        name: 'MedicationProvider',
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ Status Operations ============

  /// Mark medication as completed
  Future<bool> completeMedication(String petId, String medicationId) async {
    try {
      await _repository.completeMedication(petId, medicationId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Pause a medication
  Future<bool> pauseMedication(String petId, String medicationId) async {
    try {
      await _repository.pauseMedication(petId, medicationId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Resume a paused medication
  Future<bool> resumeMedication(String petId, String medicationId) async {
    try {
      await _repository.resumeMedication(petId, medicationId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Discontinue a medication
  Future<bool> discontinueMedication(String petId, String medicationId) async {
    try {
      await _repository.discontinueMedication(petId, medicationId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============ Dose Logging ============

  /// Log a dose as taken
  Future<bool> logDoseTaken(
    String petId,
    String medicationId,
    DateTime scheduledTime, {
    String? notes,
  }) async {
    try {
      await _repository.logDoseTaken(
        petId,
        medicationId,
        scheduledTime,
        notes: notes,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Log a dose as skipped
  Future<bool> logDoseSkipped(
    String petId,
    String medicationId,
    DateTime scheduledTime, {
    String? reason,
  }) async {
    try {
      await _repository.logDoseSkipped(
        petId,
        medicationId,
        scheduledTime,
        reason: reason,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============ Helper Methods ============

  /// Get a specific medication by ID
  Medication? getMedicationById(String petId, String medicationId) {
    final medications = _medicationsByPet[petId];
    if (medications == null) return null;
    try {
      return medications.firstWhere((m) => m.id == medicationId);
    } catch (_) {
      return null;
    }
  }

  /// Check if any medication needs attention (dose due soon)
  bool get hasDueDoses {
    final now = DateTime.now();
    final soon = now.add(const Duration(hours: 1));

    for (final meds in _medicationsByPet.values) {
      for (final med in meds) {
        if (med.isActive) {
          final nextDose = med.nextDose;
          if (nextDose != null && nextDose.isBefore(soon)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Get medications due today
  List<Medication> get medicationsDueToday {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final dueMeds = <Medication>[];

    for (final meds in _medicationsByPet.values) {
      for (final med in meds) {
        if (med.isActive && med.frequency != MedicationFrequency.asNeeded) {
          final nextDose = med.nextDose;
          if (nextDose != null &&
              nextDose.isAfter(todayStart) &&
              nextDose.isBefore(todayEnd)) {
            dueMeds.add(med);
          }
        }
      }
    }

    // Sort by next dose time
    dueMeds.sort((a, b) {
      final aNext = a.nextDose;
      final bNext = b.nextDose;
      if (aNext == null) return 1;
      if (bNext == null) return -1;
      return aNext.compareTo(bNext);
    });

    return dueMeds;
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
