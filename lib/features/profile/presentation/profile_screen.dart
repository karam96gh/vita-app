import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: context.t('profile'),
    onRefresh: () async {
      ref.invalidate(profileProvider);
      await ref.read(profileProvider.future);
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: AsyncContent(
            value: ref.watch(profileProvider),
            retry: () => ref.invalidate(profileProvider),
            builder: (profile) => Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    profile.name.characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (profile.phone != null)
                  Text(profile.phone!, textDirection: TextDirection.ltr),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppNavTile(
          icon: Icons.calendar_month_rounded,
          color: AppColors.accent,
          title: context.t('myAppointments'),
          onTap: () => context.push('/appointments'),
        ),
        const SizedBox(height: 12),
        AppNavTile(
          icon: Icons.event_note_rounded,
          color: AppColors.info,
          title: context.t('sessionHistory'),
          subtitle: context.t('sessionHistoryHint'),
          onTap: () => context.push('/sessions'),
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.t('language')),
                trailing: Text(
                  context.t(context.strings.ar ? 'arabic' : 'english'),
                ),
                onTap: () => ref.read(localeProvider.notifier).toggle(),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(context.t('logout')),
                onTap: () async {
                  if (!await confirmAction(
                    context,
                    context.t('logoutConfirm'),
                  )) {
                    return;
                  }
                  try {
                    await ref.read(authProvider.notifier).logout();
                  } on Object catch (error) {
                    if (context.mounted) showFailure(context, error);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
