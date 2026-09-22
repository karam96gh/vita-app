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

  test('a mapped Other flag is honoured', () {
    final reasons = SkipReason.listFrom([
      {'id': 'o', 'nameAr': 'أخرى', 'isOther': true},
    ], PatientContract({'skipReason.isOther': '/isOther'}));
    expect(reasons.single.isOther, isTrue);
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
