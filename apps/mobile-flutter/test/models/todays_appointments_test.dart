import 'package:flutter_test/flutter_test.dart';
import 'package:vet_plus/models/appointment_request_model.dart';

AppointmentRequest _make({
  required AppointmentRequestStatus status,
  required DateTime preferredDateStart,
  required DateTime preferredDateEnd,
}) {
  return AppointmentRequest(
    id: 'req_${preferredDateStart.millisecondsSinceEpoch}',
    clinicId: 'clinic_1',
    petOwnerId: 'owner_1',
    petOwnerName: 'Test Owner',
    petId: 'pet_1',
    petName: 'Luna',
    preferredDateStart: preferredDateStart,
    preferredDateEnd: preferredDateEnd,
    timePreference: TimePreference.morning,
    reason: 'Checkup',
    status: status,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final jan31 = DateTime(2026, 1, 31);

  group('todaysConfirmedAppointments', () {
    test('returns only confirmed appointments', () {
      final requests = [
        _make(
          status: AppointmentRequestStatus.confirmed,
          preferredDateStart: DateTime(2026, 1, 31, 9),
          preferredDateEnd: DateTime(2026, 1, 31, 17),
        ),
        _make(
          status: AppointmentRequestStatus.pending,
          preferredDateStart: DateTime(2026, 1, 31, 9),
          preferredDateEnd: DateTime(2026, 1, 31, 17),
        ),
        _make(
          status: AppointmentRequestStatus.denied,
          preferredDateStart: DateTime(2026, 1, 31, 9),
          preferredDateEnd: DateTime(2026, 1, 31, 17),
        ),
      ];

      final result = todaysConfirmedAppointments(
        requests,
        referenceDate: jan31,
      );
      expect(result.length, equals(1));
      expect(result.first.status, AppointmentRequestStatus.confirmed);
    });

    test('filters to appointments overlapping the reference day', () {
      final requests = [
        _make(
          status: AppointmentRequestStatus.confirmed,
          preferredDateStart: DateTime(2026, 1, 31, 10),
          preferredDateEnd: DateTime(2026, 1, 31, 12),
        ),
        _make(
          status: AppointmentRequestStatus.confirmed,
          preferredDateStart: DateTime(2026, 1, 30, 9),
          preferredDateEnd: DateTime(2026, 1, 30, 17),
        ),
        _make(
          status: AppointmentRequestStatus.confirmed,
          preferredDateStart: DateTime(2026, 2, 1, 9),
          preferredDateEnd: DateTime(2026, 2, 1, 17),
        ),
      ];

      final result = todaysConfirmedAppointments(
        requests,
        referenceDate: jan31,
      );
      expect(result.length, equals(1));
    });

    test('includes multi-day appointments spanning the reference day', () {
      final requests = [
        _make(
          status: AppointmentRequestStatus.confirmed,
          preferredDateStart: DateTime(2026, 1, 30),
          preferredDateEnd: DateTime(2026, 2, 2),
        ),
      ];

      final result = todaysConfirmedAppointments(
        requests,
        referenceDate: jan31,
      );
      expect(result.length, equals(1));
    });

    test(
      'excludes appointment ending exactly at midnight of reference day',
      () {
        final requests = [
          _make(
            status: AppointmentRequestStatus.confirmed,
            preferredDateStart: DateTime(2026, 1, 30, 9),
            preferredDateEnd: DateTime(2026, 1, 31, 0, 0, 0),
          ),
        ];

        final result = todaysConfirmedAppointments(
          requests,
          referenceDate: jan31,
        );
        expect(result.length, equals(0));
      },
    );

    test(
      'includes appointment starting exactly at midnight of reference day',
      () {
        final requests = [
          _make(
            status: AppointmentRequestStatus.confirmed,
            preferredDateStart: DateTime(2026, 1, 31, 0, 0, 0),
            preferredDateEnd: DateTime(2026, 1, 31, 8),
          ),
        ];

        final result = todaysConfirmedAppointments(
          requests,
          referenceDate: jan31,
        );
        expect(result.length, equals(1));
      },
    );

    test('returns empty list when no requests provided', () {
      final result = todaysConfirmedAppointments([], referenceDate: jan31);
      expect(result, isEmpty);
    });

    test('uses current date when no referenceDate is given', () {
      final now = DateTime.now();
      final requests = [
        _make(
          status: AppointmentRequestStatus.confirmed,
          preferredDateStart: DateTime(now.year, now.month, now.day, 9),
          preferredDateEnd: DateTime(now.year, now.month, now.day, 17),
        ),
      ];

      final result = todaysConfirmedAppointments(requests);
      expect(result.length, equals(1));
    });
  });
}
