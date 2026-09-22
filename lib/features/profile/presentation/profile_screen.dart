import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
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
      children: [
        AppCard(
          child: AsyncContent(
            value: ref.watch(profileProvider),
            retry: () => ref.invalidate(profileProvider),
            builder: (profile) => Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  child: Icon(Icons.person_outline, size: 40),
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
