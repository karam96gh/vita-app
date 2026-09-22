import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/config/app_config.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, required this.enablePush});
  final Future<void> Function() enablePush;
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<String> _busy = {};
  bool _enabling = false;
  @override
  Widget build(BuildContext context) => AppPage(
    title: context.t('notifications'),
    onRefresh: () async {
      ref.invalidate(notificationsProvider);
      await ref.read(notificationsProvider.future);
    },
    child: Column(
      children: [
        if (AppConfig.firebaseEnabled)
          AppButton(
            label: context.t('enableNotifications'),
            busy: _enabling,
            icon: Icons.notifications_active_outlined,
            onPressed: () async {
              setState(() => _enabling = true);
              try {
                await widget.enablePush();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.t('notificationsEnabled'))),
                  );
                }
              } on Object catch (error) {
                if (context.mounted) showFailure(context, error);
              } finally {
                if (mounted) setState(() => _enabling = false);
              }
            },
          ),
        if (AppConfig.firebaseEnabled) const SizedBox(height: 24),
        AsyncContent(
          value: ref.watch(notificationsProvider),
          retry: () => ref.invalidate(notificationsProvider),
          builder: (items) => items.isEmpty
              ? AppEmptyState(
                  title: context.t('emptyNotifications'),
                  icon: Icons.notifications_none,
                )
              : Column(
                  children: [
                    for (final notification in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.localizedTitle(
                                  Localizations.localeOf(context).languageCode,
                                ),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notification.localizedBody(
                                  Localizations.localeOf(context).languageCode,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppDates.day(
                                  notification.at,
                                  Localizations.localeOf(context).languageCode,
                                ),
                              ),
                              if (!notification.read)
                                TextButton(
                                  onPressed: _busy.contains(notification.id)
                                      ? null
                                      : () async {
                                          setState(
                                            () => _busy.add(notification.id),
                                          );
                                          try {
                                            await ref
                                                .read(repositoryProvider)
                                                .readNotification(
                                                  notification.id,
                                                );
                                            ref.invalidate(
                                              notificationsProvider,
                                            );
                                          } on Object catch (error) {
                                            if (context.mounted) {
                                              showFailure(context, error);
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(
                                                () => _busy.remove(
                                                  notification.id,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  child: Text(context.t('markRead')),
                                ),
                            ],
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
