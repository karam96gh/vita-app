import 'package:flutter_test/flutter_test.dart';
import 'package:vita_patient/core/errors/api_failure.dart';
import 'package:vita_patient/core/network/patient_contract.dart';
import 'package:vita_patient/features/patient/domain/models.dart';

void main() {
  test('skip reasons decode the observed list without a schema', () {
    final reasons = SkipReason.listFrom([
      {
        'id': 'b',
        'nameAr': 'ألم',
        'nameEn': 'Pain',
        'sortOrder': 2,
        'active': true,
      },
      {
        'id': 'a',
        'nameAr': 'ضيق وقت',
        'nameEn': 'No time',
        'sortOrder': 1,
        'active': true,
      },
      {'id': 'x', 'nameAr': 'قديم', 'nameEn': null, 'active': false},
    ], PatientContract({}));
    expect(reasons.map((r) => r.id), ['a', 'b']);
    expect(reasons.first.localizedLabel('ar'), 'ضيق وقت');
    expect(reasons.first.localizedLabel('en'), 'No time');
    // No "Other" marker exists in the response; nothing is inferred from labels.
    expect(reasons.every((r) => !r.isOther), isTrue);
  });

  test('requiresText marks the Other reason', () {
    final reasons = SkipReason.listFrom([
      {'id': 'a', 'nameAr': 'ألم', 'requiresText': false},
      {'id': 'o', 'nameAr': 'أخرى', 'requiresText': true},
      {'id': 'b', 'nameAr': 'ضيق وقت'},
    ], PatientContract({}));
    expect(reasons.map((r) => r.isOther), [false, true, false]);
    expect(
      () => SkipReason.listFrom([
        {'id': 'x', 'nameAr': 'x', 'requiresText': 'yes'},
      ], PatientContract({})),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('daily completions decode and reject malformed days', () {
    final days = DailyCompletion.listFrom([
      {'date': '2026-09-22', 'completed': 5},
      {'date': '2026-09-21', 'completed': 0},
    ]);
    expect(days.map((d) => d.date), [
      DateTime(2026, 9, 21),
      DateTime(2026, 9, 22),
    ]);
    expect(days.last.completed, 5);
    for (final bad in [
      {'items': []},
      [
        {'date': 'yesterday', 'completed': 1},
      ],
      [
        {'date': '2026-09-22', 'completed': -1},
      ],
    ]) {
      expect(() => DailyCompletion.listFrom(bad), throwsA(isA<ApiFailure>()));
    }
  });

  test('error details reach the caller', () {
    try {
      ApiResponseParser.parse({
        'success': false,
        'code': 'EXERCISE_DURATION_NOT_ELAPSED',
        'requiredSeconds': 90,
        'elapsedSeconds': 40,
      });
      fail('expected a failure');
    } on ApiFailure catch (error) {
      expect(error.code, 'EXERCISE_DURATION_NOT_ELAPSED');
      expect(error.intDetail('requiredSeconds'), 90);
      expect(error.intDetail('elapsedSeconds'), 40);
      expect(error.intDetail('missing'), isNull);
    }
  });

  test('a mapped Other flag is honoured', () {
    final reasons = SkipReason.listFrom([
      {'id': 'o', 'nameAr': 'أخرى', 'isOther': true},
    ], PatientContract({'skipReason.isOther': '/isOther'}));
    expect(reasons.single.isOther, isTrue);
  });

  test('chat messages decode the confirmed shape', () {
    final mine = ChatMessage.fromJson({
      'id': 'm1',
      'messageText': 'مرحبا',
      'sentAt': '2026-09-22T10:00:00.000Z',
      'senderType': 'PATIENT',
      'senderId': 'p1',
    });
    expect(
      [mine.id, mine.text, mine.at, mine.mine],
      ['m1', 'مرحبا', DateTime.utc(2026, 9, 22, 10), true],
    );
    final theirs = ChatMessage.fromJson({
      'id': 'm2',
      'messageText': 'أهلاً',
      'sentAt': '2026-09-22T10:01:00.000Z',
      'senderType': 'THERAPIST',
    });
    expect(theirs.mine, isFalse);
    for (final bad in [
      {'id': 'x', 'messageText': 't', 'sentAt': '2026-09-22T10:00:00Z'},
      {
        'id': 'x',
        'messageText': 't',
        'sentAt': '2026-09-22T10:00:00Z',
        'senderType': 'ADMIN',
      },
    ]) {
      expect(
        () => ChatMessage.fromJson(bad),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
        ),
      );
    }
  });

  test('malformed skip reasons fail explicitly', () {
    for (final value in [
      {'items': []},
      [
        {'nameAr': 'no id'},
      ],
      [
        {'id': 'a', 'nameAr': 'x', 'sortOrder': '1'},
      ],
    ]) {
      expect(
        () => SkipReason.listFrom(value, PatientContract({})),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
        ),
      );
    }
  });
}
