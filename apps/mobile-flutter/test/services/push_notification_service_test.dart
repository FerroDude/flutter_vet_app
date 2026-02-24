import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_plus/services/push_notification_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PushNotificationService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = PushNotificationService.test(firestore: firestore);
  });

  group('PushNotificationService', () {
    test(
      'hasNotificationsEnabled returns false when user is missing',
      () async {
        final enabled = await service.hasNotificationsEnabled('missing_user');
        expect(enabled, isFalse);
      },
    );

    test('hasNotificationsEnabled returns true when token exists', () async {
      await firestore.collection('users').doc('user_1').set({
        'fcmToken': 'token_abc',
      });

      final enabled = await service.hasNotificationsEnabled('user_1');
      expect(enabled, isTrue);
    });

    test('hasNotificationsEnabled returns false when token is empty', () async {
      await firestore.collection('users').doc('user_1').set({'fcmToken': ''});

      final enabled = await service.hasNotificationsEnabled('user_1');
      expect(enabled, isFalse);
    });

    test('saveTokenForUser writes token and updated timestamp', () async {
      await firestore.collection('users').doc('user_1').set({
        'name': 'Test User',
      });
      service.setCurrentTokenForTesting('token_xyz');

      await service.saveTokenForUser('user_1');

      final userDoc = await firestore.collection('users').doc('user_1').get();
      expect(userDoc.data()!['fcmToken'], equals('token_xyz'));
      expect(userDoc.data()!['fcmTokenUpdatedAt'], isNotNull);
    });

    test('clearTokenForUser removes token fields', () async {
      await firestore.collection('users').doc('user_1').set({
        'fcmToken': 'token_xyz',
        'fcmTokenUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await service.clearTokenForUser('user_1');

      final userDoc = await firestore.collection('users').doc('user_1').get();
      expect(userDoc.data()!.containsKey('fcmToken'), isFalse);
      expect(userDoc.data()!.containsKey('fcmTokenUpdatedAt'), isFalse);
    });

    test('disableNotifications returns true and clears token', () async {
      await firestore.collection('users').doc('user_1').set({
        'fcmToken': 'token_xyz',
        'fcmTokenUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      final ok = await service.disableNotifications('user_1');
      final userDoc = await firestore.collection('users').doc('user_1').get();

      expect(ok, isTrue);
      expect(userDoc.data()!.containsKey('fcmToken'), isFalse);
    });
  });
}
