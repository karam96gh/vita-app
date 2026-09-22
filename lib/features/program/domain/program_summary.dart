import 'dart:math';
import '../../patient/domain/models.dart';

/// Derived view of the patient's exercise program for the Today screen.
class ProgramSummary {
  ProgramSummary._(this.active, this.week, this.streak);

  factory ProgramSummary.of(List<AssignedExercise> items, DateTime now) {
    final active = items.where((item) => !item.cancelled).toList();
    final today = _day(now);
    // A device clock behind the server must not push real completions into
    // "the future" and hide them from this week.
    final completedDays = {
      for (final item in active)
        if (item.finishedAt != null && !item.skipped)
          _earliest(_day(item.finishedAt!.toLocal()), today),
    };
    final week = [
      for (var offset = 6; offset >= 0; offset--)
        today.subtract(Duration(days: offset)),
    ];
    // A streak is still alive until today ends without a completion.
    var cursor = completedDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var streak = 0;
    while (completedDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return ProgramSummary._(active, {
      for (final day in week) day: completedDays.contains(day),
    }, streak);
  }

  final List<AssignedExercise> active;

  /// The last seven local days, oldest first, mapped to "had a completion".
  final Map<DateTime, bool> week;
  final int streak;

  int get total => active.length;
  int get finished => active.where((item) => item.done).length;
  bool get complete => total > 0 && finished == total;
  bool get started => active.any((item) => item.executed);

  /// Resume an interrupted exercise first, otherwise the first untouched one.
  AssignedExercise? get next =>
      active.where((item) => item.inProgress).firstOrNull ??
      active.where((item) => !item.done).firstOrNull;

  int get remainingMinutes {
    final seconds = active
        .where((item) => !item.done)
        .fold(0, (sum, item) => sum + estimateSeconds(item));
    return seconds == 0 ? 0 : max(1, (seconds / 60).ceil());
  }

  /// Null when the prescription yields an implausible home-session length.
  int? get displayMinutes {
    final minutes = remainingMinutes;
    return minutes > 0 && minutes <= 120 ? minutes : null;
  }

  /// Rep-based when reps are prescribed, otherwise timed by duration per set.
  static int estimateSeconds(AssignedExercise item) {
    final sets = max<int>(item.sets ?? 1, 1);
    final int work = item.reps != null
        ? item.reps! * max<int>(item.holdSeconds ?? 0, 3)
        : item.durationSeconds ?? 30;
    return sets * work + (sets - 1) * (item.restSeconds ?? 0);
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _earliest(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}
