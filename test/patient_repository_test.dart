import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_patient/core/errors/api_failure.dart';
import 'package:vita_patient/core/network/api_client.dart';
import 'package:vita_patient/core/network/patient_contract.dart';
import 'package:vita_patient/features/patient/data/patient_repository.dart';
import 'package:vita_patient/features/patient/domain/models.dart';
import 'core/network_test.dart' show MemoryTokens, TestAdapter, pair, success;

Map<String, dynamic> notification(String id, String sentAt, {String? readAt}) =>
    {
      'id': id,
      'titleAr': 'تذكير',
      'titleEn': 'Reminder',
      'bodyAr': 'موعد تجريبي',
      'bodyEn': 'Test appointment',
      'sentAt': sentAt,
      'readAt': readAt,
    };

void main() {
  final malformed = throwsA(
    isA<ApiFailure>().having((error) => error.code, 'code', 'INVALID_RESPONSE'),
  );

  test(
    'patient sessions use bearer auth and their IDs open exercises',
    () async {
      const id = '043ce108-test';
      final paths = <String>[];
      final dio = Dio();
      dio.httpClientAdapter = TestAdapter((request) async {
        paths.add(request.path);
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer old-access');
        return success(
          request.path == '/me/sessions'
              ? [
                  {
                    'id': id,
                    'caseId': 'e2acfb95-test',
                    'sessionNumber': 1,
                    'sessionDate': '2001-09-03T00:00:00.000Z',
                    'attendanceConfirmed': false,
                    'physiotherapistId': null,
                    'appointmentId': null,
                  },
                ]
              : [],
        );
      });
      final api = ApiClient(baseUrl: '', store: MemoryTokens(), transport: dio)
        ..tokens = pair();
      addTearDown(api.dispose);
      final repository = PatientRepository(
        api,
        PatientContract({'exercises.items': ''}),
      );
      final sessions = await repository.sessions();
      expect(sessions.single.id, id);
      expect(sessions.single.number, 1);
      expect(sessions.single.date, DateTime.utc(2001, 9, 3));
      expect(sessions.single.attendanceConfirmed, isFalse);
      expect(sessions.single.alreadyRated, isNull);
      expect(await repository.exercises(sessions.single.id), isEmpty);
      expect(paths, ['/me/sessions', '/me/sessions/$id/exercises']);
    },
  );

  test('session list handles empty and malformed responses', () async {
    Object? response = [];
    final dio = Dio();
    dio.httpClientAdapter = TestAdapter((_) async => success(response));
    final api = ApiClient(baseUrl: '', store: MemoryTokens(), transport: dio)
      ..tokens = pair();
    addTearDown(api.dispose);
    final repository = PatientRepository(api, PatientContract({}));
    expect(await repository.sessions(), isEmpty);
    for (final value in [
      null,
      {},
      [null],
      [
        {'id': 'session'},
      ],
      [
        {
          'id': 'session',
          'sessionNumber': 1,
          'sessionDate': 'invalid',
          'attendanceConfirmed': true,
        },
      ],
    ]) {
      response = value;
      await expectLater(repository.sessions(), malformed);
    }
  });

  test(
    'confirmed endpoints decode without optional schema configuration',
    () async {
      final fixtures = <String, Object>{
        '/me/profile': {
          'username': 'test-account',
          'erpPatient': {
            'firstName': ' Test ',
            'lastName': ' Patient ',
            'phone': null,
            'idNumber': 'not used in profile',
          },
        },
        '/me/notifications': [
          notification('older', '2026-09-14T10:00:00Z'),
          notification(
            'newer',
            '2026-09-15T10:00:00Z',
            readAt: '2026-09-15T11:00:00Z',
          ),
        ],
      };
      final dio = Dio();
      dio.httpClientAdapter = TestAdapter((request) async {
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer old-access');
        return success(fixtures[request.path]);
      });
      final api = ApiClient(baseUrl: '', store: MemoryTokens(), transport: dio)
        ..tokens = pair();
      addTearDown(api.dispose);
      final repository = PatientRepository(api, PatientContract({}));
      final profile = await repository.profile();
      expect(profile.name, 'Test Patient');
      expect(profile.phone, isNull);
      final notifications = await repository.notifications();
      expect(notifications.map((item) => item.id), ['newer', 'older']);
      expect(notifications.first.read, isTrue);
      expect(notifications.last.read, isFalse);
      expect(notifications.first.localizedTitle('en'), 'Reminder');
      expect(notifications.first.localizedTitle('ar'), 'تذكير');
      expect(notifications.first.localizedBody('en'), 'Test appointment');
    },
  );

  test('malformed patient and counters do not become fabricated data', () {
    for (final value in [
      null,
      {},
      {'erpPatient': null},
      {
        'erpPatient': {'firstName': 7, 'lastName': 'Patient'},
      },
    ]) {
      expect(() => PatientProfile.fromJson(value), malformed);
    }
  });

  test('notifications require explicit read state and valid dates', () {
    final unread = notification('1', '2026-09-15T10:00:00Z');
    expect(PatientNotification.fromJson(unread).read, isFalse);
    expect(
      () => PatientNotification.fromJson({...unread}..remove('readAt')),
      malformed,
    );
    expect(
      () => PatientNotification.fromJson({...unread, 'readAt': true}),
      malformed,
    );
    expect(
      () => PatientNotification.fromJson({...unread, 'readAt': 'invalid'}),
      malformed,
    );
    expect(
      () => PatientNotification.fromJson({...unread, 'sentAt': 'invalid'}),
      malformed,
    );
    final fallback = PatientNotification.fromJson({
      ...unread,
      'titleEn': null,
      'bodyEn': '',
    });
    expect(fallback.localizedTitle('en'), 'تذكير');
    expect(fallback.localizedBody('en'), 'موعد تجريبي');
  });
}
