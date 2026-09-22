import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/router/route_observer.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/polling_loop.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver, RouteAware {
  final _text = TextEditingController();
  late final PollingLoop _loop;
  AsyncValue<Conversation> _conversation = const AsyncLoading();
  Object? _pollError;
  bool _visible = true, _resumed = true, _sending = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _loop = PollingLoop(_poll);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    _visible = false;
    _sync();
  }

  @override
  void didPopNext() {
    _visible = true;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    _generation++;
    _loop.stop();
    if (_visible && _resumed) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (!_visible || !_resumed) return;
    try {
      final conversation = await ref.read(repositoryProvider).conversation();
      if (!mounted || generation != _generation) return;
      setState(() {
        _conversation = AsyncData(conversation);
        _pollError = null;
      });
      await ref.read(repositoryProvider).readChat();
      if (mounted && generation == _generation) _loop.start();
    } on Object catch (error, stack) {
      if (mounted && generation == _generation) {
        setState(() => _conversation = AsyncError(error, stack));
        _loop.stop();
      }
    }
  }

  Future<void> _poll() async {
    final current = _conversation.valueOrNull;
    final generation = _generation;
    if (current == null || !_visible || !_resumed) return;
    try {
      // Reconcile identity before polling because ERP may reassign the therapist.
      final active = await ref.read(repositoryProvider).conversation();
      if (!mounted || generation != _generation) return;
      final base = active.id == current.id ? current : active;
      final ordered = [...base.messages]..sort((a, b) => a.at.compareTo(b.at));
      final messages = await ref
          .read(repositoryProvider)
          .messages(ordered.isEmpty ? null : ordered.last.at);
      if (!mounted || generation != _generation) return;
      final merged = {
        for (final message in [
          ...base.messages,
          ...active.messages,
          ...messages,
        ])
          message.id: message,
      }.values.toList()..sort((a, b) => a.at.compareTo(b.at));
      setState(() {
        _conversation = AsyncData(Conversation(active.id, merged));
        _pollError = null;
      });
      await ref.read(repositoryProvider).readChat();
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _pollError = error);
      }
    }
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty || !_visible || !_resumed) return;
    setState(() => _sending = true);
    final submitted = _text.text;
    try {
      await ref.read(repositoryProvider).sendMessage(submitted);
      if (!mounted) return;
      if (_text.text == submitted) _text.clear();
      await _load();
    } on Object catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _loop.dispose();
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('therapist'))),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.t('chatPrivacy'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          if (_pollError != null)
            MaterialBanner(
              content: Text(context.strings.error(_pollError!)),
              actions: [
                TextButton(onPressed: _load, child: Text(context.t('retry'))),
              ],
            ),
          Expanded(
            child: _conversation.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(
                child: AppErrorState(error: e, retry: _load),
              ),
              data: (conversation) => conversation.messages.isEmpty
                  ? AppEmptyState(
                      title: context.t('emptyChat'),
                      icon: Icons.forum_outlined,
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(20),
                      itemCount: conversation.messages.length,
                      itemBuilder: (context, index) {
                        final message = conversation
                            .messages[conversation.messages.length - 1 - index];
                        return Align(
                          alignment: message.mine
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * .8,
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: message.mine
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.text,
                                  style: TextStyle(
                                    color: message.mine
                                        ? Colors.white
                                        : AppColors.primary,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  AppDates.time(
                                    message.at,
                                    Localizations.localeOf(
                                      context,
                                    ).languageCode,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: message.mine
                                        ? Colors.white70
                                        : AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (_conversation.hasValue)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: context.t('message'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    tooltip: context.t('send'),
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
