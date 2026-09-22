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
  const ExerciseTile({super.key, required this.exercise});
  final AssignedExercise exercise;
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

/// Program grouped by treatment session, newest session first.
class SessionGroupedList extends StatelessWidget {
  const SessionGroupedList({
    super.key,
    required this.items,
    required this.sessions,
  });
  final List<AssignedExercise> items;
  final List<PatientSession>? sessions;
  @override
  Widget build(BuildContext context) {
    final groups = <String?, List<AssignedExercise>>{};
    for (final item in items) {
      groups.putIfAbsent(item.sessionId, () => []).add(item);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null || b == null) return a == null ? 1 : -1;
        final na = sessionOf(groups[a]!.first, sessions).number ?? 0;
        final nb = sessionOf(groups[b]!.first, sessions).number ?? 0;
        return nb.compareTo(na);
      });
    final language = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in keys) ...[
          Builder(
            builder: (context) {
              final group = groups[key]!;
              final info = sessionOf(group.first, sessions);
              final active = group.where((item) => !item.cancelled);
              final title = key == null
                  ? context.t('unlinkedSession')
                  : [
                      context.t('session'),
                      if (info.number != null) ltr('${info.number}'),
                    ].join(' ');
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          if (info.date != null)
                            Text(
                              DateFormat.yMMMMEEEEd(
                                language,
                              ).format(info.date!.toLocal()),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    AppBadge(
                      text: ltr(
                        '${active.where((item) => item.done).length}'
                        '/${active.length}',
                      ),
                      neutral: true,
                      icon: Icons.check_rounded,
                    ),
                  ],
                ),
              );
            },
          ),
          ExerciseList(items: groups[key]!),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Program-style list: actionable exercises first, cancelled ones last.
class ExerciseList extends StatelessWidget {
  const ExerciseList({super.key, required this.items});
  final List<AssignedExercise> items;
  @override
  Widget build(BuildContext context) {
    final active = items.where((item) => !item.cancelled).toList();
    final cancelled = items.where((item) => item.cancelled).toList();
    var index = 0;
    Widget tile(AssignedExercise item) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppEntrance(
        index: index++,
        child: ExerciseTile(exercise: item),
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
