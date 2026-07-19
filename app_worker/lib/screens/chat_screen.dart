import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Plan §12: chat between customer and worker on an active booking. Auto-translation and
/// abuse/external-payment flagging happen server-side via eventRouter's `translate` handler
/// (§9.5), triggered automatically on message create — this screen only ever reads/creates
/// messages, never touches translatedText/aiFlagged directly.
class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String senderId;
  final String senderRole; // 'customer' | 'worker'
  /// Non-null = this worker's private pre-offer thread (plan's "ask a question before
  /// offering") rather than the normal active-job chat — see message_repository.dart.
  final String? threadWorkerId;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.senderId,
    required this.senderRole,
    this.threadWorkerId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <Message>[];
  final _textController = TextEditingController();
  RealtimeSubscription? _subscription;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = AppServices.messages.subscribeToMessages();
    _subscription!.stream.listen((event) {
      final payload = event.payload;
      if (payload['bookingId'] != widget.bookingId) return;
      if (payload['threadWorkerId'] != widget.threadWorkerId) return;
      final message = Message.fromMap(payload);
      setState(() {
        final i = _messages.indexWhere((m) => m.id == message.id);
        if (i != -1) {
          _messages[i] = message; // translation/flag update arriving after the create event
        } else {
          _messages.add(message);
        }
      });
    });
  }

  Future<void> _load() async {
    final messages = await AppServices.messages.listForBooking(
      widget.bookingId,
      threadWorkerId: widget.threadWorkerId,
    );
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(messages);
      _loading = false;
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _textController.clear();
    try {
      await AppServices.messages.sendMessage(
        bookingId: widget.bookingId,
        senderId: widget.senderId,
        senderRole: widget.senderRole,
        text: text,
        threadWorkerId: widget.threadWorkerId,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.threadWorkerId != null ? 'Ask the customer' : 'Chat')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final isMine = m.senderId == widget.senderId;
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: m.aiFlagged
                                ? Colors.red.withValues(alpha: 0.15)
                                : isMine
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMine ? 16 : 4),
                              bottomRight: Radius.circular(isMine ? 4 : 16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.text, style: TextStyle(color: isMine ? scheme.onPrimaryContainer : scheme.onSurfaceVariant)),
                              if (!isMine && m.translatedText != null && m.translatedText != m.text) ...[
                                const SizedBox(height: 4),
                                Text(
                                  m.translatedText!,
                                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
                                ),
                              ],
                              if (m.aiFlagged) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red),
                                    const SizedBox(width: 3),
                                    Text(
                                      m.flagReason ?? 'flagged for review',
                                      style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(hintText: 'Message... (never share payment details here)'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: _sending
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_upward),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
