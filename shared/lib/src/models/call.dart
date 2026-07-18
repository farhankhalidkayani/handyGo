/// Mirrors the `calls` collection — WebRTC signaling for in-app voice calls (the free
/// alternative to real telephony-level masked calling, which needs a paid proxy service).
/// `offerSdp`/`answerSdp` are the WebRTC session descriptions; ICE candidates trickle in
/// separately via `call_candidates` since they arrive over time from both sides.
class Call {
  final String id;
  final String bookingId;
  final String callerId;
  final String calleeId;
  final String callerRole;
  final String status; // ringing | accepted | declined | ended
  final String? offerSdp;
  final String? answerSdp;

  const Call({
    required this.id,
    required this.bookingId,
    required this.callerId,
    required this.calleeId,
    required this.callerRole,
    this.status = 'ringing',
    this.offerSdp,
    this.answerSdp,
  });

  factory Call.fromMap(Map<String, dynamic> map) => Call(
        id: map['\$id'] as String,
        bookingId: map['bookingId'] as String,
        callerId: map['callerId'] as String,
        calleeId: map['calleeId'] as String,
        callerRole: map['callerRole'] as String,
        status: map['status'] as String? ?? 'ringing',
        offerSdp: map['offerSdp'] as String?,
        answerSdp: map['answerSdp'] as String?,
      );
}
