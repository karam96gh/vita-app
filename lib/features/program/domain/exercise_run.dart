import 'dart:math';
import '../../patient/domain/models.dart';

enum RunPhase { intro, work, rest, feedback }

enum RunMode {
  /// Hold a position for `durationSeconds` per set.
  timed,

  /// Each rep is held for `holdSeconds`; reps advance on their own.
  holdReps,

  /// Plain reps; the set ends on the patient's tap after a minimum pace.
  reps,

  /// No timing prescribed at all.
  untimed,
}

/// Wall-clock driven state machine for performing one exercise, so timers stay
/// correct across frame drops and app backgrounding. "Complete" is reachable
/// only after every prescribed set has run its full time.
class ExerciseRun {
  ExerciseRun(this.exercise);

  /// Unprescribed rep pace; guards against finishing a set instantly.
  static const minSecondsPerRep = 2;

  final AssignedExercise exercise;
  RunPhase phase = RunPhase.intro;
  int set = 1;
  DateTime? _endsAt;
  Duration? _frozen;

  int get sets => max(exercise.sets ?? 1, 1);
  int get reps => exercise.reps ?? 0;
  int get holdSeconds => exercise.holdSeconds ?? 0;

  RunMode get mode {
    if (reps > 0) return holdSeconds > 0 ? RunMode.holdReps : RunMode.reps;
    if ((exercise.durationSeconds ?? 0) > 0) return RunMode.timed;
    return RunMode.untimed;
  }

  Duration get workTarget => Duration(
    seconds: switch (mode) {
      RunMode.timed => exercise.durationSeconds!,
      RunMode.holdReps => reps * holdSeconds,
      RunMode.reps => reps * minSecondsPerRep,
      RunMode.untimed => 0,
    },
  );

  Duration get restTarget => Duration(seconds: exercise.restSeconds ?? 0);
  Duration get phaseTarget => phase == RunPhase.rest ? restTarget : workTarget;
  bool get paused => _frozen != null;
  bool get canComplete => phase == RunPhase.feedback;

  Duration remaining(DateTime now) {
    if (_frozen != null) return _frozen!;
    final end = _endsAt;
    if (end == null) return Duration.zero;
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the current set may end now.
  bool ready(DateTime now) =>
      phase == RunPhase.work && !paused && remaining(now) == Duration.zero;

  void begin(DateTime now) {
    set = 1;
    phase = RunPhase.work;
    _start(workTarget, now);
  }

  void pause(DateTime now) {
    if (paused || (phase != RunPhase.work && phase != RunPhase.rest)) return;
    _frozen = remaining(now);
  }

  void resume(DateTime now) {
    final frozen = _frozen;
    if (frozen == null) return;
    _frozen = null;
    _endsAt = now.add(frozen);
  }

  /// Applies automatic transitions; returns true when the phase or set moved.
  bool tick(DateTime now) {
    if (paused) return false;
    if (phase == RunPhase.rest && remaining(now) == Duration.zero) {
      _nextSet(now);
      return true;
    }
    final automatic = mode == RunMode.timed || mode == RunMode.holdReps;
    return automatic && finishSet(now);
  }

  /// Ends the current set; refused until its full time has elapsed.
  bool finishSet(DateTime now) {
    if (!ready(now)) return false;
    if (set >= sets) {
      phase = RunPhase.feedback;
      _endsAt = null;
    } else if (restTarget > Duration.zero) {
      phase = RunPhase.rest;
      _start(restTarget, now);
    } else {
      _nextSet(now);
    }
    return true;
  }

  void skipRest(DateTime now) {
    if (phase == RunPhase.rest) _nextSet(now);
  }

  /// 1-based rep being held right now (hold mode only).
  int currentRep(DateTime now) {
    if (mode != RunMode.holdReps) return 0;
    final done = (workTarget - remaining(now)).inSeconds ~/ holdSeconds;
    return min(done + 1, reps);
  }

  /// Seconds left in the current rep's hold (hold mode only).
  int holdLeft(DateTime now) {
    if (mode != RunMode.holdReps) return 0;
    final left = remaining(now).inSeconds % holdSeconds;
    return left == 0 && remaining(now) > Duration.zero ? holdSeconds : left;
  }

  void _nextSet(DateTime now) {
    set++;
    phase = RunPhase.work;
    _start(workTarget, now);
  }

  void _start(Duration length, DateTime now) {
    _frozen = null;
    _endsAt = now.add(length);
  }
}
