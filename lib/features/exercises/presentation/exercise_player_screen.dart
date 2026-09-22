import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';
import 'exercises_screen.dart';
import 'media_view.dart';

/// Guided one-exercise-at-a-time flow for a single session.
class ExercisePlayerScreen extends ConsumerStatefulWidget {
  const ExercisePlayerScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  ConsumerState<ExercisePlayerScreen> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<ExercisePlayerScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _finished = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _advance(int total) {
    if (_index + 1 >= total) {
      setState(() => _finished = true);
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(exercisesProvider(widget.sessionId));
    // Keep the last data on refresh so actions never flash the whole screen.
    final data = async.valueOrNull;
    return Scaffold(
      body: SafeArea(
        child: data == null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: async.hasError
                    ? AppErrorState(
                        error: async.error!,
                        retry: () =>
                            ref.invalidate(exercisesProvider(widget.sessionId)),
                      )
                    : const AppListSkeleton(count: 1, lines: 2, media: true),
              )
            : _body(data.where((item) => !item.cancelled).toList()),
      ),
    );
  }

  Widget _body(List<AssignedExercise> items) {
    if (items.isEmpty) {
      return Center(child: AppEmptyState(title: context.t('emptyExercises')));
    }
    if (_finished) return _Finished(onClose: () => Navigator.pop(context));
    final position = _index.clamp(0, items.length - 1);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: context.t('close'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (position + 1) / items.length,
                    minHeight: 8,
                    backgroundColor: AppColors.canvas,
                    valueColor: const AlwaysStoppedAnimation(AppColors.success),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${position + 1} / ${items.length}',
                // Counters must not mirror into "4 / 1" under RTL.
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: items.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) => _ExercisePage(
              key: ValueKey(items[index].id),
              exercise: items[index],
              sessionId: widget.sessionId,
              onDone: () => _advance(items.length),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExercisePage extends ConsumerStatefulWidget {
  const _ExercisePage({
    super.key,
    required this.exercise,
    required this.sessionId,
    required this.onDone,
  });
  final AssignedExercise exercise;
  final String sessionId;
  final VoidCallback onDone;
  @override
  ConsumerState<_ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends ConsumerState<_ExercisePage> {
  Timer? _ticker;
  late int _remaining = _total;
  bool _busy = false;

  int get _total =>
      widget.exercise.durationSeconds ?? widget.exercise.holdSeconds ?? 0;
  bool get _running => _ticker != null;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_running) {
      _ticker?.cancel();
      setState(() => _ticker = null);
      return;
    }
    if (_remaining == 0) _remaining = _total;
    setState(() {
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remaining <= 1) {
          timer.cancel();
          HapticFeedback.mediumImpact();
          setState(() {
            _remaining = 0;
            _ticker = null;
          });
          return;
        }
        setState(() => _remaining--);
      });
    });
  }

  void _resetTimer() {
    _ticker?.cancel();
    setState(() {
      _ticker = null;
      _remaining = _total;
    });
  }

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
      if (action == 'start') {
        if (mounted && !_running && _remaining > 0) _toggleTimer();
      } else {
        widget.onDone();
      }
    } on Object catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final language = Localizations.localeOf(context).languageCode;
    final name =
        exercise.localized(exercise.name, exercise.nameEn, language) ??
        exercise.name;
    final canStart = exercise.allows('start');
    final canComplete = exercise.allows('complete');
    final canSkip = exercise.allows('skip');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        if (exercise.mediaUrl != null)
          MediaView(url: exercise.mediaUrl!, type: exercise.mediaType ?? '')
        else
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.self_improvement_rounded,
              size: 44,
              color: AppColors.muted,
            ),
          ),
        const SizedBox(height: 20),
        Text(name, style: AppTypography.section, textAlign: TextAlign.center),
        if (exercise.done || exercise.inProgress) ...[
          const SizedBox(height: 10),
          Center(child: ExerciseStateBadge(exercise: exercise)),
        ],
        const SizedBox(height: 20),
        if (_total > 0) ...[
          Center(
            child: SizedBox(
              width: 172,
              height: 172,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: _total == 0 ? 0 : _remaining / _total,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.canvas,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.success,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _clock(_remaining),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        context.t('timerLabel'),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                tooltip: context.t(_running ? 'pause' : 'play'),
                onPressed: _toggleTimer,
                icon: Icon(
                  _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: context.t('reset'),
                onPressed: _resetTimer,
                icon: const Icon(Icons.replay_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final stat in [
              if (exercise.sets != null)
                (Icons.repeat_rounded, '${exercise.sets}', 'exerciseSets'),
              if (exercise.reps != null)
                (
                  Icons.fitness_center_rounded,
                  '${exercise.reps}',
                  'exerciseReps',
                ),
              if (exercise.restSeconds != null)
                (
                  Icons.self_improvement_rounded,
                  '${exercise.restSeconds}',
                  'exerciseRest',
                ),
            ])
              StatChip(
                icon: stat.$1,
                value: stat.$2,
                label: context.t(stat.$3),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (canStart)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppButton(
              label: context.t('start'),
              icon: Icons.play_arrow_rounded,
              color: AppColors.success,
              busy: _busy,
              onPressed: () => _act('start'),
            ),
          ),
        if (canComplete)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppButton(
              label: context.t('complete'),
              icon: Icons.check_rounded,
              color: AppColors.success,
              busy: _busy,
              onPressed: () => _act('complete'),
            ),
          ),
        if (canSkip)
          TextButton(
            onPressed: _busy ? null : () => _act('skip'),
            child: Text(context.t('skip')),
          ),
        if (!canStart && !canComplete && !canSkip) ...[
          if (!exercise.done) ...[
            Text(
              context.t('actionsUnavailable'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: widget.onDone,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(context.t('next')),
          ),
        ],
      ],
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.onClose});
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 44,
            backgroundColor: Color(0xFFE8F5F0),
            child: Icon(
              Icons.check_rounded,
              size: 46,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.t('sessionDone'),
            style: AppTypography.section,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            context.t('sessionDoneHint'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.7),
          ),
          const SizedBox(height: 28),
          AppButton(label: context.t('close'), onPressed: onClose),
        ],
      ),
    ),
  );
}
