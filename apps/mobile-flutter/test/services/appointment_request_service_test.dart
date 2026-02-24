import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_plus/models/appointment_request_model.dart';
import 'package:vet_plus/services/appointment_request_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AppointmentRequestService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = AppointmentRequestService(firestore: firestore);
  });

  group('AppointmentRequestService', () {
    test('createRequest stores request with pending status', () async {
      final requestId = await service.createRequest(
        clinicId: 'clinic_1',
        petOwnerId: 'owner_1',
        petOwnerName: 'Pedro',
        petId: 'pet_1',
        petName: 'Luna',
        petSpecies: 'Dog',
        preferredDateStart: DateTime(2026, 2, 1),
        preferredDateEnd: DateTime(2026, 2, 3),
        timePreference: TimePreference.morning,
        reason: 'Checkup',
        notes: 'Needs vaccine review',
      );

      final doc = await firestore
          .collection('appointmentRequests')
          .doc(requestId)
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()!['clinicId'], equals('clinic_1'));
      expect(doc.data()!['petOwnerId'], equals('owner_1'));
      expect(
        doc.data()!['status'],
        equals(AppointmentRequestStatus.pending.index),
      );
    });

    test('hasPendingRequest returns true only for pending requests', () async {
      await firestore.collection('appointmentRequests').add({
        'clinicId': 'clinic_1',
        'petOwnerId': 'owner_1',
        'petOwnerName': 'Pedro',
        'petId': 'pet_1',
        'petName': 'Luna',
        'petSpecies': 'Dog',
        'preferredDateStart': DateTime(2026, 2, 1).millisecondsSinceEpoch,
        'preferredDateEnd': DateTime(2026, 2, 3).millisecondsSinceEpoch,
        'timePreference': TimePreference.anyTime.index,
        'reason': 'Checkup',
        'notes': null,
        'status': AppointmentRequestStatus.pending.index,
        'handledBy': null,
        'handledByName': null,
        'handledAt': null,
        'responseMessage': null,
        'linkedChatRoomId': null,
        'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'updatedAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      });

      await firestore.collection('appointmentRequests').add({
        'clinicId': 'clinic_1',
        'petOwnerId': 'owner_2',
        'petOwnerName': 'Ana',
        'petId': 'pet_2',
        'petName': 'Max',
        'petSpecies': 'Cat',
        'preferredDateStart': DateTime(2026, 2, 1).millisecondsSinceEpoch,
        'preferredDateEnd': DateTime(2026, 2, 3).millisecondsSinceEpoch,
        'timePreference': TimePreference.anyTime.index,
        'reason': 'Checkup',
        'notes': null,
        'status': AppointmentRequestStatus.confirmed.index,
        'handledBy': 'rec_1',
        'handledByName': 'Reception',
        'handledAt': DateTime(2026, 1, 2).millisecondsSinceEpoch,
        'responseMessage': 'Confirmed',
        'linkedChatRoomId': null,
        'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'updatedAt': DateTime(2026, 1, 2).millisecondsSinceEpoch,
      });

      final hasPending = await service.hasPendingRequest(
        clinicId: 'clinic_1',
        petOwnerId: 'owner_1',
      );
      final hasPendingForConfirmedOnly = await service.hasPendingRequest(
        clinicId: 'clinic_1',
        petOwnerId: 'owner_2',
      );

      expect(hasPending, isTrue);
      expect(hasPendingForConfirmedOnly, isFalse);
    });

    test('cancelRequest deletes a pending request document', () async {
      final docRef = await firestore.collection('appointmentRequests').add({
        'clinicId': 'clinic_1',
        'petOwnerId': 'owner_1',
        'petOwnerName': 'Pedro',
        'petId': 'pet_1',
        'petName': 'Luna',
        'petSpecies': 'Dog',
        'preferredDateStart': DateTime(2026, 2, 1).millisecondsSinceEpoch,
        'preferredDateEnd': DateTime(2026, 2, 3).millisecondsSinceEpoch,
        'timePreference': TimePreference.anyTime.index,
        'reason': 'Checkup',
        'notes': null,
        'status': AppointmentRequestStatus.pending.index,
        'handledBy': null,
        'handledByName': null,
        'handledAt': null,
        'responseMessage': null,
        'linkedChatRoomId': null,
        'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'updatedAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      });

      await service.cancelRequest(docRef.id);

      final docAfterCancel = await firestore
          .collection('appointmentRequests')
          .doc(docRef.id)
          .get();
      expect(docAfterCancel.exists, isFalse);
    });

    test('cancelRequest throws when request is not pending', () async {
      final docRef = await firestore.collection('appointmentRequests').add({
        'clinicId': 'clinic_1',
        'petOwnerId': 'owner_1',
        'petOwnerName': 'Pedro',
        'petId': 'pet_1',
        'petName': 'Luna',
        'petSpecies': 'Dog',
        'preferredDateStart': DateTime(2026, 2, 1).millisecondsSinceEpoch,
        'preferredDateEnd': DateTime(2026, 2, 3).millisecondsSinceEpoch,
        'timePreference': TimePreference.anyTime.index,
        'reason': 'Checkup',
        'notes': null,
        'status': AppointmentRequestStatus.confirmed.index,
        'handledBy': 'rec_1',
        'handledByName': 'Reception',
        'handledAt': DateTime(2026, 1, 2).millisecondsSinceEpoch,
        'responseMessage': 'Confirmed',
        'linkedChatRoomId': null,
        'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'updatedAt': DateTime(2026, 1, 2).millisecondsSinceEpoch,
      });

      await expectLater(service.cancelRequest(docRef.id), throwsException);
    });

    test('petOwnerRequestsStream filters out cancelled requests', () async {
      await firestore.collection('appointmentRequests').add({
        'clinicId': 'clinic_1',
        'petOwnerId': 'owner_1',
        'petOwnerName': 'Pedro',
        'petId': 'pet_1',
        'petName': 'Luna',
        'petSpecies': 'Dog',
        'preferredDateStart': DateTime(2026, 2, 1).millisecondsSinceEpoch,
        'preferredDateEnd': DateTime(2026, 2, 3).millisecondsSinceEpoch,
        'timePreference': TimePreference.anyTime.index,
        'reason': 'Checkup',
        'notes': null,
        'status': AppointmentRequestStatus.pending.index,
        'handledBy': null,
        'handledByName': null,
        'handledAt': null,
        'responseMessage': null,
        'linkedChatRoomId': null,
        'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'updatedAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      });

      await firestore.collection('appointmentRequests').add({
        'clinicId': 'clinic_1',
        'petOwnerId': 'owner_1',
        'petOwnerName': 'Pedro',
        'petId': 'pet_2',
        'petName': 'Max',
        'petSpecies': 'Cat',
        'preferredDateStart': DateTime(2026, 2, 2).millisecondsSinceEpoch,
        'preferredDateEnd': DateTime(2026, 2, 4).millisecondsSinceEpoch,
        'timePreference': TimePreference.anyTime.index,
        'reason': 'Follow-up',
        'notes': null,
        'status': AppointmentRequestStatus.cancelled.index,
        'handledBy': null,
        'handledByName': null,
        'handledAt': null,
        'responseMessage': null,
        'linkedChatRoomId': null,
        'createdAt': DateTime(2026, 1, 2).millisecondsSinceEpoch,
        'updatedAt': DateTime(2026, 1, 2).millisecondsSinceEpoch,
      });

      final items = await service.petOwnerRequestsStream('owner_1').first;
      expect(items.length, equals(1));
      expect(items.first.status, equals(AppointmentRequestStatus.pending));
    });
  });
}
