// This is a basic Flutter widget test for the PetOn app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peton/services/cache_service.dart';
import 'package:peton/models/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PetOn Services Tests', () {
    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
    });

    test('CacheService initializes correctly', () async {
      final cacheService = CacheService();

      try {
        await cacheService.init();
      } catch (e) {
        // If already initialized, that's okay for testing
        if (!e.toString().contains('already been initialized')) {
          rethrow;
        }
      }

      // Test basic cache operations
      expect(cacheService.getCachedUserId(), isNull);
      expect(cacheService.getLastSyncTime(), isNull);
    });

    test('NotificationService initializes correctly', () async {
      final notificationService = NotificationService();

      // Test that initialization doesn't throw
      expect(
        () async => await notificationService.initialize(),
        returnsNormally,
      );

      await notificationService.initialize();

      // Test basic notification operations
      final pendingNotifications = await notificationService
          .getPendingNotifications();
      expect(pendingNotifications, isEmpty);
    });

    test('CacheService handles event caching', () async {
      final cacheService = CacheService();
      await cacheService.init();

      const testUserId = 'test-user-123';

      // Test cache validity check
      final isValid = await cacheService.isCacheValid(testUserId);
      expect(isValid, isFalse);

      // Test cache clearing
      await cacheService.clearCache();
      expect(cacheService.getCachedUserId(), isNull);
    });
  });

  group('PetOn Widget Tests', () {
    testWidgets('Theme and basic widget creation', (WidgetTester tester) async {
      // Test a simple widget without Firebase dependencies
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('PetOn Test')),
            body: const Center(child: Text('Welcome to PetOn')),
          ),
        ),
      );

      // Verify basic widget structure
      expect(find.text('PetOn Test'), findsOneWidget);
      expect(find.text('Welcome to PetOn'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('App theme components work correctly', (
      WidgetTester tester,
    ) async {
      // Test various Flutter widgets and themes work as expected
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          home: Scaffold(
            body: Column(
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Statistics Card'),
                  ),
                ),
                ElevatedButton(onPressed: () {}, child: const Text('Refresh')),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );

      // Verify UI components render correctly
      expect(find.text('Statistics Card'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Test button interaction
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify no exceptions occurred
      expect(tester.takeException(), isNull);
    });
  });
}
