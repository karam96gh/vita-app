import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';

/// Keeps numbers readable inside Arabic text (e.g. "3 × 10" never mirrors).
String ltr(String value) =>
    '${String.fromCharCode(0x2066)}$value${String.fromCharCode(0x2069)}';

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

class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.exercise, this.size = 56});
  final AssignedExercise exercise;
  final double size;
  @override
  Widget build(BuildContext context) {
    final (icon, color) = exercise.cancelled
        ? (Icons.block_rounded, Theme.of(context).colorScheme.error)
        : exercise.done && !exercise.skipped
        ? (Icons.check_rounded, AppColors.success)
        : exercise.skipped
        ? (Icons.fast_forward_rounded, AppColors.muted)
        : exercise.inProgress
        ? (Icons.timelapse_rounded, AppColors.accent)
        : exercise.mediaType == 'VIDEO'
        ? (Icons.play_arrow_rounded, AppColors.primary)
        : (Icons.self_improvement_rounded, AppColors.primary);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: size * .5),
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
    final muted = exercise.cancelled || exercise.done;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openExercise(context, exercise),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ExerciseThumb(exercise: exercise),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseName(context, exercise),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: muted ? AppColors.muted : AppColors.primary,
                        decoration: exercise.cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (dose.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        dose,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
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
                            children: [
                              Icon(
                                Icons.event_note_rounded,
                                size: 14,
                                color: color,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    if (exercise.done || exercise.inProgress) ...[
                      const SizedBox(height: 8),
                      ExerciseStateBadge(exercise: exercise),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class ExerciseStateBadge extends StatelessWidget {
  const ExerciseStateBadge({super.key, required this.exercise});
  final AssignedExercise exercise;
  @override
  Widget build(BuildContext context) => exercise.cancelled
      ? AppBadge(text: context.t('cancelledExercise'), danger: true)
      : exercise.skipped
      ? AppBadge(
          text: context.t('exerciseSkipped'),
          neutral: true,
          icon: Icons.fast_forward_rounded,
        )
      : exercise.done
      ? AppBadge(
          text: context.t('exerciseCompleted'),
          icon: Icons.check_circle_rounded,
        )
      : AppBadge(
          text: context.t('running'),
          neutral: true,
          icon: Icons.timelapse_rounded,
        );
}

class WarningNote extends StatelessWidget {
  const WarningNote({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.warningTint,
      borderRadius: BorderRadius.circular(14),
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
            style: const TextStyle(color: AppColors.warning, height: 1.6),
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
