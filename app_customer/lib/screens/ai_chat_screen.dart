import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'ai_intake_screen.dart';

class _ChatMessage {
  final String text;
  final bool fromUser;

  _ChatMessage(this.text, this.fromUser);
}

/// Plan §12/§9.4: C1 — multilingual chatbot. Free-form conversation via aiRouter's `chat`
/// feature; ends with a "Book Service" shortcut into the AI intake flow (§9.3), matching the
/// system prompt's own instruction to suggest booking once a problem is described.
class AiChatScreen extends StatefulWidget {
  final UserProfile profile;

  const AiChatScreen({super.key, required this.profile});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _messageController = TextEditingController();
  final _messages = <_ChatMessage>[];
  bool _sending = false;

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text, true));
      _sending = true;
      _messageController.clear();
    });
    try {
      final result = await AppServices.bookings.getAiChatReply(message: text);
      setState(() => _messages.add(_ChatMessage(result['reply'] as String? ?? '...', false)));
    } catch (e) {
      setState(() => _messages.add(_ChatMessage('Sorry, something went wrong: $e', false)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => AiIntakeScreen(profile: widget.profile)),
            ),
            child: const Text('Book Service', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                return Align(
                  alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: m.fromUser
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
          if (_sending) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Type a message...'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _sending ? null : _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
