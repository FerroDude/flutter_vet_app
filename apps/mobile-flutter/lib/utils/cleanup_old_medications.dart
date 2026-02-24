import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';

/// Temporary utility to delete old medication events from the events collection.
/// Run this once to clean up old data before testing the new medication system.
///
/// Usage: Call `cleanupOldMedicationEvents()` from anywhere (e.g., a button tap)
/// Then DELETE this file after cleanup is complete.
class MedicationCleanup {
  static Future<int> cleanupOldMedicationEvents() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final firestore = FirebaseFirestore.instance;

    // Query all events where type == 1 (medication type index)
    // EventType enum: appointment=0, medication=1, note=2
    final eventsRef = firestore
        .collection('users')
        .doc(userId)
        .collection('events');

    final snapshot = await eventsRef
        .where('type', isEqualTo: 1) // 1 = EventType.medication.index
        .get();

    developer.log(
      'Found ${snapshot.docs.length} old medication events to delete',
      name: 'MedicationCleanup',
    );

    // Delete in batches (Firestore limit is 500 per batch)
    int deletedCount = 0;
    final batch = firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      deletedCount++;

      // Commit every 400 documents
      if (deletedCount % 400 == 0) {
        await batch.commit();
        developer.log(
          'Deleted $deletedCount medication events so far...',
          name: 'MedicationCleanup',
        );
      }
    }

    // Commit remaining
    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }

    developer.log(
      'Successfully deleted $deletedCount old medication events',
      name: 'MedicationCleanup',
    );
    return deletedCount;
  }

  /// Also clean up any medications in the new collection (for fresh testing)
  static Future<int> cleanupNewMedications() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final firestore = FirebaseFirestore.instance;
    int totalDeleted = 0;

    // Get all pets
    final petsSnapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('pets')
        .get();

    for (final petDoc in petsSnapshot.docs) {
      // Get medications for this pet
      final medsSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('pets')
          .doc(petDoc.id)
          .collection('medications')
          .get();

      // Delete each medication
      for (final medDoc in medsSnapshot.docs) {
        await medDoc.reference.delete();
        totalDeleted++;
      }
    }

    developer.log(
      'Successfully deleted $totalDeleted medications from new system',
      name: 'MedicationCleanup',
    );
    return totalDeleted;
  }

  /// Delete both old events and new medications
  static Future<Map<String, int>> cleanupAll() async {
    final oldCount = await cleanupOldMedicationEvents();
    final newCount = await cleanupNewMedications();

    return {'oldMedicationEvents': oldCount, 'newMedications': newCount};
  }
}
