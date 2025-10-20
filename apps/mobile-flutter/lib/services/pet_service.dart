import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/symptom_models.dart';

class PetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _users() =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> _symptomsCollection(
    String ownerId,
    String petId,
  ) {
    return _users()
        .doc(ownerId)
        .collection('pets')
        .doc(petId)
        .collection('symptoms');
  }

  Future<String> addSymptom({
    required String ownerId,
    required String petId,
    required SymptomType type,
    required DateTime at,
    String? note,
  }) async {
    final data = {
      'ownerId': ownerId,
      'petId': petId,
      'type': symptomTypeToKey(type),
      'timestamp': Timestamp.fromDate(at),
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final doc = await _symptomsCollection(ownerId, petId).add(data);
    return doc.id;
  }

  Stream<List<PetSymptom>> symptomsStream(
    String ownerId,
    String petId, {
    SymptomType? type,
    DateTime? start,
    DateTime? end,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> q = _symptomsCollection(
      ownerId,
      petId,
    ).orderBy('timestamp', descending: true);
    if (type != null) {
      q = q.where('type', isEqualTo: symptomTypeToKey(type));
    }
    if (start != null) {
      q = q.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }
    if (end != null) {
      q = q.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }
    q = q.limit(limit);

    return q.snapshots().map(
      (snap) => snap.docs
          .map((d) => PetSymptom.fromJson(d.data(), d.id, ownerId, petId))
          .toList(),
    );
  }

  Future<Map<DateTime, int>> symptomCountsByDay(
    String ownerId,
    String petId, {
    SymptomType? type,
    DateTime? start,
    DateTime? end,
  }) async {
    final items = await symptomsStream(
      ownerId,
      petId,
      type: type,
      start: start,
      end: end,
      limit: 1000,
    ).first;
    final Map<DateTime, int> counts = {};
    for (final s in items) {
      final day = DateTime(
        s.timestamp.year,
        s.timestamp.month,
        s.timestamp.day,
      );
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<DateTime, int>> symptomCountsByDayForUser(
    String ownerId, {
    DateTime? start,
    DateTime? end,
  }) async {
    final petsSnap = await _users().doc(ownerId).collection('pets').get();
    final Map<DateTime, int> aggregated = {};
    for (final pet in petsSnap.docs) {
      final counts = await symptomCountsByDay(
        ownerId,
        pet.id,
        start: start,
        end: end,
      );
      counts.forEach((day, count) {
        aggregated[day] = (aggregated[day] ?? 0) + count;
      });
    }
    return aggregated;
  }

  Future<Map<DateTime, List<PetSymptom>>> symptomsByDayForUser(
    String ownerId, {
    DateTime? start,
    DateTime? end,
  }) async {
    final petsSnap = await _users().doc(ownerId).collection('pets').get();
    final Map<DateTime, List<PetSymptom>> aggregated = {};

    for (final pet in petsSnap.docs) {
      final symptoms = await symptomsStream(
        ownerId,
        pet.id,
        start: start,
        end: end,
        limit: 1000,
      ).first;

      for (final symptom in symptoms) {
        final day = DateTime(
          symptom.timestamp.year,
          symptom.timestamp.month,
          symptom.timestamp.day,
        );
        final list = aggregated.putIfAbsent(day, () => []);
        list.add(symptom);
      }
    }

    for (final entry in aggregated.entries) {
      entry.value.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return aggregated;
  }

  Future<List<PetSymptom>> recentSymptomsForUser(
    String ownerId, {
    int perPetLimit = 3,
    int totalLimit = 10,
  }) async {
    final petsSnap = await _users().doc(ownerId).collection('pets').get();
    final List<PetSymptom> all = [];
    for (final pet in petsSnap.docs) {
      final q = await _symptomsCollection(
        ownerId,
        pet.id,
      ).orderBy('timestamp', descending: true).limit(perPetLimit).get();
      for (final d in q.docs) {
        all.add(PetSymptom.fromJson(d.data(), d.id, ownerId, pet.id));
      }
    }
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (all.length > totalLimit) {
      return all.sublist(0, totalLimit);
    }
    return all;
  }
}
