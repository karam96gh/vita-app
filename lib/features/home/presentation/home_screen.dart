import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/config/app_config.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../appointments/presentation/appointments_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider).valueOrNull;
    final total = progress == null
        ? 0
        : progress.active +
              progress.completed +
              progress.skipped +
              progress.running;
    final fraction = progress == null || total == 0
        ? 0.0
        : progress.completed / total;
    return AppPage(
      title: AppConfig.brand,
      actions: [
        IconButton(
          tooltip: context.t('notifications'),
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
      onRefresh: () async {
        ref.invalidate(appointmentsProvider);
        await ref.read(appointmentsProvider.future);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            color: AppColors.primary,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.spa_rounded,
                        color: AppColors.accent,
                        size: 32,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.t('todayTitle'),
                        style: AppTypography.title.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t('todayHint'),
                        style: const TextStyle(
                          color: Color(0xFFD6DAEF),
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.primary,
                        ),
                        onPressed: () => context.go('/sessions'),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(context.t('carePlan')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                AppProgressRing(
                  progress: fraction,
                  value: progress == null
                      ? '–'
                      : '${progress.completed}/$total',
                  label: context.t('todayProgressHint'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(context.t('yourCare'), style: AppTypography.section),
          const SizedBox(height: 16),
          _CareTile(
            title: context.t('sessions'),
            subtitle: context.t('exerciseHint'),
            icon: Icons.accessibility_new_rounded,
            route: '/sessions',
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          _CareTile(
            title: context.t('progress'),
            subtitle: context.t('progressHint'),
            icon: Icons.insights_rounded,
            route: '/progress',
            color: AppColors.info,
          ),
          const SizedBox(height: 12),
          _CareTile(
            title: context.t('chat'),
            subtitle: context.t('chatHint'),
            icon: Icons.forum_outlined,
            route: '/chat',
            color: AppColors.accent,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            children: [
              Text(context.t('nextAppointment'), style: AppTypography.section),
              TextButton(
                onPressed: () => context.go('/appointments'),
                child: Text(context.t('viewAll')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AsyncContent(
            value: ref.watch(appointmentsProvider),
            retry: () => ref.invalidate(appointmentsProvider),
            builder: (items) {
              final future = items.where(
                (a) => !a.end.isBefore(DateTime.now()),
              );
              return future.isEmpty
                  ? AppCard(
                      child: AppEmptyState(
                        title: context.t('emptyAppointments'),
                        icon: Icons.calendar_month_outlined,
                      ),
                    )
                  : AppointmentCard(appointment: future.first);
            },
          ),
        ],
      ),
    );
  }
}

class _CareTile extends StatelessWidget {
  const _CareTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
  });
  final String title, subtitle, route;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .14),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    ),
  );
}
