import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_plus/pages/petOwners/profile_page.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('Profile stats streams', () {
    test('return zero when userId is empty', () async {
      expect(await petCountStream(firestore, '').first, equals(0));
      expect(await appointmentCountStream(firestore, '').first, equals(0));
      expect(await recordCountStream(firestore, '').first, equals(0));
    });

    test('petCountStream returns pet count for owner', () async {
      await firestore
          .collection('users')
          .doc('owner_1')
          .collection('pets')
          .doc('pet_1')
          .set({'name': 'Luna'});
      await firestore
          .collection('users')
          .doc('owner_1')
          .collection('pets')
          .doc('pet_2')
          .set({'name': 'Max'});

      final count = await petCountStream(firestore, 'owner_1').first;
      expect(count, equals(2));
    });

    test('appointmentCountStream filters by petOwnerId', () async {
      await firestore.collection('appointmentRequests').add({
        'petOwnerId': 'owner_1',
        'status': 0,
      });
      await firestore.collection('appointmentRequests').add({
        'petOwnerId': 'owner_1',
        'status': 1,
      });
      await firestore.collection('appointmentRequests').add({
        'petOwnerId': 'owner_2',
        'status': 0,
      });

      final count = await appointmentCountStream(firestore, 'owner_1').first;
      expect(count, equals(2));
    });

    test(
      'recordCountStream uses symptoms collectionGroup by ownerId',
      () async {
        await firestore
            .collection('users')
            .doc('owner_1')
            .collection('pets')
            .doc('pet_1')
            .collection('symptoms')
            .doc('s1')
            .set({'ownerId': 'owner_1', 'label': 'cough'});

        await firestore
            .collection('users')
            .doc('owner_1')
            .collection('pets')
            .doc('pet_2')
            .collection('symptoms')
            .doc('s2')
            .set({'ownerId': 'owner_1', 'label': 'fever'});

        await firestore
            .collection('users')
            .doc('owner_2')
            .collection('pets')
            .doc('pet_9')
            .collection('symptoms')
            .doc('s9')
            .set({'ownerId': 'owner_2', 'label': 'itching'});

        final count = await recordCountStream(firestore, 'owner_1').first;
        expect(count, equals(2));
      },
    );
  });
}
