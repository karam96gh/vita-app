import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: context.t('sessions'),
    onRefresh: () async {
      ref.invalidate(sessionsProvider);
      await ref.read(sessionsProvider.future);
    },
    child: AsyncContent(
      value: ref.watch(sessionsProvider),
      retry: () => ref.invalidate(sessionsProvider),
      skeleton: const AppListSkeleton(count: 3, lines: 1),
      builder: (items) => items.isEmpty
          ? AppEmptyState(title: context.t('emptySessions'))
          : Column(
              children: [
                for (final (index, session) in items.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AppEntrance(
                      index: index,
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${context.t('session')} ${session.number}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppDates.day(
                                session.date,
                                Localizations.localeOf(context).languageCode,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                AppButton(
                                  label: context.t('exercises'),
                                  icon: Icons.accessibility_new,
                                  onPressed: () => context.push(
                                    '/sessions/${Uri.encodeComponent(session.id)}/exercises',
                                  ),
                                ),
                                if (session.attendanceConfirmed &&
                                    session.alreadyRated != true)
                                  OutlinedButton(
                                    onPressed: () => context.push(
                                      '/sessions/${Uri.encodeComponent(session.id)}/rating',
                                    ),
                                    child: Text(context.t('rate')),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}
