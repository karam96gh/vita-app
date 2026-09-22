import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: context.t('progress'),
    onRefresh: () async {
      ref.invalidate(progressProvider);
      await ref.read(progressProvider.future);
    },
    child: AsyncContent(
      value: ref.watch(progressProvider),
      retry: () => ref.invalidate(progressProvider),
      builder: (progress) => Column(
        children: [
          const Icon(Icons.insights_rounded, size: 64, color: AppColors.accent),
          const SizedBox(height: 24),
          for (final entry in {
            'active': progress.active,
            'completed': progress.completed,
            'skipped': progress.skipped,
            'running': progress.running,
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t(entry.key),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: AppTypography.title.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          AppNavTile(
            icon: Icons.event_note_rounded,
            color: AppColors.info,
            title: context.t('sessionHistory'),
            subtitle: context.t('sessionHistoryHint'),
            onTap: () => context.push('/sessions'),
          ),
        ],
      ),
    ),
  );
}
