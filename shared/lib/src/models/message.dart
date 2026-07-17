/// Mirrors the `messages` collection (§5.8). `translatedText`/`detectedLang`/`aiFlagged`/
/// `flagReason` are written server-side by eventRouter's `translate` handler (§9.5), triggered
/// automatically on create — never set by the client.
class Message {
  final String id;
  final String bookingId;
  final String senderId;
  final String senderRole;
  final String text;
  final String? translatedText;
  final String? detectedLang;
  final bool aiFlagged;
  final String? flagReason;

  const Message({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    this.translatedText,
    this.detectedLang,
    this.aiFlagged = false,
    this.flagReason,
  });

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['\$id'] as String,
        bookingId: map['bookingId'] as String,
        senderId: map['senderId'] as String,
        senderRole: map['senderRole'] as String,
        text: map['text'] as String? ?? '',
        translatedText: map['translatedText'] as String?,
        detectedLang: map['detectedLang'] as String?,
        aiFlagged: map['aiFlagged'] as bool? ?? false,
        flagReason: map['flagReason'] as String?,
      );
}
