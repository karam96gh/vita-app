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
      item(
        'b',
        execution: {
          'status': 'SKIPPED',
          'skipReasonId': 'r',
          'updatedAt': now.toUtc().toIso8601String(),
        },
      ),
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

  test('time estimate matches server and excludes rests', () {
    // Fixture: 3 sets × 10 reps × 5s hold. Rest is excluded.
    expect(ProgramSummary.estimateSeconds(item('reps')), 150);
    final timed = item('timed', extra: {'reps': null, 'sets': 2});
    // Duration is per set: 2 sets × 60s.
    expect(ProgramSummary.estimateSeconds(timed), 120);
    final plainReps = item(
      'plain-reps',
      extra: {'sets': null, 'reps': 10, 'holdSeconds': null},
    );
    expect(ProgramSummary.estimateSeconds(plainReps), 20);
    expect(ProgramSummary.of([item('reps'), timed], now).remainingMinutes, 5);
    expect(ProgramSummary.of([item('reps'), timed], now).displayMinutes, 5);
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

  test('progress figures exclude skips and use reported time', () {
    final items = [
      item('a', execution: {...completedOn(now), 'elapsedSeconds': 120}),
      item(
        'b',
        execution: {
          ...completedOn(now.subtract(const Duration(days: 3))),
          'elapsedSeconds': 60,
          'completionNote': 'شعرت بألم',
        },
      ),
      item('c', execution: {'status': 'SKIPPED', 'skipReasonId': 'r'}),
      item('d', execution: {'status': 'IN_PROGRESS'}),
      item('gone', status: 'CANCELLED', execution: completedOn(now)),
    ];
    final summary = ProgramSummary.of(items, now);
    // Only 'a' was completed today; 'b' three days ago is due again.
    expect(summary.doneToday, 1);
    expect(summary.inProgressCount, 1);
    expect(summary.recent.map((e) => e.id), ['a', 'b']);
    expect(summary.recent.last.completionNote, 'شعرت بألم');

    final daily = ProgramSummary.dailyCompletions(items, now);
    expect(daily.length, 14);
    expect(daily.values.last, 1);
    expect(daily[DateTime(2026, 9, 19)], 1);
    expect(daily.values.reduce((a, b) => a + b), 2);
  });

  test('daily targets come from todayCompletedCount and timesPerDay', () {
    final twiceOfThree = item(
      'three',
      extra: {'timesPerDay': 3, 'todayCompletedCount': 2},
      execution: completedOn(now),
    );
    expect(twiceOfThree.dailyTarget, 3);
    expect(twiceOfThree.completedToday(now), 2);
    expect(twiceOfThree.doneToday(now), isFalse);
    expect(twiceOfThree.allows('start'), isTrue);

    final done = item(
      'once',
      extra: {'timesPerDay': null, 'todayCompletedCount': 1},
    );
    expect(done.doneToday(now), isTrue);

    // Yesterday's completion does not satisfy today.
    final yesterday = item(
      'y',
      execution: completedOn(now.subtract(const Duration(days: 1))),
    );
    expect(yesterday.doneToday(now), isFalse);

    final summary = ProgramSummary.of([twiceOfThree, done, yesterday], now);
    expect(summary.finished, 1);
    expect(summary.next?.id, 'three');
    // Two remaining repetitions of 'three' plus one of 'y'.
    expect(
      summary.remainingMinutes,
      ((ProgramSummary.estimateSeconds(twiceOfThree) +
                  ProgramSummary.estimateSeconds(yesterday)) /
              60)
          .ceil(),
    );
  });

  test('week and streak follow the server daily calendar', () {
    // Server days run two days ahead of this device's clock.
    final daily = DailyCompletion.listFrom([
      for (var day = 11; day <= 24; day++)
        {
          'date': '2026-09-${day.toString().padLeft(2, '0')}',
          'completed': day >= 21 ? 2 : (day == 19 ? 1 : 0),
        },
    ]);
    final summary = ProgramSummary.of([item('a')], now, daily: daily);
    expect(summary.week.keys.first, DateTime(2026, 9, 18));
    expect(summary.week.keys.last, DateTime(2026, 9, 24));
    expect(summary.week.values.toList(), [
      false, true, false, true, true, true, true, //
    ]);
    expect(summary.streak, 4);
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
