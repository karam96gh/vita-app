import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';
import '../../program/domain/program_summary.dart';
import '../../program/presentation/exercise_widgets.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: context.t('progress'),
    onRefresh: () async {
      ref.invalidate(programProvider);
      await ref.read(programProvider.future);
    },
    child: AsyncContent(
      value: ref.watch(programProvider),
      retry: () => ref.invalidate(programProvider),
      skeleton: const AppListSkeleton(count: 3, lines: 2),
      builder: (items) {
        final now = DateTime.now();
        final summary = ProgramSummary.of(items, now);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AdherenceCard(summary: summary),
            const SizedBox(height: 16),
            _StatRow(summary: summary),
            const SizedBox(height: 16),
            _DailyChart(counts: ProgramSummary.dailyCompletions(items, now)),
            const SizedBox(height: 28),
            Text(context.t('recentActivity'), style: AppTypography.section),
            const SizedBox(height: 12),
            _RecentActivity(items: summary.recent.take(8).toList()),
            const SizedBox(height: 24),
            AppNavTile(
              icon: Icons.event_note_rounded,
              color: AppColors.info,
              title: context.t('sessionHistory'),
              subtitle: context.t('sessionHistoryHint'),
              onTap: () => context.push('/sessions'),
            ),
          ],
        );
      },
    ),
  );
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.summary});
  final ProgramSummary summary;
  @override
  Widget build(BuildContext context) {
    final done = summary.active
        .where((item) => item.done && !item.skipped)
        .length;
    return AppCard(
      color: AppColors.primary,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('adherence'),
                  style: AppTypography.section.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  '${ltr('$done')} ${context.t('ofWord')} '
                  '${ltr('${summary.total}')} ${context.t('exercisesCount')}',
                  style: const TextStyle(color: Color(0xFFD6DAEF)),
                ),
              ],
            ),
          ),
          AppProgressRing(
            size: 84,
            progress: summary.adherence,
            value: ltr('${(summary.adherence * 100).round()}%'),
            label: '',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.summary});
  final ProgramSummary summary;
  @override
  Widget build(BuildContext context) {
    final done = summary.active
        .where((item) => item.done && !item.skipped)
        .length;
    final stats = [
      ('summaryCompleted', ltr('$done'), Icons.check_circle_rounded),
      ('running', ltr('${summary.inProgressCount}'), Icons.timelapse_rounded),
      (
        'summarySkipped',
        ltr('${summary.skippedCount}'),
        Icons.fast_forward_rounded,
      ),
      (
        'summaryTime',
        ltr(clock(summary.activeTime.inSeconds)),
        Icons.timer_outlined,
      ),
    ];
    return Row(
      children: [
        for (final (index, stat) in stats.indexed)
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: index == 0 ? 0 : 5,
                end: index == stats.length - 1 ? 0 : 5,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppShadows.soft,
                ),
                child: Column(
                  children: [
                    Icon(stat.$3, color: AppColors.muted, size: 20),
                    const SizedBox(height: 6),
                    FittedBox(
                      child: Text(
                        stat.$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.t(stat.$1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
    );
  }
}

/// Completions per day. One series, so no legend: the title names it.
class _DailyChart extends StatefulWidget {
  const _DailyChart({required this.counts});
  final Map<DateTime, int> counts;
  @override
  State<_DailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<_DailyChart> {
  static const _plotHeight = 120.0;
  late DateTime _selected = widget.counts.keys.last;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final entries = widget.counts.entries.toList();
    final peak = entries.fold(1, (max, e) => e.value > max ? e.value : max);
    final selectedCount = widget.counts[_selected] ?? 0;
    final empty = entries.every((entry) => entry.value == 0);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('completedLast14'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            empty
                ? context.t('noActivity')
                : '${DateFormat.MMMMEEEEd(language).format(_selected)} · '
                      '${context.t('completedCountLabel')}: '
                      '${ltr('$selectedCount')}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _plotHeight + 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final entry in entries)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: entry.key == _selected,
                      label:
                          '${DateFormat.MMMMEEEEd(language).format(entry.key)}: '
                          '${entry.value}',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selected = entry.key),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Padding(
                              // 2px surface gap between adjacent bars.
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: entry.value == 0
                                    ? 3
                                    : _plotHeight * entry.value / peak,
                                constraints: const BoxConstraints(maxWidth: 14),
                                decoration: BoxDecoration(
                                  color: entry.value == 0
                                      ? const Color(0xFFE3E6EF)
                                      : AppColors.chart.withValues(
                                          alpha: entry.key == _selected
                                              ? 1
                                              : .55,
                                        ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat.d(language).format(entry.key),
                              style: TextStyle(
                                fontSize: 11,
                                color: entry.key == _selected
                                    ? AppColors.primary
                                    : AppColors.muted,
                                fontWeight: entry.key == _selected
                                    ? FontWeight.w800
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.items});
  final List<AssignedExercise> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return AppCard(
        child: AppEmptyState(
          title: context.t('noActivity'),
          icon: Icons.insights_rounded,
        ),
      );
    }
    final language = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => openExercise(context, item),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExerciseThumb(exercise: item, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exerciseName(context, item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                AppDates.day(item.finishedAt!, language),
                                AppDates.time(item.finishedAt!, language),
                                if (item.elapsedSeconds != null)
                                  ltr(clock(item.elapsedSeconds!)),
                              ].join(' · '),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            if (item.completionNote?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 8),
                              AppBadge(
                                text: item.completionNote!.trim(),
                                neutral: true,
                                icon: Icons.sticky_note_2_outlined,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
