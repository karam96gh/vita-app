import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/config/app_config.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';

/// Keeps numbers readable inside Arabic text (e.g. "3 × 10" never mirrors).
String ltr(String value) =>
    '${String.fromCharCode(0x2066)}$value${String.fromCharCode(0x2069)}';

/// "N exercises" with Arabic number agreement:
/// تمرين واحد، تمرينان (تمرينين after "من")، 3 تمارين، 11 تمريناً.
String exerciseCount(BuildContext context, int n, {bool genitive = false}) {
  if (!context.strings.ar) {
    return '${ltr('$n')} ${n == 1 ? 'exercise' : 'exercises'}';
  }
  return switch (n) {
    1 => 'تمرين واحد',
    2 => genitive ? 'تمرينين' : 'تمرينان',
    >= 3 && <= 10 => '${ltr('$n')} تمارين',
    _ => '${ltr('$n')} تمريناً',
  };
}

String clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Compact prescription line such as "3 × 10 · ثبات 5ث".
String doseLabel(BuildContext context, AssignedExercise item) {
  final parts = <String>[];
  final sets = item.sets;
  if (item.reps != null) {
    parts.add(
      sets != null && sets > 1
          ? ltr('$sets × ${item.reps}')
          : '${ltr('${item.reps}')} ${context.t('repsShort')}',
    );
  } else if (item.durationSeconds != null) {
    final time = clock(item.durationSeconds!);
    parts.add(ltr(sets != null && sets > 1 ? '$sets × $time' : time));
  }
  if (item.holdSeconds != null) {
    parts.add(
      '${context.t('holdShort')} '
      '${ltr('${item.holdSeconds}')}${context.t('secondsShort')}',
    );
  }
  return parts.join(' · ');
}

String exerciseName(BuildContext context, AssignedExercise item) =>
    item.localized(
      item.name,
      item.nameEn,
      Localizations.localeOf(context).languageCode,
    ) ??
    item.name;

void openExercise(BuildContext context, AssignedExercise item) =>
    context.push('/program/${Uri.encodeComponent(item.id)}', extra: item);

class ExerciseThumb extends ConsumerWidget {
  const ExerciseThumb({super.key, required this.exercise, this.size = 56});
  final AssignedExercise exercise;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final thumbnail = exercise.thumbnailUrl?.trim().isNotEmpty == true
        ? exercise.thumbnailUrl
        : exercise.mediaType == 'IMAGE' &&
              exercise.mediaUrl?.trim().isNotEmpty == true
        ? exercise.mediaUrl
        : null;
    final (icon, color) = exercise.cancelled
        ? (Icons.block_rounded, Theme.of(context).colorScheme.error)
        : exercise.doneToday(now)
        ? (Icons.check_rounded, AppColors.success)
        : exercise.skippedToday(now)
        ? (Icons.fast_forward_rounded, AppColors.muted)
        : exercise.inProgress
        ? (Icons.timelapse_rounded, AppColors.accent)
        : exercise.mediaType == 'VIDEO'
        ? (Icons.play_arrow_rounded, AppColors.primary)
        : (Icons.self_improvement_rounded, AppColors.primary);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .12)),
      ),
      child: Icon(icon, color: color, size: size * .5),
    );
    if (thumbnail == null) return fallback;
    final raw = Uri.tryParse(thumbnail);
    final config = ref.read(configProvider);
    final gateway = Uri.tryParse(config.gateway);
    final uri = raw == null ? null : gateway?.resolveUri(raw);
    final developmentMedia =
        !kReleaseMode &&
        config.environment == Environment.development &&
        uri?.scheme == 'http' &&
        uri?.origin == gateway?.origin;
    if (uri == null ||
        (uri.scheme != 'https' && !developmentMedia) ||
        uri.userInfo.isNotEmpty) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        uri.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class ExerciseTile extends StatelessWidget {
  const ExerciseTile({super.key, required this.exercise, this.session});
  final AssignedExercise exercise;

  /// Owning treatment session, shown as a hint under the prescription.
  final ({int? number, DateTime? date})? session;
  @override
  Widget build(BuildContext context) {
    final dose = doseLabel(context, exercise);
    final muted = exercise.cancelled || exercise.handledToday(DateTime.now());
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.primary.withValues(alpha: .08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openExercise(context, exercise),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExerciseThumb(exercise: exercise),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseName(context, exercise),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.5,
                        color: muted ? AppColors.muted : AppColors.primary,
                        decoration: exercise.cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (dose.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        dose,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (session != null) ...[
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final number = session!.number;
                          final date = session!.date;
                          final color = number == null
                              ? AppColors.muted
                              : AppColors.info;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Icon(
                                  Icons.event_note_rounded,
                                  size: 16,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  number == null
                                      ? context.t('unlinkedSession')
                                      : [
                                          '${context.t('session')} '
                                              '${ltr('$number')}',
                                          if (date != null)
                                            DateFormat.MMMd(
                                              Localizations.localeOf(
                                                context,
                                              ).languageCode,
                                            ).format(date.toLocal()),
                                        ].join(' · '),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    if (ExerciseStateBadge.shows(exercise)) ...[
                      const SizedBox(height: 8),
                      ExerciseStateBadge(exercise: exercise),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsetsDirectional.only(start: 6, top: 16),
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's status: in progress, done/skipped today, or "1 من 3 اليوم".
class ExerciseStateBadge extends StatelessWidget {
  const ExerciseStateBadge({super.key, required this.exercise});
  final AssignedExercise exercise;

  static bool shows(AssignedExercise exercise) {
    final now = DateTime.now();
    return exercise.cancelled ||
        exercise.inProgress ||
        exercise.handledToday(now) ||
        exercise.dailyTarget > 1;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final count = exercise.completedToday(now);
    final target = exercise.dailyTarget;
    final tally =
        '${ltr('${min(count, target)}')} ${context.t('ofWord')} '
        '${ltr('$target')} ${context.t('today')}';
    if (exercise.cancelled) {
      return AppBadge(text: context.t('cancelledExercise'), danger: true);
    }
    if (exercise.inProgress) {
      return AppBadge(
        text: context.t('running'),
        neutral: true,
        icon: Icons.timelapse_rounded,
      );
    }
    if (exercise.doneToday(now)) {
      return AppBadge(
        text: target > 1 ? tally : context.t('doneToday'),
        icon: Icons.check_circle_rounded,
      );
    }
    if (exercise.skippedToday(now)) {
      return AppBadge(
        text: context.t('skippedToday'),
        neutral: true,
        icon: Icons.fast_forward_rounded,
      );
    }
    if (target > 1) {
      return AppBadge(text: tally, neutral: true, icon: Icons.repeat_rounded);
    }
    return const SizedBox.shrink();
  }
}

class WarningNote extends StatelessWidget {
  const WarningNote({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.warningTint,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.warning.withValues(alpha: .18)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.warning,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Session number/date for an exercise; the all-exercises response sometimes
/// omits the embedded session, so fall back to the session history by id.
({int? number, DateTime? date}) sessionOf(
  AssignedExercise item,
  List<PatientSession>? sessions,
) {
  final match = sessions?.where((s) => s.id == item.sessionId).firstOrNull;
  return (number: item.sessionNumber ?? match?.number, date: match?.date);
}

/// Program-style list: actionable exercises first, cancelled ones last.
class ExerciseList extends StatelessWidget {
  const ExerciseList({
    super.key,
    required this.items,
    this.showSession = false,
    this.sessions,
  });
  final List<AssignedExercise> items;

  /// Tag each exercise with its owning session (whole-program view).
  final bool showSession;
  final List<PatientSession>? sessions;
  @override
  Widget build(BuildContext context) {
    final active = items.where((item) => !item.cancelled).toList();
    final cancelled = items.where((item) => item.cancelled).toList();
    var index = 0;
    Widget tile(AssignedExercise item) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppEntrance(
        index: index++,
        child: ExerciseTile(
          exercise: item,
          session: showSession ? sessionOf(item, sessions) : null,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in active) tile(item),
        if (cancelled.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.t('cancelledSection'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in cancelled) tile(item),
        ],
      ],
    );
  }
}
