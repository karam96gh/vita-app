import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';
import '../../program/domain/program_summary.dart';
import '../../program/presentation/exercise_widgets.dart';
import '../../program/presentation/program_screen.dart';

/// Exercises prescribed in one treatment session (reached from session history).
class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: context.t('exercises'),
    onRefresh: () async {
      ref.invalidate(exercisesProvider(sessionId));
      await ref.read(exercisesProvider(sessionId).future);
    },
    child: AsyncContent(
      value: ref.watch(exercisesProvider(sessionId)),
      retry: () => ref.invalidate(exercisesProvider(sessionId)),
      skeleton: const AppListSkeleton(count: 3, lines: 1),
      builder: (items) {
        if (items.isEmpty) {
          return AppEmptyState(title: context.t('emptyExercises'));
        }
        final summary = ProgramSummary.of(items, DateTime.now());
        final next = summary.next;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (next != null) ...[
              StartProgramButton(
                label: context.t(
                  summary.started ? 'continueExercises' : 'startSession',
                ),
                onPressed: () => startPlayer(
                  context,
                  startId: next.id,
                  sessionId: sessionId,
                ),
              ),
              const SizedBox(height: 24),
            ],
            ExerciseList(items: items),
          ],
        );
      },
    ),
  );
}

class SkipSheet extends ConsumerStatefulWidget {
  const SkipSheet({super.key});
  @override
  ConsumerState<SkipSheet> createState() => _SkipSheetState();
}

class _SkipSheetState extends ConsumerState<SkipSheet> {
  SkipReason? _reason;
  final _note = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('reason'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          AsyncContent(
            value: ref.watch(skipReasonsProvider),
            retry: () => ref.invalidate(skipReasonsProvider),
            builder: (reasons) => reasons.isEmpty
                ? AppEmptyState(title: context.t('empty'))
                : Column(
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _reason?.id,
                        decoration: InputDecoration(
                          labelText: context.t('reason'),
                        ),
                        items: reasons
                            .map(
                              (r) => DropdownMenuItem(
                                value: r.id,
                                child: Text(
                                  r.localizedLabel(
                                    Localizations.localeOf(
                                      context,
                                    ).languageCode,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) => setState(
                          () => _reason = reasons.firstWhere((r) => r.id == id),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: context.t(
                            _reason?.isOther == true ? 'reasonText' : 'note',
                          ),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            context.t(_error!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: context.t('confirm'),
                        onPressed: () {
                          final error = Validation.skip(_reason, _note.text);
                          if (error != null) {
                            setState(() => _error = error);
                            return;
                          }
                          Navigator.pop(context, (
                            reason: _reason!,
                            note: _note.text,
                          ));
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
