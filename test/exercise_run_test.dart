import 'package:flutter_test/flutter_test.dart';
import 'package:vita_patient/features/program/domain/exercise_run.dart';
import 'program_summary_test.dart' show item;

void main() {
  final t0 = DateTime(2026, 9, 22, 10);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  test('timed exercise cannot complete before every set runs its time', () {
    // 2 sets × 30s with 10s rest, no reps.
    final run = ExerciseRun(
      item(
        't',
        extra: {
          'reps': null,
          'sets': 2,
          'durationSeconds': 30,
          'holdSeconds': null,
          'restSeconds': 10,
        },
      ),
    );
    expect(run.mode, RunMode.timed);
    run.begin(t0);
    expect(run.finishSet(at(29)), isFalse);
    expect(run.tick(at(29)), isFalse);
    expect(run.canComplete, isFalse);

    expect(run.tick(at(30)), isTrue);
    expect(run.phase, RunPhase.rest);
    expect(run.tick(at(40)), isTrue);
    expect((run.phase, run.set), (RunPhase.work, 2));
    expect(run.canComplete, isFalse);

    expect(run.tick(at(70)), isTrue);
    expect(run.canComplete, isTrue);
  });

  test('plain reps unlock the set only after the minimum pace', () {
    final run = ExerciseRun(
      item('r', extra: {'sets': 1, 'reps': 10, 'holdSeconds': null}),
    );
    expect(run.mode, RunMode.reps);
    run.begin(t0);
    // Plain reps never end on their own.
    expect(run.tick(at(100)), isFalse);
    expect(run.finishSet(at(19)), isFalse);
    expect(run.finishSet(at(20)), isTrue);
    expect(run.canComplete, isTrue);
  });

  test('held reps count themselves and end the set automatically', () {
    // Fixture: 3 sets × 10 reps, hold 5s, rest 20s.
    final run = ExerciseRun(item('h'));
    expect(run.mode, RunMode.holdReps);
    expect(run.workTarget, const Duration(seconds: 50));
    run.begin(t0);
    expect(run.currentRep(at(0)), 1);
    expect(run.holdLeft(at(0)), 5);
    expect(run.currentRep(at(12)), 3);
    expect(run.holdLeft(at(12)), 3);
    expect(run.tick(at(50)), isTrue);
    expect(run.phase, RunPhase.rest);
  });

  test('pausing freezes the countdown and blocks finishing', () {
    final run = ExerciseRun(
      item('p', extra: {'reps': null, 'sets': 1, 'durationSeconds': 30}),
    );
    run.begin(t0);
    run.pause(at(10));
    expect(run.remaining(at(500)), const Duration(seconds: 20));
    expect(run.tick(at(500)), isFalse);
    run.resume(at(500));
    expect(run.tick(at(519)), isFalse);
    expect(run.tick(at(520)), isTrue);
    expect(run.canComplete, isTrue);
  });

  test('rest can be skipped but work time cannot', () {
    final run = ExerciseRun(
      item(
        's',
        extra: {
          'reps': null,
          'sets': 2,
          'durationSeconds': 30,
          'restSeconds': 60,
        },
      ),
    );
    run.begin(t0);
    run.skipRest(at(5)); // ignored while working
    expect(run.phase, RunPhase.work);
    run.tick(at(30));
    run.skipRest(at(31));
    expect((run.phase, run.set), (RunPhase.work, 2));
    expect(run.finishSet(at(40)), isFalse);
  });

  test('an exercise with no timing ends on demand', () {
    final run = ExerciseRun(
      item(
        'u',
        extra: {
          'reps': null,
          'sets': null,
          'durationSeconds': null,
          'holdSeconds': null,
        },
      ),
    );
    expect(run.mode, RunMode.untimed);
    run.begin(t0);
    expect(run.finishSet(t0), isTrue);
    expect(run.canComplete, isTrue);
  });
}
