import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/program_summary.dart';
import 'exercise_widgets.dart';

class ProgramScreen extends ConsumerWidget {
  const ProgramScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: context.t('program'),
    onRefresh: () async {
      ref.invalidate(programProvider);
      await ref.read(programProvider.future);
    },
    child: AsyncContent(
      value: ref.watch(programProvider),
      retry: () => ref.invalidate(programProvider),
      skeleton: const AppListSkeleton(count: 4, lines: 1),
      builder: (items) {
        if (items.isEmpty) {
          return AppEmptyState(
            title: context.t('noProgram'),
            hint: context.t('noProgramHint'),
          );
        }
        final summary = ProgramSummary.of(items, DateTime.now());
        final next = summary.next;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (next != null) ...[
              StartProgramButton(
                label: context.t(
                  summary.started ? 'continueExercises' : 'startExercises',
                ),
                onPressed: () => startPlayer(context, startId: next.id),
              ),
              const SizedBox(height: 24),
            ],
            ExerciseList(
              items: items,
              showSession: true,
              sessions: ref.watch(sessionsProvider).valueOrNull,
            ),
          ],
        );
      },
    ),
  );
}

void startPlayer(
  BuildContext context, {
  String? startId,
  String? sessionId,
  bool autoStart = false,
}) {
  context.push(
    playerLocation(
      startId: startId,
      sessionId: sessionId,
      autoStart: autoStart,
    ),
  );
}

String playerLocation({
  String? startId,
  String? sessionId,
  bool autoStart = false,
}) {
  final query = {
    'start': ?startId,
    'session': ?sessionId,
    if (autoStart) 'auto': '1',
  };
  return Uri(path: '/play', queryParameters: query).toString();
}

class StartProgramButton extends StatelessWidget {
  const StartProgramButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.success,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 56),
    ),
    onPressed: onPressed,
    icon: const Icon(Icons.play_arrow_rounded),
    label: Text(label),
  );
}
