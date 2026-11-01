import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../exercises/presentation/media_view.dart';
import '../../patient/domain/models.dart';
import 'exercise_widgets.dart';
import 'program_screen.dart';

/// Read-only reference page; performing the exercise happens in the player.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.id, this.initial});
  final String id;
  final AssignedExercise? initial;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref
        .watch(programProvider)
        .valueOrNull
        ?.where((item) => item.id == id)
        .firstOrNull;
    final exercise = latest ?? initial;
    if (exercise == null) {
      return AppPage(
        title: context.t('exercises'),
        child: AsyncContent(
          value: ref.watch(programProvider),
          retry: () => ref.invalidate(programProvider),
          builder: (_) => AppEmptyState(title: context.t('EXERCISE_NOT_FOUND')),
        ),
      );
    }
    final language = Localizations.localeOf(context).languageCode;
    String? localized(String? ar, String? en) =>
        exercise.localized(ar, en, language);
    final warnings = localized(exercise.warnings, exercise.warningsEn);
    final sections = {
      'exerciseInstructions': localized(
        exercise.instructions,
        exercise.instructionsEn,
      ),
      'exerciseMethod': localized(exercise.method, exercise.methodEn),
      'exerciseDescription': localized(
        exercise.description,
        exercise.descriptionEn,
      ),
      'exerciseMistakes': localized(exercise.mistakes, exercise.mistakesEn),
      'exerciseFrequency': localized(exercise.frequency, exercise.frequencyEn),
    }..removeWhere((_, value) => value == null);
    final stats = [
      if (exercise.sets != null)
        (Icons.repeat_rounded, '${exercise.sets}', 'exerciseSets'),
      if (exercise.reps != null)
        (Icons.fitness_center_rounded, '${exercise.reps}', 'exerciseReps'),
      if (exercise.durationSeconds != null)
        (
          Icons.timer_outlined,
          '${exercise.durationSeconds}',
          'exerciseDuration',
        ),
      if (exercise.holdSeconds != null)
        (
          Icons.pause_circle_outline_rounded,
          '${exercise.holdSeconds}',
          'exerciseHold',
        ),
      if (exercise.restSeconds != null)
        (
          Icons.self_improvement_rounded,
          '${exercise.restSeconds}',
          'exerciseRest',
        ),
    ];
    // Exercises repeat without limit, so only cancellation hides the action.
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('exercises'))),
      bottomNavigationBar: exercise.cancelled
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: StartProgramButton(
                label: context.t(
                  exercise.inProgress
                      ? 'continueExercises'
                      : exercise.doneToday(now)
                      ? 'repeatExercise'
                      : 'startThisExercise',
                ),
                // The whole-program feed carries today's counts.
                onPressed: () =>
                    startPlayer(context, startId: exercise.id, autoStart: true),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exerciseName(context, exercise),
                  style: AppTypography.section.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                Builder(
                  builder: (context) {
                    final info = sessionOf(
                      exercise,
                      ref.watch(sessionsProvider).valueOrNull,
                    );
                    if (info.number == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        [
                          '${context.t('fromSession')} ${ltr('${info.number}')}',
                          if (info.date != null)
                            AppDates.day(
                              info.date!,
                              Localizations.localeOf(context).languageCode,
                            ),
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    );
                  },
                ),
                if (ExerciseStateBadge.shows(exercise)) ...[
                  const SizedBox(height: 12),
                  ExerciseStateBadge(exercise: exercise),
                ],
                if (exercise.cancelled) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.t('cancelledHint'),
                    style: const TextStyle(color: AppColors.muted, height: 1.6),
                  ),
                ],
              ],
            ),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                final columns = constraints.maxWidth >= 330 * textScale
                    ? 3
                    : constraints.maxWidth >= 220 * textScale
                    ? 2
                    : 1;
                final visibleColumns = columns > stats.length
                    ? stats.length
                    : columns;
                final width =
                    (constraints.maxWidth - 10 * (visibleColumns - 1)) /
                    visibleColumns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final stat in stats)
                      StatChip(
                        width: width,
                        icon: stat.$1,
                        value: stat.$2,
                        label: context.t(stat.$3),
                        color: AppColors.primary,
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          if (exercise.mediaUrl != null)
            MediaView(url: exercise.mediaUrl!, type: exercise.mediaType ?? '')
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: .08),
                ),
              ),
              child: Center(child: ExerciseThumb(exercise: exercise, size: 80)),
            ),
          if (warnings != null) ...[
            const SizedBox(height: 20),
            WarningNote(text: warnings),
          ],
          for (final section in sections.entries) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(section.key),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    section.value!,
                    style: const TextStyle(fontSize: 15, height: 1.8),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
