/// Mirrors the `notifications` collection (§5.9). Named `AppNotification` to avoid clashing
/// with Flutter's own `Notification` widget type.
class AppNotification {
  final String id;
  final String userId;
  final String role;
  final String type;
  final String title;
  final String? body;
  final String? bookingId;
  final bool read;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.role,
    required this.type,
    required this.title,
    this.body,
    this.bookingId,
    this.read = false,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['\$id'] as String,
        userId: map['userId'] as String,
        role: map['role'] as String,
        type: map['type'] as String,
        title: map['title'] as String,
        body: map['body'] as String?,
        bookingId: map['bookingId'] as String?,
        read: map['read'] as bool? ?? false,
      );
}
