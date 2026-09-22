import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_patient/core/errors/api_failure.dart';
import 'package:vita_patient/core/network/api_client.dart';
import 'package:vita_patient/core/network/patient_contract.dart';
import 'package:vita_patient/features/patient/data/patient_repository.dart';
import 'package:vita_patient/features/patient/domain/models.dart';
import 'core/network_test.dart' show MemoryTokens, TestAdapter, pair, success;

Map<String, dynamic> fixture(String id, int order) => {
  'id': id,
  'status': 'ACTIVE',
  'sortOrder': order,
  'durationSeconds': 60,
  'sets': 3,
  'reps': 10,
  'holdSeconds': 5,
  'restSeconds': 20,
  'customInstructionAr': 'Custom AR',
  'customInstructionEn': 'Custom EN',
  'frequencyTextAr': 'Frequency AR',
  'frequencyTextEn': 'Frequency EN',
  'execution': null,
  'exercise': {
    'id': 'catalog-id',
    'nameAr': 'Name AR',
    'nameEn': 'Name EN',
    'descriptionAr': 'Description AR',
    'descriptionEn': 'Description EN',
    'executionMethodAr': 'Method AR',
    'executionMethodEn': 'Method EN',
    'warningsAr': 'Warnings AR',
    'warningsEn': 'Warnings EN',
    'commonMistakesAr': 'Mistakes AR',
    'commonMistakesEn': 'Mistakes EN',
    'mediaType': 'VIDEO',
    'mediaUrl': '/media/example.mp4',
  },
};

void main() {
  test(
    'confirmed nested response works without schema and preserves assignment ID',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = TestAdapter((request) async {
        expect(request.path, '/me/sessions/session/exercises');
        expect(request.headers['Authorization'], 'Bearer old-access');
        return success([fixture('second', 2), fixture('first', 1)]);
      });
      final api = ApiClient(baseUrl: '', store: MemoryTokens(), transport: dio)
        ..tokens = pair();
      addTearDown(api.dispose);
      final items = await PatientRepository(
        api,
        PatientContract({}),
      ).exercises('session');
      expect(items.map((e) => e.id), ['first', 'second']);
      final item = items.first;
      expect(item.localized(item.name, item.nameEn, 'en'), 'Name EN');
      expect(
        item.localized(item.instructions, item.instructionsEn, 'ar'),
        'Custom AR',
      );
      expect(item.localized('Fallback', '', 'en'), 'Fallback');
      expect(item.method, 'Method AR');
      expect(item.warnings, 'Warnings AR');
      expect(item.mistakes, 'Mistakes AR');
      expect(
        [
          item.durationSeconds,
          item.sets,
          item.reps,
          item.holdSeconds,
          item.restSeconds,
        ],
        [60, 3, 10, 5, 20],
      );
      expect(item.mediaType, 'VIDEO');
      expect(item.mediaUrl, '/media/example.mp4');
      // A not-yet-executed assignment can be started or skipped, not completed.
      expect(item.allows('start'), isTrue);
      expect(item.allows('skip'), isTrue);
      expect(item.allows('complete'), isFalse);
    },
  );

  test('malformed exercise fields fail explicitly', () {
    for (final value in [
      null,
      {},
      {...fixture('id', 0), 'exercise': null},
      {...fixture('id', 0), 'sets': -1},
      {...fixture('id', 0), 'reps': '10'},
    ]) {
      expect(
        () => AssignedExercise.fromJson(value, PatientContract({})),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
        ),
      );
    }
  });

  test('actions follow the execution state', () {
    AssignedExercise parse(Object? execution) => AssignedExercise.fromJson({
      ...fixture('id', 0),
      'execution': execution,
    }, PatientContract({}));
    List<bool> actions(AssignedExercise item) => [
      for (final action in ['start', 'complete', 'skip']) item.allows(action),
    ];

    final started = parse({'status': 'IN_PROGRESS'});
    expect(started.inProgress, isTrue);
    expect(actions(started), [false, true, true]);

    final completed = parse({
      'status': 'COMPLETED',
      'completedAt': '2026-09-20T10:00:00.000Z',
    });
    expect(completed.done, isTrue);
    expect(completed.finishedAt, DateTime.utc(2026, 9, 20, 10));
    expect(actions(completed), [false, false, false]);

    expect(actions(parse({'status': 'SKIPPED'})), [false, false, false]);
    expect(
      () => parse('COMPLETED'),
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
      ),
    );
  });

  test('explicit server permissions override the derived state', () {
    final item = AssignedExercise.fromJson({
      ...fixture('id', 0),
      'allowed': false,
    }, PatientContract({'exercise.canStart': '/allowed'}));
    expect(item.allows('start'), isFalse);
    expect(item.allows('skip'), isTrue);
  });

  test('cancelled exercises block even configured permissions', () {
    final value = {...fixture('id', 0), 'status': 'CANCELLED', 'allowed': true};
    final item = AssignedExercise.fromJson(
      value,
      PatientContract({
        'exercise.canStart': '/allowed',
        'exercise.canComplete': '/allowed',
        'exercise.canSkip': '/allowed',
      }),
    );
    for (final action in ['start', 'complete', 'skip']) {
      expect(item.allows(action), isFalse);
    }
  });
}
