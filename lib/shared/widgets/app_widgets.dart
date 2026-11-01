import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/app_strings.dart';
import '../../app/theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.large),
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.primary.withValues(alpha: .06)),
      boxShadow: AppShadows.soft,
    ),
    child: child,
  );
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.icon,
    this.color,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => FilledButton(
    style: color == null
        ? null
        : FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: color == AppColors.accent
                ? AppColors.primary
                : Colors.white,
          ),
    onPressed: busy ? null : onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 20),
        if (busy || icon != null) const SizedBox(width: 10),
        Flexible(child: Text(label)),
      ],
    ),
  );
}

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = 12,
  });
  final double height, width, radius;
  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: .5,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hold a steady placeholder when the system asks for reduced motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(
      begin: .45,
      end: .9,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
    child: Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E9F2),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.progress,
    required this.value,
    required this.label,
    this.size = 92,
  });
  final double progress;
  final String value, label;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: 1,
            strokeWidth: 8,
            strokeCap: StrokeCap.round,
            valueColor: AlwaysStoppedAnimation(
              Colors.white.withValues(alpha: .16),
            ),
          ),
        ),
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: progress.clamp(0, 1),
            strokeWidth: 8,
            strokeCap: StrokeCap.round,
            backgroundColor: Colors.transparent,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (label.isNotEmpty)
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD6DAEF), fontSize: 12),
              ),
          ],
        ),
      ],
    ),
  );
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.primary,
    this.width,
  });
  final IconData icon;
  final String value, label;
  final Color color;
  final double? width;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .045),
      border: Border.all(color: color.withValues(alpha: .08)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({
    super.key,
    this.count = 3,
    this.lines = 2,
    this.media = false,
  });
  final int count, lines;
  final bool media;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.t('loading'),
    child: Column(
      children: [
        for (var card = 0; card < count; card++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (media) ...[
                    const AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AppSkeleton(height: double.infinity, radius: 16),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const AppSkeleton(height: 18, width: 150, radius: 8),
                  const SizedBox(height: 14),
                  for (var line = 0; line < lines; line++) ...[
                    AppSkeleton(
                      height: 12,
                      width: line.isEven ? double.infinity : 190,
                      radius: 6,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class AppEntrance extends StatefulWidget {
  const AppEntrance({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<AppEntrance> createState() => _AppEntranceState();
}

class _AppEntranceState extends State<AppEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_enter.isCompleted || _enter.isAnimating || _delay != null) return;
    // Show content immediately when the system asks for reduced motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _enter.value = 1;
      return;
    }
    _delay = Timer(
      Duration(milliseconds: 45 * widget.index.clamp(0, 6)),
      () => mounted ? _enter.forward() : null,
    );
  }

  @override
  void dispose() {
    _delay?.cancel();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, .06),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic)),
      child: widget.child,
    ),
  );
}

class AppNavTile extends StatelessWidget {
  const AppNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = AppColors.primary,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .12),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: onTap,
    ),
  );
}

class AppLoading extends StatelessWidget {
  const AppLoading({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.t('loading'),
    child: const Padding(
      padding: EdgeInsets.all(48),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.hint,
    this.icon = Icons.spa_outlined,
  });
  final String title;
  final String? hint;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.canvas,
            child: Icon(icon, size: 32, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ],
      ),
    ),
  );
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppEmptyState(
        title: context.strings.error(error),
        icon: Icons.cloud_off_rounded,
      ),
      OutlinedButton.icon(
        onPressed: retry,
        icon: const Icon(Icons.refresh),
        label: Text(context.t('retry')),
      ),
    ],
  );
}

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.value,
    required this.retry,
    required this.builder,
    this.skeleton,
  });
  final AsyncValue<T> value;
  final VoidCallback retry;
  final Widget Function(T) builder;
  final Widget? skeleton;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 240),
    child: value.when(
      skipLoadingOnRefresh: false,
      data: builder,
      loading: () => skeleton ?? const AppLoading(),
      error: (error, _) => AppErrorState(error: error, retry: retry),
    ),
  );
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.onRefresh,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final scroll = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: child,
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        top: false,
        child: onRefresh == null
            ? scroll
            : RefreshIndicator(
                onRefresh: () async {
                  try {
                    await onRefresh!();
                  } on Object {
                    /* AsyncContent renders the provider's failure. */
                  }
                },
                child: scroll,
              ),
      ),
    );
  }
}

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.text,
    this.danger = false,
    this.neutral = false,
    this.icon,
  });
  final String text;
  final bool danger, neutral;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Theme.of(context).colorScheme.error
        : neutral
        ? AppColors.muted
        : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: danger
            ? const Color(0xFFFFE9E8)
            : neutral
            ? AppColors.canvas
            : const Color(0xFFE8F5F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

void showFailure(BuildContext context, Object error) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(context.strings.error(error))));

Future<bool> confirmAction(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('confirm')),
          ),
        ],
      ),
    ) ??
    false;
