import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_patient/app/localization/app_strings.dart';
import 'package:flutter/widgets.dart';
import 'package:vita_patient/core/errors/api_failure.dart';
import 'package:vita_patient/core/network/patient_contract.dart';
import 'package:vita_patient/core/services/polling_loop.dart';
import 'package:vita_patient/features/patient/domain/models.dart';

void main() {
  test('Other requires text and skip always requires a reason', () {
    expect(Validation.skip(null, ''), 'SKIP_REASON_REQUIRED');
    expect(
      Validation.skip(const SkipReason('1', 'Other', true), '  '),
      'SKIP_REASON_TEXT_REQUIRED',
    );
    expect(
      Validation.skip(const SkipReason('1', 'Other', true), 'Reason'),
      isNull,
    );
    expect(
      Validation.skip(const SkipReason('2', 'Unavailable', false), ''),
      isNull,
    );
  });
  test('rating requires completion and an integer in the permitted range', () {
    for (final score in [-1, 0, 6, 100]) {
      expect(Validation.rating(score, true), isFalse);
    }
    expect(Validation.rating(5, false), isFalse);
    for (var score = 1; score <= 5; score++) {
      expect(Validation.rating(score, true), isTrue);
    }
  });
  test('cancelled assignment overrides all action permissions', () {
    final contract = PatientContract({
      'exercise.id': '/id',
      'exercise.name': '/name',
      'exercise.assignmentStatus': '/status',
      'exercise.canStart': '/allowed',
      'exercise.canComplete': '/allowed',
      'exercise.canSkip': '/allowed',
    });
    final exercise = AssignedExercise({
      'id': 'a',
      'name': 'Example',
      'status': 'CANCELLED',
      'allowed': true,
    }, contract);
    for (final action in ['start', 'complete', 'skip']) {
      expect(exercise.allows(action), isFalse);
    }
  });
  test('unconfirmed contract fields fail instead of guessing', () {
    expect(
      () => PatientContract({}).text({'name': 'Patient'}, 'profile.name'),
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'code', 'CONTRACT_REQUIRED'),
      ),
    );
  });
  test(
    'error mapper never displays raw exceptions or server message bodies',
    () {
      const strings = AppStrings(Locale('ar'));
      expect(
        strings.error(Exception('sensitive')),
        isNot(contains('sensitive')),
      );
      expect(
        strings.error(const ApiFailure('NO_RESPONSIBLE_THERAPIST')),
        'لا يوجد معالج مسؤول عنك حالياً',
      );
    },
  );
  testWidgets('polling never overlaps and stops while invisible', (
    tester,
  ) async {
    var calls = 0;
    final gate = Completer<void>();
    final loop = PollingLoop(() async {
      calls++;
      await gate.future;
    }, interval: const Duration(seconds: 4));
    loop.start();
    await tester.pump(const Duration(seconds: 4));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 20));
    expect(calls, 1);
    loop.stop();
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(calls, 1);
    loop.start();
    await tester.pump(const Duration(seconds: 4));
    expect(calls, 2);
    loop.dispose();
    await tester.pump(const Duration(seconds: 20));
    expect(calls, 2);
  });
}
