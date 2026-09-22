import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/config/app_config.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';

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

  Future<void> _enable() async {
    if (_enabling) return;
    setState(() => _enabling = true);
    try {
      await widget.enablePush();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('notificationsEnabled'))),
        );
      }
    } on Object catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
  }

  Future<void> _markRead(PatientNotification notification) async {
    if (notification.read || _busy.contains(notification.id)) return;
    setState(() => _busy.add(notification.id));
    try {
      await ref.read(repositoryProvider).readNotification(notification.id);
      ref.invalidate(notificationsProvider);
    } on Object catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy.remove(notification.id));
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: context.t('notifications'),
    onRefresh: () async {
      ref.invalidate(notificationsProvider);
      await ref.read(notificationsProvider.future);
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (AppConfig.firebaseEnabled) ...[
          AppNavTile(
            icon: Icons.notifications_active_outlined,
            color: AppColors.accent,
            title: context.t('enableNotifications'),
            onTap: _enable,
          ),
          const SizedBox(height: 20),
        ],
        AsyncContent(
          value: ref.watch(notificationsProvider),
          retry: () => ref.invalidate(notificationsProvider),
          skeleton: const AppListSkeleton(count: 4, lines: 2),
          builder: (items) => items.isEmpty
              ? AppEmptyState(
                  title: context.t('emptyNotifications'),
                  icon: Icons.notifications_none_rounded,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, notification) in items.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppEntrance(
                          index: index,
                          child: _NotificationTile(
                            notification: notification,
                            busy: _busy.contains(notification.id),
                            onTap: () => _markRead(notification),
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.busy,
    required this.onTap,
  });
  final PatientNotification notification;
  final bool busy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final unread = !notification.read;
    return Semantics(
      label: unread ? context.t('unreadCount') : context.t('read'),
      child: Material(
        color: unread ? Colors.white : const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: unread && !busy ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: (unread ? AppColors.accent : AppColors.muted)
                      .withValues(alpha: .12),
                  child: Icon(
                    Icons.notifications_rounded,
                    color: unread ? AppColors.accent : AppColors.muted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.localizedTitle(language),
                        style: TextStyle(
                          fontWeight: unread
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.localizedBody(language),
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppDates.day(notification.at, language)} · '
                        '${AppDates.time(notification.at, language)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (unread)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
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
