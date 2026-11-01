import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

  /// Messages shown immediately while the server confirms them.
  final List<_Pending> _pending = [];
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
      if (conversation.unreadCount > 0) ref.invalidate(conversationProvider);
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
      // `after` is strictly greater-than on the server; overlap by a second so
      // a message sharing the last timestamp is not lost (merge dedupes by id).
      final messages = await ref
          .read(repositoryProvider)
          .messages(
            ordered.isEmpty
                ? null
                : ordered.last.at.subtract(const Duration(seconds: 1)),
          );
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
        _conversation = AsyncData(Conversation(active.id, merged, 0));
        _pollError = null;
      });
      await ref.read(repositoryProvider).readChat();
      if (active.unreadCount > 0) ref.invalidate(conversationProvider);
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _pollError = error);
      }
    }
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty || !_visible || !_resumed) return;
    HapticFeedback.lightImpact();
    final pending = _Pending(_text.text, DateTime.now());
    _text.clear();
    setState(() => _pending.add(pending));
    await _deliver(pending);
  }

  Future<void> _deliver(_Pending pending) async {
    setState(() {
      _sending = true;
      pending.failed = false;
    });
    try {
      await ref.read(repositoryProvider).sendMessage(pending.text);
      if (!mounted) return;
      await _load();
      if (mounted) setState(() => _pending.remove(pending));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => pending.failed = true);
      showFailure(context, error);
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
    appBar: AppBar(
      title: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFE8F5F0),
            child: Icon(
              Icons.medical_services_outlined,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('therapist'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        context.t('chatPrivacyShort'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          if (_pollError != null)
            MaterialBanner(
              content: Text(context.strings.error(_pollError!)),
              actions: [
                TextButton(onPressed: _load, child: Text(context.t('retry'))),
              ],
            ),
          Expanded(
            child: _conversation.when(
              loading: () => const _ChatSkeleton(),
              error: (e, _) => Center(
                child: AppErrorState(error: e, retry: _load),
              ),
              data: (conversation) =>
                  conversation.messages.isEmpty && _pending.isEmpty
                  ? AppEmptyState(
                      title: context.t('emptyChat'),
                      hint: context.t('chatPrivacy'),
                      icon: Icons.forum_outlined,
                    )
                  : _MessageList(
                      messages: conversation.messages,
                      pending: _pending,
                      onRetry: (pending) {
                        if (!_sending) _deliver(pending);
                      },
                    ),
            ),
          ),
          if (_conversation.hasValue)
            _Composer(controller: _text, sending: _sending, onSend: _send),
        ],
      ),
    ),
  );
}

class _Pending {
  _Pending(this.text, this.at);
  final String text;
  final DateTime at;
  bool failed = false;
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.pending,
    required this.onRetry,
  });
  final List<ChatMessage> messages;
  final List<_Pending> pending;
  final ValueChanged<_Pending> onRetry;
  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final ordered = [...messages]..sort((a, b) => a.at.compareTo(b.at));
    final rows = <Widget>[];
    DateTime? day;
    for (final message in ordered) {
      final local = message.at.toLocal();
      final current = DateTime(local.year, local.month, local.day);
      if (current != day) {
        day = current;
        rows.add(_DayChip(DateFormat.MMMMEEEEd(language).format(current)));
      }
      rows.add(_Bubble(message: message));
    }
    for (final item in pending) {
      rows.add(
        _Bubble(
          message: ChatMessage('', item.text, item.at, true),
          pending: !item.failed,
          failed: item.failed,
          onRetry: () => onRetry(item),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: rows.length,
      itemBuilder: (_, index) => rows[rows.length - 1 - index],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECF3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    this.pending = false,
    this.failed = false,
    this.onRetry,
  });
  final ChatMessage message;
  final bool pending, failed;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final bubble = Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: failed
              ? AppColors.danger
              : mine
              ? AppColors.primary
              : Colors.white,
          boxShadow: mine ? null : AppShadows.soft,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(18),
            topEnd: const Radius.circular(18),
            bottomStart: Radius.circular(mine ? 18 : 4),
            bottomEnd: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: mine ? Colors.white : AppColors.primary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 4),
            if (pending || failed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    failed
                        ? Icons.error_outline_rounded
                        : Icons.schedule_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      context.t(failed ? 'messageFailed' : 'messageSending'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                AppDates.time(
                  message.at,
                  Localizations.localeOf(context).languageCode,
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: mine ? Colors.white70 : AppColors.muted,
                ),
              ),
          ],
        ),
      ),
    );
    if (!failed) return pending ? Opacity(opacity: .7, child: bubble) : bubble;
    return Semantics(
      button: true,
      child: GestureDetector(onTap: onRetry, child: bubble),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) {
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F1D2452),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: context.t('message'),
                  filled: true,
                  fillColor: AppColors.canvas,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: pill,
                  enabledBorder: pill,
                  focusedBorder: pill.copyWith(
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size(48, 48),
              ),
              tooltip: context.t('send'),
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final (end, width) in [
        (false, 220.0),
        (true, 160.0),
        (false, 250.0),
        (true, 190.0),
        (false, 140.0),
      ])
        Align(
          alignment: end
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppSkeleton(height: 44, width: width, radius: 18),
          ),
        ),
    ],
  );
}
