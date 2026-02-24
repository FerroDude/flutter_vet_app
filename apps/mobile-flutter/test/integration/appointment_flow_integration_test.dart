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

  Future<String> createPendingRequest({
    String clinicId = 'clinic_1',
    String petOwnerId = 'owner_1',
    String petOwnerName = 'Pedro',
    String petId = 'pet_1',
    String petName = 'Luna',
  }) {
    return service.createRequest(
      clinicId: clinicId,
      petOwnerId: petOwnerId,
      petOwnerName: petOwnerName,
      petId: petId,
      petName: petName,
      petSpecies: 'Dog',
      preferredDateStart: DateTime(2026, 2, 1),
      preferredDateEnd: DateTime(2026, 2, 3),
      timePreference: TimePreference.afternoon,
      reason: 'Annual checkup',
      notes: 'Needs vaccine update',
    );
  }

  group('Appointment Flow Integration', () {
    test('pet owner create -> receptionist confirm -> link chat', () async {
      final requestId = await createPendingRequest();

      // Pet owner sees the newly created pending request.
      final myRequestsBefore = await service
          .petOwnerRequestsStream('owner_1')
          .first;
      expect(myRequestsBefore.length, 1);
      expect(myRequestsBefore.first.id, requestId);
      expect(myRequestsBefore.first.status, AppointmentRequestStatus.pending);

      // Receptionist confirms request.
      await service.confirmRequest(
        requestId: requestId,
        handledBy: 'rec_1',
        handledByName: 'Reception User',
        message: 'Confirmed for Monday 10:00',
      );

      // Receptionist links chat room from appointment actions.
      await service.linkChatRoom(
        requestId: requestId,
        chatRoomId: 'chat_room_123',
      );

      final request = await service.getRequest(requestId);
      expect(request, isNotNull);
      expect(request!.status, AppointmentRequestStatus.confirmed);
      expect(request.handledBy, 'rec_1');
      expect(request.handledByName, 'Reception User');
      expect(request.responseMessage, 'Confirmed for Monday 10:00');
      expect(request.linkedChatRoomId, 'chat_room_123');

      // Confirmed request still appears in owner and clinic "all" feeds.
      final ownerRequestsAfter = await service
          .petOwnerRequestsStream('owner_1')
          .first;
      expect(ownerRequestsAfter.length, 1);
      expect(
        ownerRequestsAfter.first.status,
        AppointmentRequestStatus.confirmed,
      );

      final clinicAll = await service.clinicAllRequestsStream('clinic_1').first;
      expect(clinicAll.length, 1);
      expect(clinicAll.first.status, AppointmentRequestStatus.confirmed);
    });

    test('pet owner create -> receptionist deny -> cancel is blocked', () async {
      final requestId = await createPendingRequest(
        petOwnerId: 'owner_2',
        petOwnerName: 'Ana',
        petId: 'pet_2',
        petName: 'Max',
      );

      await service.denyRequest(
        requestId: requestId,
        handledBy: 'rec_2',
        handledByName: 'Reception Two',
        message: 'No availability this week',
      );

      final denied = await service.getRequest(requestId);
      expect(denied, isNotNull);
      expect(denied!.status, AppointmentRequestStatus.denied);
      expect(denied.responseMessage, 'No availability this week');

      // Only pending requests can be cancelled; denied requests must fail cancel.
      await expectLater(service.cancelRequest(requestId), throwsException);
    });

    test(
      'pet owner create -> pet owner cancel deletes request from feeds',
      () async {
        final requestId = await createPendingRequest(
          petOwnerId: 'owner_3',
          petOwnerName: 'Chris',
          petId: 'pet_3',
          petName: 'Kiko',
        );

        await service.cancelRequest(requestId);

        final deleted = await service.getRequest(requestId);
        expect(deleted, isNull);

        final ownerRequests = await service
            .petOwnerRequestsStream('owner_3')
            .first;
        expect(ownerRequests, isEmpty);

        final clinicPending = await service
            .clinicPendingRequestsStream('clinic_1')
            .first;
        expect(clinicPending.where((r) => r.id == requestId).isEmpty, isTrue);
      },
    );
  });
}
