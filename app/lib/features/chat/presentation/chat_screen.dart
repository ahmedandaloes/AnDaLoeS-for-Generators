import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

final _messagesProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, rentalRequestId) {
  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('rental_request_id', rentalRequestId)
      .order('created_at')
      .map((rows) => rows.cast<Map<String, dynamic>>());
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
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _sending = true);
    _controller.clear();
    try {
      await supabase.from('messages').insert({
        'rental_request_id': widget.rentalRequestId,
        'sender_id': uid,
        'body': body,
      });
      HapticFeedback.lightImpact();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'),
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
    final uid = supabase.auth.currentUser?.id ?? '';
    final messagesAsync =
        ref.watch(_messagesProvider(widget.rentalRequestId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherPartyName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Chat', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet.\nSay hello to ${widget.otherPartyName}!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg['sender_id'] == uid;
                    final showDate = i == 0 ||
                        _dayOf(msg['created_at']) !=
                            _dayOf(messages[i - 1]['created_at']);

                    return Column(
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _formatDay(msg['created_at']),
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
                        color: cs.outlineVariant.withValues(alpha: 0.4))),
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    maxLength: 500,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      filled: true,
                      fillColor: cs.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
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
                          child: const Icon(Icons.send_rounded, size: 20),
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

  static String _formatDay(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day) {
        return 'Today';
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.year == yesterday.year &&
          dt.month == yesterday.month &&
          dt.day == yesterday.day) {
        return 'Yesterday';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
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
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft:
                isMe ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight:
                isMe ? const Radius.circular(4) : const Radius.circular(18),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
