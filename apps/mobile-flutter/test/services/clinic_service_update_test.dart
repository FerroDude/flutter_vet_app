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

  group('ClinicService.updateClinic', () {
    test('updates clinic document with new values', () async {
      final original = Clinic(
        id: 'clinic_1',
        name: 'Old Clinic',
        address: 'Old Address',
        phone: '111111111',
        email: 'old@clinic.com',
        adminId: 'admin_1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await firestore
          .collection('clinics')
          .doc('clinic_1')
          .set(original.toJson());

      final updated = original.copyWith(
        name: 'New Clinic',
        address: 'New Address',
        phone: '222222222',
        email: 'new@clinic.com',
        website: 'https://clinic.example',
        description: 'Updated clinic profile',
        businessHours: {'mon': '09:00-18:00'},
        updatedAt: DateTime(2026, 2, 1),
      );

      await service.updateClinic('clinic_1', updated);

      final doc = await firestore.collection('clinics').doc('clinic_1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['name'], equals('New Clinic'));
      expect(doc.data()!['address'], equals('New Address'));
      expect(doc.data()!['phone'], equals('222222222'));
      expect(doc.data()!['email'], equals('new@clinic.com'));
      expect(doc.data()!['website'], equals('https://clinic.example'));
      expect(doc.data()!['description'], equals('Updated clinic profile'));
      expect(doc.data()!['businessHours'], equals({'mon': '09:00-18:00'}));
    });

    test('throws when trying to update missing clinic', () async {
      final clinic = Clinic(
        id: 'missing',
        name: 'Missing Clinic',
        address: 'Nowhere',
        phone: '000000000',
        email: 'missing@clinic.com',
        adminId: 'admin_1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await expectLater(
        service.updateClinic('missing', clinic),
        throwsException,
      );
    });
  });
}
