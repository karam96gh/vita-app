import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../appointments/presentation/appointments_screen.dart';
import '../../program/domain/program_summary.dart';
import '../../program/presentation/exercise_widgets.dart';
import '../../program/presentation/program_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(programProvider)
      ..invalidate(dailyProvider)
      ..invalidate(appointmentsProvider)
      ..invalidate(profileProvider)
      ..invalidate(therapistMessageProvider);
    await ref.read(programProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          try {
            await _refresh(ref);
          } on Object {
            /* Each section renders its own failure. */
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const _Header(),
            const SizedBox(height: 24),
            const _ProgramCard(),
            const SizedBox(height: 16),
            const _WeekCard(),
            const SizedBox(height: 28),
            _SectionTitle(
              title: context.t('nextAppointment'),
              action: context.t('allAppointments'),
              onAction: () => context.push('/appointments'),
            ),
            const SizedBox(height: 12),
            const _NextAppointment(),
            const _TherapistMessage(),
          ],
        ),
      ),
    ),
  );
}

class _Header extends ConsumerWidget {
  const _Header();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(profileProvider).valueOrNull?.name;
    final first = name?.split(' ').first;
    final greeting = context.t(
      DateTime.now().hour < 12 ? 'goodMorning' : 'goodEvening',
    );
    return Row(
      children: [
        Semantics(
          button: true,
          label: context.t('profile'),
          child: InkResponse(
            onTap: () => context.push('/profile'),
            radius: 28,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              child: first == null
                  ? const Icon(Icons.person_outline, color: Colors.white)
                  : Text(
                      first.characters.first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                first == null ? greeting : '$greeting، $first',
                style: AppTypography.section,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                DateFormat.MMMMEEEEd(
                  Localizations.localeOf(context).languageCode,
                ).format(DateTime.now()),
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: context.t('notifications'),
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _ProgramCard extends ConsumerWidget {
  const _ProgramCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncContent(
    value: ref.watch(programProvider),
    retry: () => ref.invalidate(programProvider),
    skeleton: const AppListSkeleton(count: 1, lines: 3),
    builder: (items) {
      final summary = ProgramSummary.of(items, DateTime.now());
      if (summary.total == 0) {
        return AppCard(
          child: AppEmptyState(
            title: context.t('noProgram'),
            hint: context.t('noProgramHint'),
            icon: Icons.self_improvement_rounded,
          ),
        );
      }
      final next = summary.next;
      final minutes = summary.displayMinutes;
      final subtitle = summary.complete
          ? context.t('programDoneHint')
          : [
              '${ltr('${summary.total - summary.finished}')} '
                  '${context.t('exercisesCount')}',
              if (minutes != null)
                '${context.t('aboutMinutes')} ${ltr('$minutes')} '
                    '${context.t('minutes')}',
            ].join(' · ');
      return AppCard(
        color: AppColors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(
                          summary.complete ? 'programDone' : 'todayProgram',
                        ),
                        style: AppTypography.section.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFD6DAEF),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                AppProgressRing(
                  size: 76,
                  progress: summary.finished / summary.total,
                  value: ltr('${summary.finished}/${summary.total}'),
                  label: '',
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (next == null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x66FFFFFF)),
                  minimumSize: const Size(48, 52),
                ),
                onPressed: () => context.go('/program'),
                child: Text(context.t('viewProgram')),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(48, 56),
                ),
                onPressed: () => startPlayer(context, startId: next.id),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  context.t(
                    summary.started ? 'continueExercises' : 'startExercises',
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _WeekCard extends ConsumerWidget {
  const _WeekCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(programProvider).valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final summary = ProgramSummary.of(
      items,
      DateTime.now(),
      daily: ref.watch(dailyProvider).valueOrNull,
    );
    final language = Localizations.localeOf(context).languageCode;
    // The last server day is "today" in the clinic's calendar.
    final today = summary.week.keys.last;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('thisWeek'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              if (summary.streak > 0) ...[
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _streakLabel(context, summary.streak),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final entry in summary.week.entries)
                Expanded(
                  child: _Day(
                    label: entry.key == today
                        ? context.t('today')
                        : DateFormat.EEEE(language).format(entry.key),
                    date: DateFormat.d(language).format(entry.key),
                    done: entry.value,
                    today: entry.key == today,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Arabic counts agree with the noun: يوم واحد، يومان، 3 أيام، 11 يوماً.
String _streakLabel(BuildContext context, int days) {
  if (!context.strings.ar) return '${ltr('$days')} ${context.t('streakDays')}';
  return switch (days) {
    1 => 'يوم واحد',
    2 => 'يومان',
    <= 10 => '${ltr('$days')} أيام',
    _ => '${ltr('$days')} يوماً',
  };
}

class _Day extends StatelessWidget {
  const _Day({
    required this.label,
    required this.date,
    required this.done,
    required this.today,
  });
  final String label, date;
  final bool done, today;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $date',
    child: Column(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.success
                : today
                ? Colors.white
                : AppColors.canvas,
            border: today && !done
                ? Border.all(color: AppColors.accent, width: 2)
                : null,
          ),
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
              : Text(
                  date,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: today ? AppColors.primary : AppColors.muted,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              color: today ? AppColors.primary : AppColors.muted,
              fontWeight: today ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onAction,
  });
  final String title, action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: AppTypography.section)),
      TextButton(onPressed: onAction, child: Text(action)),
    ],
  );
}

class _NextAppointment extends ConsumerWidget {
  const _NextAppointment();
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncContent(
    value: ref.watch(appointmentsProvider),
    retry: () => ref.invalidate(appointmentsProvider),
    skeleton: const AppListSkeleton(count: 1, lines: 1),
    builder: (items) {
      final upcoming = items.where((a) => !a.end.isBefore(DateTime.now()));
      return upcoming.isEmpty
          ? AppCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.canvas,
                    child: Icon(
                      Icons.event_available_rounded,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      context.t('emptyAppointments'),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            )
          : AppointmentCard(appointment: upcoming.first);
    },
  );
}

/// Optional preview; silently absent when there is no therapist or message.
class _TherapistMessage extends ConsumerWidget {
  const _TherapistMessage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(therapistMessageProvider).valueOrNull;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.go('/chat'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.accent.withValues(alpha: .14),
                  child: const Icon(
                    Icons.forum_outlined,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.t('fromTherapist'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            AppDates.time(
                              message.at,
                              Localizations.localeOf(context).languageCode,
                            ),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
