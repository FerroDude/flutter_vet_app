import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_plus/models/clinic_models.dart';
import 'package:vet_plus/services/clinic_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ClinicService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ClinicService(firestore: firestore);
  });

  group('Profile update persistence', () {
    test('updateUserProfile persists displayName, phone and address', () async {
      final original = UserProfile(
        id: 'owner_1',
        email: 'owner@test.com',
        displayName: 'Old Name',
        userType: UserType.petOwner,
        phone: '111111111',
        address: 'Old Street',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await firestore.collection('users').doc('owner_1').set(original.toJson());

      final updated = original.copyWith(
        displayName: 'New Name',
        phone: '999999999',
        address: 'New Street',
        updatedAt: DateTime(2026, 2, 1),
      );

      await service.updateUserProfile(updated);

      final doc = await firestore.collection('users').doc('owner_1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['displayName'], equals('New Name'));
      expect(doc.data()!['phone'], equals('999999999'));
      expect(doc.data()!['address'], equals('New Street'));
    });
  });
}
