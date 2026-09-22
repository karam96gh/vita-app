import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';
import 'media_view.dart';

class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: context.t('exercises'),
    onRefresh: () async {
      ref.invalidate(exercisesProvider(sessionId));
      await ref.read(exercisesProvider(sessionId).future);
    },
    child: AsyncContent(
      value: ref.watch(exercisesProvider(sessionId)),
      retry: () => ref.invalidate(exercisesProvider(sessionId)),
      skeleton: const AppListSkeleton(count: 2, lines: 2, media: true),
      builder: (items) => items.isEmpty
          ? AppEmptyState(title: context.t('emptyExercises'))
          : Column(
              children: [
                if (items.any((item) => !item.cancelled)) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size(48, 56),
                    ),
                    onPressed: () => context.push(
                      '/sessions/${Uri.encodeComponent(sessionId)}/play',
                    ),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: Text(context.t('startSession')),
                  ),
                  const SizedBox(height: 24),
                ],
                for (final (index, exercise) in items.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: AppEntrance(
                      index: index,
                      child: ExerciseCard(
                        key: ValueKey(exercise.id),
                        exercise: exercise,
                        sessionId: sessionId,
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class ExerciseCard extends ConsumerStatefulWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.sessionId,
  });
  final AssignedExercise exercise;
  final String sessionId;
  @override
  ConsumerState<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<ExerciseCard> {
  bool _busy = false;
  Future<void> _act(String action) async {
    if (_busy) return;
    String note = '';
    SkipReason? reason;
    if (action == 'skip') {
      final result =
          await showModalBottomSheet<({SkipReason reason, String note})>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const SkipSheet(),
          );
      if (result == null || !mounted) return;
      reason = result.reason;
      note = result.note;
    }
    if (action == 'complete') {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => const CompletionDialog(),
      );
      if (result == null || !mounted) return;
      note = result;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .exerciseAction(widget.exercise, action, reason: reason, note: note);
      await HapticFeedback.mediumImpact();
      ref.invalidate(exercisesProvider(widget.sessionId));
      ref.invalidate(progressProvider);
    } on Object catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final language = Localizations.localeOf(context).languageCode;
    String? localized(String? ar, String? en) =>
        exercise.localized(ar, en, language);
    final warnings = localized(exercise.warnings, exercise.warningsEn);
    final details = <String, String?>{
      'exerciseDescription': localized(
        exercise.description,
        exercise.descriptionEn,
      ),
      'exerciseInstructions': localized(
        exercise.instructions,
        exercise.instructionsEn,
      ),
      'exerciseMethod': localized(exercise.method, exercise.methodEn),
      'exerciseMistakes': localized(exercise.mistakes, exercise.mistakesEn),
      'exerciseFrequency': localized(exercise.frequency, exercise.frequencyEn),
    }..removeWhere((_, value) => value == null);
    final stats = <(IconData, String, String)>[
      if (exercise.sets != null)
        (Icons.repeat_rounded, '${exercise.sets}', context.t('exerciseSets')),
      if (exercise.reps != null)
        (
          Icons.fitness_center_rounded,
          '${exercise.reps}',
          context.t('exerciseReps'),
        ),
      if (exercise.durationSeconds != null)
        (
          Icons.timer_outlined,
          '${exercise.durationSeconds}',
          context.t('exerciseDuration'),
        ),
      if (exercise.holdSeconds != null)
        (
          Icons.pause_circle_outline_rounded,
          '${exercise.holdSeconds}',
          context.t('exerciseHold'),
        ),
      if (exercise.restSeconds != null)
        (
          Icons.self_improvement_rounded,
          '${exercise.restSeconds}',
          context.t('exerciseRest'),
        ),
    ];
    final canStart = exercise.allows('start');
    final canComplete = exercise.allows('complete');
    final canSkip = exercise.allows('skip');
    return AppCard(
      color: exercise.cancelled ? const Color(0xFFFFF3F2) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: exercise.mediaUrl != null
                ? MediaView(
                    url: exercise.mediaUrl!,
                    type: exercise.mediaType ?? '',
                  )
                : Container(
                    height: 120,
                    width: double.infinity,
                    color: AppColors.canvas,
                    child: const Icon(
                      Icons.self_improvement_rounded,
                      size: 40,
                      color: AppColors.muted,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            localized(exercise.name, exercise.nameEn) ?? exercise.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (exercise.cancelled) ...[
            const SizedBox(height: 12),
            AppBadge(text: context.t('cancelledExercise'), danger: true),
            const SizedBox(height: 8),
            Text(context.t('cancelledHint')),
          ] else if (exercise.done || exercise.inProgress) ...[
            const SizedBox(height: 12),
            ExerciseStateBadge(exercise: exercise),
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final stat in stats)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: StatChip(
                        icon: stat.$1,
                        value: stat.$2,
                        label: stat.$3,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (warnings != null) ...[
            const SizedBox(height: 16),
            Container(
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
                      warnings,
                      style: const TextStyle(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                shape: const Border(),
                title: Text(
                  context.t('exerciseDetails'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                children: [
                  for (final section in details.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t(section.key),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(section.value!),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canStart)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: canComplete || canSkip ? 10 : 0,
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size(48, 54),
                    ),
                    onPressed: _busy ? null : () => _act('start'),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(context.t('start')),
                  ),
                ),
              if (canComplete)
                Padding(
                  padding: EdgeInsets.only(bottom: canSkip ? 10 : 0),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size(48, 54),
                    ),
                    onPressed: _busy ? null : () => _act('complete'),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(context.t('complete')),
                  ),
                ),
              if (canSkip)
                TextButton(
                  onPressed: _busy ? null : () => _act('skip'),
                  child: Text(context.t('skip')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ExerciseStateBadge extends StatelessWidget {
  const ExerciseStateBadge({super.key, required this.exercise});
  final AssignedExercise exercise;
  @override
  Widget build(BuildContext context) => exercise.skipped
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

class CompletionDialog extends StatefulWidget {
  const CompletionDialog({super.key});
  @override
  State<CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<CompletionDialog> {
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.t('completeConfirm')),
    content: TextField(
      controller: _note,
      maxLines: 3,
      decoration: InputDecoration(labelText: context.t('note')),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.t('cancel')),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _note.text),
        child: Text(context.t('confirm')),
      ),
    ],
  );
}

class SkipSheet extends ConsumerStatefulWidget {
  const SkipSheet({super.key});
  @override
  ConsumerState<SkipSheet> createState() => _SkipSheetState();
}

class _SkipSheetState extends ConsumerState<SkipSheet> {
  SkipReason? _reason;
  final _note = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('reason'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          AsyncContent(
            value: ref.watch(skipReasonsProvider),
            retry: () => ref.invalidate(skipReasonsProvider),
            builder: (reasons) => reasons.isEmpty
                ? AppEmptyState(title: context.t('empty'))
                : Column(
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _reason?.id,
                        decoration: InputDecoration(
                          labelText: context.t('reason'),
                        ),
                        items: reasons
                            .map(
                              (r) => DropdownMenuItem(
                                value: r.id,
                                child: Text(r.label),
                              ),
                            )
                            .toList(),
                        onChanged: (id) => setState(
                          () => _reason = reasons.firstWhere((r) => r.id == id),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: context.t(
                            _reason?.isOther == true ? 'reasonText' : 'note',
                          ),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            context.t(_error!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: context.t('confirm'),
                        onPressed: () {
                          final error = Validation.skip(_reason, _note.text);
                          if (error != null) {
                            setState(() => _error = error);
                            return;
                          }
                          Navigator.pop(context, (
                            reason: _reason!,
                            note: _note.text,
                          ));
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
