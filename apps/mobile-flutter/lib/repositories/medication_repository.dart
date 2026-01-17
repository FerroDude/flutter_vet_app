import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication_model.dart';

/// Repository for medication CRUD operations
class MedicationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId;

  MedicationRepository(this._currentUserId);

  String? get currentUserId => _currentUserId;

  // ============ Collection References ============

  /// Get medications collection for a specific pet
  CollectionReference<Map<String, dynamic>> _getMedicationsCollection(
    String petId,
  ) {
    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('pets')
        .doc(petId)
        .collection('medications');
  }

  // ============ CRUD Operations ============

  /// Create a new medication
  Future<String> createMedication(Medication medication) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Store in pet's medications subcollection
      final docRef = await _getMedicationsCollection(
        medication.petId,
      ).add(medication.toJson());

      developer.log(
        'Created medication ${docRef.id} for pet ${medication.petId}',
        name: 'MedicationRepository',
      );

      return docRef.id;
    } catch (e) {
      developer.log(
        'Error creating medication: $e',
        name: 'MedicationRepository',
      );
      rethrow;
    }
  }

  /// Update an existing medication
  Future<void> updateMedication(Medication medication) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _getMedicationsCollection(
        medication.petId,
      ).doc(medication.id).update(medication.toJson());

      developer.log(
        'Updated medication ${medication.id}',
        name: 'MedicationRepository',
      );
    } catch (e) {
      developer.log(
        'Error updating medication: $e',
        name: 'MedicationRepository',
      );
      rethrow;
    }
  }

  /// Delete a medication
  Future<void> deleteMedication(String petId, String medicationId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _getMedicationsCollection(petId).doc(medicationId).delete();

      developer.log(
        'Deleted medication $medicationId',
        name: 'MedicationRepository',
      );
    } catch (e) {
      developer.log(
        'Error deleting medication: $e',
        name: 'MedicationRepository',
      );
      rethrow;
    }
  }

  // ============ Query Operations ============

  /// Get all medications for a specific pet
  Future<List<Medication>> getMedicationsForPet(String petId) async {
    if (_currentUserId == null) return [];

    try {
      final snapshot = await _getMedicationsCollection(petId).get();

      return snapshot.docs.map((doc) {
        return Medication.fromJson(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      developer.log(
        'Error getting medications: $e',
        name: 'MedicationRepository',
      );
      return [];
    }
  }

  /// Stream medications for a specific pet
  Stream<List<Medication>> streamMedicationsForPet(String petId) {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _getMedicationsCollection(petId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Medication.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Get active medications for a pet
  Future<List<Medication>> getActiveMedicationsForPet(String petId) async {
    if (_currentUserId == null) return [];

    try {
      final snapshot = await _getMedicationsCollection(
        petId,
      ).where('status', isEqualTo: MedicationStatus.active.index).get();

      return snapshot.docs.map((doc) {
        return Medication.fromJson(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      developer.log(
        'Error getting active medications: $e',
        name: 'MedicationRepository',
      );
      return [];
    }
  }

  /// Stream active medications for a pet
  Stream<List<Medication>> streamActiveMedicationsForPet(String petId) {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _getMedicationsCollection(petId)
        .where('status', isEqualTo: MedicationStatus.active.index)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Medication.fromJson(doc.data(), doc.id);
          }).toList();
        });
  }

  /// Get all active medications across all pets for the user
  Future<List<Medication>> getAllActiveMedications(List<String> petIds) async {
    if (_currentUserId == null || petIds.isEmpty) return [];

    final List<Medication> allMedications = [];

    for (final petId in petIds) {
      final medications = await getActiveMedicationsForPet(petId);
      allMedications.addAll(medications);
    }

    // Sort by next dose time
    allMedications.sort((a, b) {
      final aNext = a.nextDose;
      final bNext = b.nextDose;
      if (aNext == null && bNext == null) return 0;
      if (aNext == null) return 1;
      if (bNext == null) return -1;
      return aNext.compareTo(bNext);
    });

    return allMedications;
  }

  /// Stream all medications across all pets
  Stream<List<Medication>> streamAllMedications(List<String> petIds) {
    if (_currentUserId == null || petIds.isEmpty) {
      return Stream.value([]);
    }

    // Combine streams from all pets
    final streams = petIds.map((petId) => streamMedicationsForPet(petId));

    return StreamZip(streams).map((lists) {
      final allMedications = lists.expand((list) => list).toList();
      // Sort by status (active first) then by name
      allMedications.sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        return a.name.compareTo(b.name);
      });
      return allMedications;
    });
  }

  // ============ Status Updates ============

  /// Mark medication as completed
  Future<void> completeMedication(String petId, String medicationId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _getMedicationsCollection(petId).doc(medicationId).update({
      'status': MedicationStatus.completed.index,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Pause a medication
  Future<void> pauseMedication(String petId, String medicationId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _getMedicationsCollection(petId).doc(medicationId).update({
      'status': MedicationStatus.paused.index,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Resume a paused medication
  Future<void> resumeMedication(String petId, String medicationId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _getMedicationsCollection(petId).doc(medicationId).update({
      'status': MedicationStatus.active.index,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Discontinue a medication
  Future<void> discontinueMedication(String petId, String medicationId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _getMedicationsCollection(petId).doc(medicationId).update({
      'status': MedicationStatus.discontinued.index,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Extend a medication's duration
  Future<void> extendMedication(
    String petId,
    String medicationId,
    int additionalDays,
  ) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final docRef = _getMedicationsCollection(petId).doc(medicationId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('Medication not found');
    }

    final medication = Medication.fromJson(doc.data()!, doc.id);
    final extended = medication.extendBy(additionalDays: additionalDays);

    await docRef.update(extended.toJson());

    developer.log(
      'Extended medication $medicationId by $additionalDays days',
      name: 'MedicationRepository',
    );
  }

  // ============ Dose Logging ============

  /// Log a dose as taken
  Future<void> logDoseTaken(
    String petId,
    String medicationId,
    DateTime scheduledTime, {
    String? notes,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    developer.log(
      'logDoseTaken: petId=$petId, medicationId=$medicationId',
      name: 'MedicationRepository',
    );

    final docRef = _getMedicationsCollection(petId).doc(medicationId);
    final doc = await docRef.get();

    if (!doc.exists) {
      developer.log('Medication not found!', name: 'MedicationRepository');
      throw Exception('Medication not found');
    }

    final medication = Medication.fromJson(doc.data()!, doc.id);
    developer.log(
      'Current dose history count: ${medication.doseHistory.length}',
      name: 'MedicationRepository',
    );

    final newLog = DoseLog(
      id: Medication.generateId(),
      scheduledTime: scheduledTime,
      takenAt:
          scheduledTime, // Use the scheduled time as the taken time (for logging past doses)
      skipped: false,
      notes: notes,
    );

    final updatedHistory = [...medication.doseHistory, newLog];

    developer.log(
      'Updating dose history, new count: ${updatedHistory.length}',
      name: 'MedicationRepository',
    );

    await docRef.update({
      'doseHistory': updatedHistory.map((d) => d.toJson()).toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    developer.log(
      'Dose logged successfully to Firestore',
      name: 'MedicationRepository',
    );
  }

  /// Log a dose as skipped
  Future<void> logDoseSkipped(
    String petId,
    String medicationId,
    DateTime scheduledTime, {
    String? reason,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final docRef = _getMedicationsCollection(petId).doc(medicationId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('Medication not found');
    }

    final medication = Medication.fromJson(doc.data()!, doc.id);
    final newLog = DoseLog(
      id: Medication.generateId(),
      scheduledTime: scheduledTime,
      takenAt: null,
      skipped: true,
      notes: reason,
    );

    final updatedHistory = [...medication.doseHistory, newLog];

    await docRef.update({
      'doseHistory': updatedHistory.map((d) => d.toJson()).toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Undo the last dose taken (remove the most recent dose log)
  Future<bool> undoLastDose(String petId, String medicationId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final docRef = _getMedicationsCollection(petId).doc(medicationId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('Medication not found');
    }

    final medication = Medication.fromJson(doc.data()!, doc.id);

    // Find and remove the last dose that was taken (has takenAt)
    final doseHistory = List<DoseLog>.from(medication.doseHistory);

    // Find the last taken dose
    int lastTakenIndex = -1;
    for (int i = doseHistory.length - 1; i >= 0; i--) {
      if (doseHistory[i].takenAt != null) {
        lastTakenIndex = i;
        break;
      }
    }

    if (lastTakenIndex == -1) {
      // No doses to undo
      return false;
    }

    doseHistory.removeAt(lastTakenIndex);

    await docRef.update({
      'doseHistory': doseHistory.map((d) => d.toJson()).toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    developer.log(
      'Removed last dose for medication $medicationId',
      name: 'MedicationRepository',
    );

    return true;
  }

  // ============ Vet Access (Read-only) ============

  /// Get medications for a pet (for vet view)
  Future<List<Medication>> getMedicationsForPetAsVet(
    String ownerId,
    String petId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(ownerId)
          .collection('pets')
          .doc(petId)
          .collection('medications')
          .get();

      return snapshot.docs.map((doc) {
        return Medication.fromJson(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      developer.log(
        'Error getting medications as vet: $e',
        name: 'MedicationRepository',
      );
      return [];
    }
  }

  /// Stream medications for a pet (for vet view)
  Stream<List<Medication>> streamMedicationsForPetAsVet(
    String ownerId,
    String petId,
  ) {
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('pets')
        .doc(petId)
        .collection('medications')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Medication.fromJson(doc.data(), doc.id);
          }).toList();
        });
  }
}

/// Helper class to combine multiple streams
class StreamZip<T> extends Stream<List<T>> {
  final Iterable<Stream<T>> _streams;

  StreamZip(this._streams);

  @override
  StreamSubscription<List<T>> listen(
    void Function(List<T> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final controller = StreamController<List<T>>();
    final subscriptions = <StreamSubscription<T>>[];
    final values = <int, T>{};
    var doneCount = 0;
    final streamCount = _streams.length;

    var index = 0;
    for (final stream in _streams) {
      final currentIndex = index++;
      final subscription = stream.listen(
        (value) {
          values[currentIndex] = value;
          if (values.length == streamCount) {
            final result = List.generate(streamCount, (i) => values[i] as T);
            controller.add(result);
          }
        },
        onError: (e, s) => controller.addError(e, s),
        onDone: () {
          doneCount++;
          if (doneCount == streamCount) {
            controller.close();
          }
        },
      );
      subscriptions.add(subscription);
    }

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
    };

    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
