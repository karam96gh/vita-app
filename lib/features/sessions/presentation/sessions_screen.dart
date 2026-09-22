import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';
import '../../program/presentation/exercise_widgets.dart';

/// Treatment-session history, newest first.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: context.t('sessionHistory'),
    onRefresh: () async {
      ref.invalidate(sessionsProvider);
      await ref.read(sessionsProvider.future);
    },
    child: AsyncContent(
      value: ref.watch(sessionsProvider),
      retry: () => ref.invalidate(sessionsProvider),
      skeleton: const AppListSkeleton(count: 3, lines: 1),
      builder: (items) {
        if (items.isEmpty) {
          return AppEmptyState(title: context.t('emptySessions'));
        }
        final sorted = [...items]..sort((a, b) => b.date.compareTo(a.date));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, session) in sorted.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppEntrance(
                  index: index,
                  child: _SessionTile(session: session),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final PatientSession session;
  @override
  Widget build(BuildContext context) {
    final id = Uri.encodeComponent(session.id);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/sessions/$id/exercises'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  ltr('${session.number}'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.t('session')} ${ltr('${session.number}')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppDates.day(
                        session.date,
                        Localizations.localeOf(context).languageCode,
                      ),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    if (session.attendanceConfirmed) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppBadge(
                            text: context.t('attended'),
                            icon: Icons.check_rounded,
                          ),
                          if (session.alreadyRated != true)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () =>
                                  context.push('/sessions/$id/rating'),
                              icon: const Icon(
                                Icons.star_outline_rounded,
                                size: 18,
                              ),
                              label: Text(context.t('rate')),
                            ),
                        ],
                      ),
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
