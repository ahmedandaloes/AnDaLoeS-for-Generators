import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../../core/widgets/app_error_state.dart';
import '../../../l10n/app_localizations.dart';
import '../data/repositories/message_repository.dart';

final _messagesProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, rentalRequestId) {
  return ref
      .read(messageRepositoryProvider)
      .messagesStream(rentalRequestId);
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.rentalRequestId,
    required this.otherPartyName,
  });
  final String rentalRequestId;
  final String otherPartyName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;
  bool _otherTyping = false;
  int _lastMessageCount = 0;
  Timer? _typingClearTimer;
  RealtimeChannel? _typingChannel;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(messageRepositoryProvider).currentUserId ?? '';
    _controller.addListener(_onTextChanged);
    _subscribeTyping();
  }

  void _subscribeTyping() {
    final repo = ref.read(messageRepositoryProvider);
    _typingChannel = repo
        .typingChannel(
          widget.rentalRequestId,
          onTyping: (payload) {
            final sender = payload['uid']?.toString();
            if (sender == null || sender == _uid) return;
            if (mounted) {
              setState(() => _otherTyping = true);
              _typingClearTimer?.cancel();
              _typingClearTimer =
                  Timer(const Duration(seconds: 3), () {
                if (mounted) setState(() => _otherTyping = false);
              });
            }
          },
        )
        .subscribe();
  }

  void _onTextChanged() {
    if (_controller.text.isNotEmpty) {
      _typingChannel?.sendBroadcastMessage(
          event: 'typing', payload: {'uid': _uid});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingClearTimer?.cancel();
    _typingChannel?.unsubscribe();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    if (_uid.isEmpty) return;

    setState(() => _sending = true);
    _controller.clear();
    try {
      await ref.read(messageRepositoryProvider).insertMessage(
            rentalRequestId: widget.rentalRequestId,
            senderId: _uid,
            body: body,
          );
      HapticFeedback.lightImpact();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.failedToSend),
              behavior: SnackBarBehavior.floating),
        );
        _controller.text = body;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final messagesAsync =
        ref.watch(_messagesProvider(widget.rentalRequestId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherPartyName,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _otherTyping
                  ? Text(
                      l.typing,
                      key: const ValueKey('typing'),
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.primary,
                          fontStyle: FontStyle.italic),
                    )
                  : Text(
                      l.chatLabel,
                      key: const ValueKey('chat'),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => const AppErrorState(),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color:
                                cs.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          l.noMessagesYet(widget.otherPartyName),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                // Only auto-scroll when new messages arrive — not on every
                // rebuild (which would fight the user scrolling up).
                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                  itemCount:
                      messages.length + (_otherTyping ? 1 : 0),
                  itemBuilder: (context, i) {
                    // Typing indicator bubble at end
                    if (_otherTyping && i == messages.length) {
                      return _TypingBubble(cs: cs);
                    }

                    final msg = messages[i];
                    final isMe = msg['sender_id'] == _uid;
                    final showDate = i == 0 ||
                        _dayOf(msg['created_at']) !=
                            _dayOf(messages[i - 1]['created_at']);

                    return Column(
                      children: [
                        if (showDate)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _formatDay(msg['created_at'], l),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        _MessageBubble(
                          body: msg['body']?.toString() ?? '',
                          isMe: isMe,
                          time: msg['created_at']?.toString() ?? '',
                          cs: cs,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                    top: BorderSide(
                        color:
                            cs.outlineVariant.withValues(alpha: 0.4))),
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    maxLength: 500,
                    buildCounter: (_,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: l.typeMessage,
                      filled: true,
                      fillColor: cs.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _sending
                      ? SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: cs.primary),
                        )
                      : FilledButton(
                          onPressed: _send,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            minimumSize: const Size(44, 44),
                          ),
                          child:
                              const Icon(Icons.send_rounded, size: 20),
                        ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static String _dayOf(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      return '${dt.year}-${dt.month}-${dt.day}';
    } catch (_) {
      return '';
    }
  }

  static String _formatDay(dynamic ts, AppLocalizations l) {
    // uses l.today/l.yesterday
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day) return l.today;
      final y = now.subtract(const Duration(days: 1));
      if (dt.year == y.year && dt.month == y.month && dt.day == y.day) {
        return l.yesterday;
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble({required this.cs});
  final ColorScheme cs;

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.cs.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                final v =
                    ((_anim.value + i / 3) % 1.0);
                final scale = 0.6 + 0.4 * (v < 0.5 ? v * 2 : (1 - v) * 2);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: widget.cs.onSurfaceVariant
                            .withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.body,
    required this.isMe,
    required this.time,
    required this.cs,
  });

  final String body;
  final bool isMe;
  final String time;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final timeStr = _fmt(time);
    return Align(
      alignment:
          isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(18),
            topEnd: const Radius.circular(18),
            bottomStart: isMe
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomEnd: isMe
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? cs.onPrimary : cs.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? cs.onPrimary.withValues(alpha: 0.7)
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}
