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
    final canStart = !exercise.cancelled && !exercise.done;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('exercises'))),
      bottomNavigationBar: canStart
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: StartProgramButton(
                label: context.t(
                  exercise.inProgress
                      ? 'continueExercises'
                      : 'startThisExercise',
                ),
                onPressed: () => startPlayer(
                  context,
                  startId: exercise.id,
                  sessionId: exercise.sessionId,
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (exercise.mediaUrl != null)
            MediaView(url: exercise.mediaUrl!, type: exercise.mediaType ?? '')
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.self_improvement_rounded,
                size: 48,
                color: AppColors.muted,
              ),
            ),
          const SizedBox(height: 20),
          Text(exerciseName(context, exercise), style: AppTypography.section),
          Builder(
            builder: (context) {
              final info = sessionOf(
                exercise,
                ref.watch(sessionsProvider).valueOrNull,
              );
              if (info.number == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    '${context.t('fromSession')} ${ltr('${info.number}')}',
                    if (info.date != null)
                      AppDates.day(
                        info.date!,
                        Localizations.localeOf(context).languageCode,
                      ),
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.muted),
                ),
              );
            },
          ),
          if (exercise.cancelled || exercise.done || exercise.inProgress) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExerciseStateBadge(exercise: exercise),
            ),
          ],
          if (exercise.cancelled) ...[
            const SizedBox(height: 8),
            Text(
              context.t('cancelledHint'),
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final stat in stats)
                  StatChip(
                    icon: stat.$1,
                    value: stat.$2,
                    label: context.t(stat.$3),
                  ),
              ],
            ),
          ],
          if (warnings != null) ...[
            const SizedBox(height: 20),
            WarningNote(text: warnings),
          ],
          for (final section in sections.entries) ...[
            const SizedBox(height: 24),
            Text(
              context.t(section.key),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(section.value!, style: const TextStyle(height: 1.7)),
          ],
        ],
      ),
    );
  }
}
