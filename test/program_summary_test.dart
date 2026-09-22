import 'package:flutter_test/flutter_test.dart';
import 'package:vita_patient/core/network/patient_contract.dart';
import 'package:vita_patient/features/patient/domain/models.dart';
import 'package:vita_patient/features/program/domain/program_summary.dart';
import 'exercise_repository_test.dart' show fixture;

AssignedExercise item(
  String id, {
  Map<String, dynamic>? execution,
  String status = 'ACTIVE',
  Map<String, dynamic> extra = const {},
}) => AssignedExercise.fromJson({
  ...fixture(id, 0),
  'status': status,
  'execution': execution,
  ...extra,
}, PatientContract({}));

Map<String, dynamic> completedOn(DateTime day) => {
  'status': 'COMPLETED',
  'completedAt': day.toUtc().toIso8601String(),
};

void main() {
  final now = DateTime(2026, 9, 22, 18);

  test('counts only non-cancelled work and resumes in-progress first', () {
    final summary = ProgramSummary.of([
      item('done', execution: completedOn(now)),
      item('fresh'),
      item('running', execution: {'status': 'IN_PROGRESS'}),
      item('gone', status: 'CANCELLED'),
    ], now);
    expect(summary.total, 3);
    expect(summary.finished, 1);
    expect(summary.started, isTrue);
    expect(summary.complete, isFalse);
    expect(summary.next?.id, 'running');
  });

  test('a finished program has no next exercise', () {
    final summary = ProgramSummary.of([
      item('a', execution: completedOn(now)),
      item('b', execution: {'status': 'SKIPPED'}),
    ], now);
    expect(summary.complete, isTrue);
    expect(summary.next, isNull);
    expect(summary.remainingMinutes, 0);
  });

  test('streak counts consecutive days and survives an unfinished today', () {
    DateTime daysAgo(int days) => now.subtract(Duration(days: days));
    final summary = ProgramSummary.of([
      item('a', execution: completedOn(daysAgo(1))),
      item('b', execution: completedOn(daysAgo(2))),
      item('c', execution: completedOn(daysAgo(4))),
      // Skips never count toward adherence.
      item(
        'd',
        execution: {
          'status': 'SKIPPED',
          'skippedAt': daysAgo(3).toUtc().toIso8601String(),
        },
      ),
    ], now);
    expect(summary.streak, 2);
    expect(summary.week.length, 7);
    expect(summary.week.values.toList(), [
      false, false, true, false, true, true, false, //
    ]);
    expect(summary.week.keys.last, DateTime(2026, 9, 22));
  });

  test('time estimate follows reps, holds, sets and rests', () {
    // Fixture: 3 sets × 10 reps, hold 5s, rest 20s → 3·50 + 2·20.
    expect(ProgramSummary.estimateSeconds(item('reps')), 190);
    final timed = item('timed', extra: {'reps': null, 'sets': 2});
    // 2 sets × 60s duration + 1 rest of 20s.
    expect(ProgramSummary.estimateSeconds(timed), 140);
    expect(ProgramSummary.of([item('reps'), timed], now).remainingMinutes, 6);
    expect(ProgramSummary.of([item('reps'), timed], now).displayMinutes, 6);
    // Seed-style prescriptions (100 × 99) must not surface as "5000 minutes".
    final absurd = item('absurd', extra: {'sets': 100, 'reps': 99});
    expect(ProgramSummary.of([absurd], now).displayMinutes, isNull);
  });

  test('observed execution schema: timing fields and skip detection', () {
    final done = item(
      'done',
      execution: {
        'id': 'e1',
        'assignmentId': 'done',
        'startedAt': '2026-09-21T09:00:00.000Z',
        'completedAt': '2026-09-21T09:04:10.000Z',
        'elapsedSeconds': 250,
        'status': 'COMPLETED',
        'skipReasonId': null,
        'skipReasonText': null,
        'completionNote': null,
      },
    );
    expect(done.startedAt, DateTime.utc(2026, 9, 21, 9));
    expect(done.elapsedSeconds, 250);
    expect(done.done && !done.skipped, isTrue);

    final skipped = item(
      'skipped',
      execution: {'status': 'UNDOCUMENTED', 'skipReasonId': 'r1'},
    );
    expect(skipped.skipped, isTrue);
    expect(skipped.done, isTrue);
    expect(skipped.allows('complete'), isFalse);
  });

  test('a completion stamped after the device date counts as today', () {
    // Device clock two days behind the server, as seen on the emulator.
    final summary = ProgramSummary.of([
      item('a', execution: completedOn(now.add(const Duration(days: 2)))),
    ], now);
    expect(summary.week.values.last, isTrue);
    expect(summary.streak, 1);
  });

  test('all-exercises response keeps the owning session', () {
    final exercise = item(
      'x',
      extra: {
        'erpSessionId': 'session-7',
        'session': {'id': 'session-7', 'sessionNumber': 7},
      },
    );
    expect(exercise.sessionId, 'session-7');
    expect(exercise.sessionNumber, 7);
  });
}
