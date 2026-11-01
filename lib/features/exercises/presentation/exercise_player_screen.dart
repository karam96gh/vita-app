import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/api_failure.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';
import '../../program/domain/exercise_run.dart';
import '../../program/presentation/exercise_widgets.dart';
import 'exercises_screen.dart';
import 'media_view.dart';

/// Guided flow: intro → timed sets and rests → feedback → next exercise.
class ExercisePlayerScreen extends ConsumerStatefulWidget {
  const ExercisePlayerScreen({
    super.key,
    this.sessionId,
    this.startId,
    this.autoStart = false,
  });
  final String? sessionId, startId;
  final bool autoStart;
  @override
  ConsumerState<ExercisePlayerScreen> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<ExercisePlayerScreen> {
  /// Snapshot taken once, so refreshes never reshuffle the running queue.
  List<AssignedExercise>? _queue;
  int _index = 0;
  bool _running = false, _finished = false, _pain = false;
  final _completed = <String>{}, _skipped = <String>{};
  Duration _activeTime = Duration.zero;

  AutoDisposeFutureProvider<List<AssignedExercise>> get _source =>
      widget.sessionId == null
      ? programProvider
      : exercisesProvider(widget.sessionId!);

  void _snapshot(List<AssignedExercise> items) {
    final now = DateTime.now();
    // Due today, plus an explicitly chosen exercise the patient repeats.
    final open = items
        .where(
          (item) =>
              !item.cancelled &&
              (!item.handledToday(now) || item.id == widget.startId),
        )
        .toList();
    final start = open.indexWhere((item) => item.id == widget.startId);
    _queue = start <= 0 ? open : [...open.sublist(start), ...open.take(start)];
  }

  void _onFinished(AssignedExercise item, {required bool completed}) {
    (completed ? _completed : _skipped).add(item.id);
    setState(() {
      _running = false;
      if (_index + 1 >= _queue!.length) {
        _finished = true;
      } else {
        _index++;
      }
    });
  }

  Future<bool> _confirmExit() async {
    if (!_running) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t('exitPlayerTitle')),
            content: Text(context.t('exitPlayerHint')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.t('stay')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.t('exitAction')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _close() async {
    if (await _confirmExit() && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_queue == null) {
      final async = ref.watch(_source);
      final data = async.valueOrNull;
      if (data != null) {
        _snapshot(data);
      } else {
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: async.hasError
                  ? AppErrorState(
                      error: async.error!,
                      retry: () => ref.invalidate(_source),
                    )
                  : const AppListSkeleton(count: 1, lines: 3, media: true),
            ),
          ),
        );
      }
    }
    final queue = _queue!;
    return PopScope(
      canPop: !_running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: SafeArea(
          child: queue.isEmpty
              ? Center(
                  child: AppEmptyState(
                    title: context.t('nothingLeft'),
                    icon: Icons.check_circle_outline_rounded,
                  ),
                )
              : _finished
              ? _Summary(
                  completed: _completed.length,
                  skipped: _skipped.length,
                  activeTime: _activeTime,
                  pain: _pain,
                )
              : Column(
                  children: [
                    _Header(
                      position: _index,
                      total: queue.length,
                      onClose: _close,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: _ExerciseRunView(
                          key: ValueKey(queue[_index].id),
                          exercise: queue[_index],
                          autoStart: widget.autoStart && _index == 0,
                          sessionId: widget.sessionId,
                          upNext: _index + 1 < queue.length
                              ? queue[_index + 1]
                              : null,
                          onRunning: (value) =>
                              setState(() => _running = value),
                          onActiveTime: (value) => _activeTime += value,
                          onPain: () => _pain = true,
                          onFinished: (completed) =>
                              _onFinished(queue[_index], completed: completed),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.position,
    required this.total,
    required this.onClose,
  });
  final int position, total;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: context.t('close'),
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: position / total),
              duration: const Duration(milliseconds: 400),
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: const Color(0xFFE3E6EF),
                valueColor: const AlwaysStoppedAnimation(AppColors.success),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${position + 1} / $total',
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ExerciseRunView extends ConsumerStatefulWidget {
  const _ExerciseRunView({
    super.key,
    required this.exercise,
    required this.onFinished,
    required this.onRunning,
    required this.onActiveTime,
    required this.onPain,
    this.autoStart = false,
    this.sessionId,
    this.upNext,
  });
  final AssignedExercise exercise;
  final bool autoStart;
  final String? sessionId;
  final AssignedExercise? upNext;
  final ValueChanged<bool> onFinished, onRunning;
  final ValueChanged<Duration> onActiveTime;
  final VoidCallback onPain;
  @override
  ConsumerState<_ExerciseRunView> createState() => _ExerciseRunViewState();
}

int _ceilSeconds(Duration value) => (value.inMilliseconds + 999) ~/ 1000;

class _ExerciseRunViewState extends ConsumerState<_ExerciseRunView> {
  static const _feelings = ['feelEasy', 'feelRight', 'feelHard', 'feelPain'];
  late final ExerciseRun _run = ExerciseRun(widget.exercise);

  /// Server truth for this assignment; refreshed after start so later actions
  /// are validated against the real execution state, not the queue snapshot.
  late AssignedExercise _current = widget.exercise;
  Timer? _ticker;
  DateTime? _startedAt;
  bool _busy = false, _showVideo = false;
  String? _feeling;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onTick() {
    final before = (_run.phase, _run.set);
    final moved = _run.tick(DateTime.now());
    if (moved && before != (_run.phase, _run.set)) {
      HapticFeedback.mediumImpact();
    }
    if (_run.phase == RunPhase.feedback) _ticker?.cancel();
    setState(() {});
  }

  void _refreshData() {
    ref
      ..invalidate(programProvider)
      ..invalidate(dailyProvider);
    if (widget.sessionId != null) {
      ref.invalidate(exercisesProvider(widget.sessionId!));
    }
  }

  Future<void> _reload() async {
    final repository = ref.read(repositoryProvider);
    final items = widget.sessionId == null
        ? await repository.program()
        : await repository.exercises(widget.sessionId!);
    final fresh = items.where((item) => item.id == widget.exercise.id);
    if (fresh.isNotEmpty) _current = fresh.first;
  }

  Future<void> _start() async {
    if (_busy) return;
    widget.onRunning(true);
    // An interrupted execution is resumed without a second server start.
    if (!_current.inProgress) {
      setState(() => _busy = true);
      try {
        await ref.read(repositoryProvider).exerciseAction(_current, 'start');
        _refreshData();
        try {
          await _reload();
        } on Object {
          // Starting succeeded. Completion reloads server truth again, so a
          // transient refresh failure must not make the patient tap Start twice.
        }
      } on Object catch (error) {
        if (mounted) {
          setState(() => _busy = false);
          widget.onRunning(false);
          showFailure(context, error);
        }
        return;
      }
    }
    if (!mounted) return;
    final now = DateTime.now();
    HapticFeedback.lightImpact();
    setState(() {
      _busy = false;
      _startedAt = now;
      _run.begin(now);
    });
    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _onTick(),
    );
  }

  void _finishSet() {
    if (_run.finishSet(DateTime.now())) {
      HapticFeedback.mediumImpact();
      if (_run.phase == RunPhase.feedback) _ticker?.cancel();
      setState(() {});
    }
  }

  void _togglePause() {
    final now = DateTime.now();
    setState(() => _run.paused ? _run.resume(now) : _run.pause(now));
  }

  Future<void> _complete() async {
    if (_busy || !_run.canComplete) return;
    setState(() => _busy = true);
    // The therapist reads notes in the clinic language, whatever the UI locale.
    final note = _feeling == null
        ? ''
        : const AppStrings(Locale('ar')).t(_feeling!);
    try {
      // A failed reload right after start is retried here before completing.
      if (!_current.allows('complete')) await _reload();
      await ref
          .read(repositoryProvider)
          .exerciseAction(_current, 'complete', note: note);
      await HapticFeedback.heavyImpact();
      if (_feeling == 'feelPain') widget.onPain();
      if (_startedAt != null) {
        widget.onActiveTime(DateTime.now().difference(_startedAt!));
      }
      _refreshData();
      widget.onFinished(true);
    } on ApiFailure catch (error) {
      if (!mounted) return;
      // The server measures from its own start stamp; tell the patient exactly
      // how long is left instead of a generic failure.
      final required = error.intDetail('requiredSeconds');
      final elapsed = error.intDetail('elapsedSeconds');
      if (error.code == 'EXERCISE_DURATION_NOT_ELAPSED' &&
          required != null &&
          elapsed != null &&
          required > elapsed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.t('durationNotElapsed')} '
              '${ltr(clock(required - elapsed))}',
            ),
          ),
        );
      } else {
        showFailure(context, error);
      }
    } on Object catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    if (_busy) return;
    final result =
        await showModalBottomSheet<({SkipReason reason, String note})>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const SkipSheet(),
        );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .exerciseAction(
            _current,
            'skip',
            reason: result.reason,
            note: result.note,
          );
      _ticker?.cancel();
      _refreshData();
      widget.onFinished(false);
    } on Object catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final media = exercise.mediaUrl == null
        ? null
        : MediaView(url: exercise.mediaUrl!, type: exercise.mediaType ?? '');
    final skip = TextButton(
      onPressed: _busy ? null : _skip,
      child: Text(context.t('skip')),
    );
    return switch (_run.phase) {
      RunPhase.intro => _intro(context, media, skip),
      RunPhase.work || RunPhase.rest => _active(context, media, skip),
      RunPhase.feedback => _feedback(context),
    };
  }

  Widget _intro(BuildContext context, Widget? media, Widget skip) {
    final exercise = widget.exercise;
    final language = Localizations.localeOf(context).languageCode;
    final warnings = exercise.localized(
      exercise.warnings,
      exercise.warningsEn,
      language,
    );
    final instructions = exercise.localized(
      exercise.instructions,
      exercise.instructionsEn,
      language,
    );
    return _Scaffolded(
      bottom: [
        AppButton(
          label: context.t(
            exercise.inProgress ? 'continueExercise' : 'startThisExercise',
          ),
          icon: Icons.play_arrow_rounded,
          color: AppColors.success,
          busy: _busy,
          onPressed: _start,
        ),
        skip,
      ],
      children: [
        media ?? const _MediaPlaceholder(),
        const SizedBox(height: 20),
        Text(
          exerciseName(context, exercise),
          style: AppTypography.section,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          doseLabel(context, exercise),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 16),
        ),
        if (warnings != null) ...[
          const SizedBox(height: 16),
          WarningNote(text: warnings),
        ],
        if (instructions != null) ...[
          const SizedBox(height: 16),
          Text(
            context.t('exerciseInstructions'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(instructions, style: const TextStyle(height: 1.7)),
        ],
        if (widget.upNext != null) ...[
          const SizedBox(height: 20),
          Text(
            '${context.t('upNext')}: ${exerciseName(context, widget.upNext!)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _active(BuildContext context, Widget? media, Widget skip) {
    final now = DateTime.now();
    final rest = _run.phase == RunPhase.rest;
    final remaining = _run.remaining(now);
    final target = _run.phaseTarget;
    final progress = target == Duration.zero
        ? 1.0
        : remaining.inMilliseconds / target.inMilliseconds;
    final setText =
        '${context.t('setLabel')} ${ltr('${_run.set}')} '
        '${context.t('ofWord')} ${ltr('${_run.sets}')}';
    final (big, caption) = rest
        ? (clock(_ceilSeconds(remaining)), context.t('restLabel'))
        : switch (_run.mode) {
            RunMode.timed => (
              clock(_ceilSeconds(remaining)),
              context.t('timerLabel'),
            ),
            RunMode.holdReps => (
              '${_run.holdLeft(now)}',
              '${context.t('holdNow')} · ${context.t('repLabel')} '
                  '${ltr('${_run.currentRep(now)}')} ${context.t('ofWord')} '
                  '${ltr('${_run.reps}')}',
            ),
            RunMode.reps => ('${_run.reps}', context.t('repsTarget')),
            RunMode.untimed => (exerciseName(context, widget.exercise), ''),
          };
    final manual =
        !rest && (_run.mode == RunMode.reps || _run.mode == RunMode.untimed);
    final ready = _run.ready(now);
    return _Scaffolded(
      bottom: [
        if (rest)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 54)),
            onPressed: () => setState(() => _run.skipRest(DateTime.now())),
            icon: const Icon(Icons.fast_forward_rounded),
            label: Text(context.t('skipRest')),
          )
        else if (manual)
          AppButton(
            label: ready
                ? context.t('finishSet')
                : '${context.t('readyIn')} ${ltr(clock(_ceilSeconds(remaining)))}',
            icon: ready ? Icons.check_rounded : Icons.hourglass_top_rounded,
            color: AppColors.success,
            onPressed: ready ? _finishSet : null,
          ),
        skip,
      ],
      children: [
        Row(
          children: [
            AppBadge(text: setText, neutral: rest, icon: Icons.repeat_rounded),
            const Spacer(),
            if (media != null)
              TextButton.icon(
                onPressed: () => setState(() => _showVideo = !_showVideo),
                icon: Icon(
                  _showVideo
                      ? Icons.expand_less_rounded
                      : Icons.play_circle_outline_rounded,
                ),
                label: Text(context.t(_showVideo ? 'hideVideo' : 'watchVideo')),
              ),
          ],
        ),
        if (_showVideo && media != null) ...[const SizedBox(height: 12), media],
        const SizedBox(height: 24),
        Center(
          child: _Ring(
            progress: progress,
            color: rest ? AppColors.accent : AppColors.success,
            big: big,
            caption: _run.paused ? context.t('pausedLabel') : caption,
          ),
        ),
        const SizedBox(height: 16),
        if (_run.mode != RunMode.untimed || rest)
          Center(
            child: IconButton.filled(
              iconSize: 30,
              tooltip: context.t(_run.paused ? 'play' : 'pause'),
              onPressed: _togglePause,
              icon: Icon(
                _run.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              ),
            ),
          ),
        if (rest) ...[
          const SizedBox(height: 16),
          Text(
            '${context.t('nextSetLabel')} ${ltr('${_run.set + 1}')} '
            '${context.t('ofWord')} ${ltr('${_run.sets}')}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          exerciseName(context, widget.exercise),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ],
    );
  }

  Widget _feedback(BuildContext context) => _Scaffolded(
    bottom: [
      AppButton(
        label: context.t('complete'),
        icon: Icons.check_rounded,
        color: AppColors.success,
        busy: _busy,
        onPressed: _complete,
      ),
    ],
    children: [
      const SizedBox(height: 24),
      const Center(
        child: CircleAvatar(
          radius: 40,
          backgroundColor: Color(0xFFE8F5F0),
          child: Icon(Icons.check_rounded, size: 44, color: AppColors.success),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        context.t('howWasIt'),
        textAlign: TextAlign.center,
        style: AppTypography.section,
      ),
      const SizedBox(height: 4),
      Text(
        context.t('feedbackOptional'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 20),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final feeling in _feelings)
            ChoiceChip(
              label: Text(context.t(feeling)),
              selected: _feeling == feeling,
              onSelected: (selected) =>
                  setState(() => _feeling = selected ? feeling : null),
            ),
        ],
      ),
      if (_feeling == 'feelPain') ...[
        const SizedBox(height: 16),
        WarningNote(text: context.t('painAdvice')),
      ],
    ],
  );
}

/// Scrollable content with actions pinned to the bottom.
class _Scaffolded extends StatelessWidget {
  const _Scaffolded({required this.children, required this.bottom});
  final List<Widget> children, bottom;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          children: children,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: bottom,
        ),
      ),
    ],
  );
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.progress,
    required this.color,
    required this.big,
    required this.caption,
  });
  final double progress;
  final Color color;
  final String big, caption;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    height: 220,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: progress.clamp(0, 1),
            strokeWidth: 12,
            strokeCap: StrokeCap.round,
            backgroundColor: AppColors.canvas,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(
                  big,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (caption.isNotEmpty)
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    height: 160,
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Icon(
      Icons.self_improvement_rounded,
      size: 48,
      color: AppColors.muted,
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.completed,
    required this.skipped,
    required this.activeTime,
    required this.pain,
  });
  final int completed, skipped;
  final Duration activeTime;
  final bool pain;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      const SizedBox(height: 32),
      const Center(
        child: CircleAvatar(
          radius: 46,
          backgroundColor: Color(0xFFE8F5F0),
          child: Icon(
            Icons.emoji_events_rounded,
            size: 48,
            color: AppColors.success,
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        context.t('sessionDone'),
        textAlign: TextAlign.center,
        style: AppTypography.title,
      ),
      const SizedBox(height: 8),
      Text(
        context.t('sessionDoneHint'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, height: 1.7),
      ),
      const SizedBox(height: 28),
      Row(
        children: [
          for (final (label, value, color) in [
            ('summaryCompleted', ltr('$completed'), AppColors.success),
            ('summarySkipped', ltr('$skipped'), AppColors.muted),
            ('summaryTime', ltr(clock(activeTime.inSeconds)), AppColors.info),
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AppCard(
                  child: Column(
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t(label),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      if (pain) ...[
        const SizedBox(height: 20),
        WarningNote(text: context.t('painAdvice')),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => context.go('/chat'),
          icon: const Icon(Icons.forum_outlined),
          label: Text(context.t('messageTherapist')),
        ),
      ],
      const SizedBox(height: 28),
      AppButton(
        label: context.t('close'),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
