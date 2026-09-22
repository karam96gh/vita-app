import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/api_failure.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';

class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  final _note = TextEditingController();
  int _score = 0;
  bool _busy = false, _done = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(PatientSession session) async {
    if (_busy || !Validation.rating(_score, session.attendanceConfirmed)) {
      return;
    }
    if (!await confirmAction(context, context.t('submitRating')) || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).rate(session, _score, _note.text);
      _note.clear();
      if (mounted) setState(() => _done = true);
    } on Object catch (error) {
      if (error is ApiFailure &&
          error.code == 'RATING_ALREADY_EXISTS' &&
          mounted) {
        setState(() => _done = true);
      }
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: context.t('rate'),
    child: _done
        ? AppEmptyState(
            title: context.t('ratingThanks'),
            icon: Icons.check_circle_outline,
          )
        : AsyncContent(
            value: ref.watch(sessionsProvider),
            retry: () => ref.invalidate(sessionsProvider),
            builder: (sessions) {
              final matches = sessions.where((s) => s.id == widget.sessionId);
              if (matches.isEmpty || !matches.first.attendanceConfirmed) {
                return AppEmptyState(title: context.t('SESSION_NOT_COMPLETED'));
              }
              final session = matches.first;
              if (session.alreadyRated == true) {
                return AppEmptyState(title: context.t('RATING_ALREADY_EXISTS'));
              }
              return AppCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(context.t('ratingTitle'), style: AppTypography.title),
                    const SizedBox(height: 16),
                    Text(
                      context.t('ratingPrivacy'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        for (var score = 1; score <= 5; score++)
                          IconButton(
                            tooltip: '$score / 5',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _score = score),
                            icon: Icon(
                              score <= _score
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: AppColors.accent,
                              size: 36,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _note,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: context.t('privateNote'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: context.t('submitRating'),
                      busy: _busy,
                      onPressed: _score > 0 ? () => _submit(session) : null,
                    ),
                  ],
                ),
              );
            },
          ),
  );
}
