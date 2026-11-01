import 'dart:math';
import '../../patient/domain/models.dart';

/// Derived view of the patient's exercise program for today.
///
/// Exercises repeat without limit (each start opens a new execution), so
/// "done" is always about today: completed `timesPerDay` times, or skipped.
class ProgramSummary {
  ProgramSummary._(this.active, this.now, this.week, this.streak);

  factory ProgramSummary.of(
    List<AssignedExercise> items,
    DateTime now, {
    List<DailyCompletion>? daily,
  }) {
    final active = items.where((item) => !item.cancelled).toList();
    // The server's clinic calendar wins; a wrong device clock cannot skew it.
    final days = daily != null && daily.isNotEmpty
        ? {for (final day in daily) day.date: day.completed}
        : dailyCompletions(items, now);
    final ordered = days.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final lastSeven = ordered.skip(max(0, ordered.length - 7));
    var streak = 0;
    // A streak is still alive until today ends without a completion.
    final backwards = ordered.reversed.toList();
    final start = backwards.isNotEmpty && backwards.first.value == 0 ? 1 : 0;
    for (final entry in backwards.skip(start)) {
      if (entry.value == 0) break;
      streak++;
    }
    return ProgramSummary._(active, now, {
      for (final entry in lastSeven) entry.key: entry.value > 0,
    }, streak);
  }

  final List<AssignedExercise> active;
  final DateTime now;

  /// Up to the last seven clinic days, oldest first, mapped to "any completion".
  final Map<DateTime, bool> week;
  final int streak;

  int get total => active.length;

  /// Exercises with nothing left to do today (done or skipped).
  int get finished => active.where((item) => item.handledToday(now)).length;
  int get doneToday => active.where((item) => item.doneToday(now)).length;
  int get skippedToday => active.where((item) => item.skippedToday(now)).length;
  int get inProgressCount => active.where((item) => item.inProgress).length;
  bool get complete => total > 0 && finished == total;
  bool get started =>
      active.any((item) => item.inProgress || item.completedToday(now) > 0);

  /// Resume an interrupted exercise first, otherwise the first one still due.
  AssignedExercise? get next =>
      active.where((item) => item.inProgress).firstOrNull ??
      active.where((item) => !item.handledToday(now)).firstOrNull;

  int get remainingMinutes {
    final seconds = active
        .where((item) => !item.handledToday(now))
        .fold(
          0,
          (sum, item) =>
              sum +
              estimateSeconds(item) *
                  max(1, item.dailyTarget - item.completedToday(now)),
        );
    return seconds == 0 ? 0 : max(1, (seconds / 60).ceil());
  }

  /// Latest completion of each exercise, most recent first.
  List<AssignedExercise> get recent =>
      active.where((item) => item.finishedAt != null && !item.skipped).toList()
        ..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));

  /// Fallback when the daily endpoint is unavailable: only the latest
  /// execution per exercise is known, so repeated sessions are undercounted.
  static Map<DateTime, int> dailyCompletions(
    List<AssignedExercise> items,
    DateTime now, {
    int days = 14,
  }) {
    final today = _day(now);
    final counts = {
      for (var offset = days - 1; offset >= 0; offset--)
        today.subtract(Duration(days: offset)): 0,
    };
    for (final item in items) {
      if (item.cancelled || item.skipped || item.finishedAt == null) continue;
      // A device clock behind the server must not push completions into
      // "the future" and hide them.
      final day = _earliest(_day(item.finishedAt!.toLocal()), today);
      if (counts.containsKey(day)) counts[day] = counts[day]! + 1;
    }
    return counts;
  }

  /// Null when the prescription yields an implausible home-session length.
  int? get displayMinutes {
    final minutes = remainingMinutes;
    return minutes > 0 && minutes <= 120 ? minutes : null;
  }

  /// Matches EXERCISE_DURATION_NOT_ELAPSED on the server. Rest is excluded.
  static int estimateSeconds(AssignedExercise item) {
    final sets = max<int>(item.sets ?? 1, 1);
    final int work = item.reps != null
        ? item.reps! * ((item.holdSeconds ?? 0) > 0 ? item.holdSeconds! : 2)
        : item.durationSeconds ?? 0;
    return sets * work;
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _earliest(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}
