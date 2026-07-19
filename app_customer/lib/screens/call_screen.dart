import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart' as appwrite;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// In-app voice calling over WebRTC — the zero-cost alternative to real telephony-level
/// masked calling (which needs a paid proxy service like Twilio). Signaling (SDP offer/
/// answer + ICE candidates) goes through Appwrite Realtime via the `calls`/`call_candidates`
/// collections; audio flows peer-to-peer once connected.
///
/// Uses only Google's free public STUN server, no TURN relay — calls can fail to connect on
/// restrictive networks (symmetric NAT, some corporate networks) since there's no free/
/// reliable TURN hosting. This is a real, documented limitation, not a bug: unlike a real
/// phone call, both apps also need to be open for a call to connect at all (no PSTN fallback).
class CallScreen extends StatefulWidget {
  final String bookingId;
  final String myUserId;
  final String myRole; // 'customer' | 'worker'
  final String peerUserId;

  /// Non-null when answering an incoming call (skips creating a new offer).
  final Call? incomingCall;

  const CallScreen({
    super.key,
    required this.bookingId,
    required this.myUserId,
    required this.myRole,
    required this.peerUserId,
    this.incomingCall,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

const _iceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
  ],
};

class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _callId;
  String _status = 'Connecting...';
  bool _muted = false;
  bool _ended = false;
  appwrite.RealtimeSubscription? _callSub;
  appwrite.RealtimeSubscription? _candidateSub;
  final Set<String> _appliedCandidateKeys = {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      _localStream = await navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': false})
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _status =
            'Could not access the microphone — check permissions and try again',
      );
      return;
    }

    final pc = await createPeerConnection(_iceServers);
    _pc = pc;
    for (final track in _localStream!.getAudioTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (candidate) {
      final callId = _callId;
      if (callId == null || candidate.candidate == null) return;
      AppServices.calls.sendCandidate(
        callId: callId,
        senderId: widget.myUserId,
        candidate: jsonEncode({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }),
      );
    };

    pc.onConnectionState = (state) {
      if (!mounted) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _status = 'Connected');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        setState(
          () => _status =
              'Connection failed — the other side may be on a restrictive network',
        );
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        setState(() => _status = 'Disconnected');
      }
    };

    if (widget.incomingCall != null) {
      await _answer(widget.incomingCall!);
    } else {
      await _call();
    }

    _listenForSignaling();
  }

  Future<void> _call() async {
    final pc = _pc!;
    final offer = await pc.createOffer({'offerToReceiveAudio': 1});
    await pc.setLocalDescription(offer);
    final call = await AppServices.calls.createCall(
      bookingId: widget.bookingId,
      callerId: widget.myUserId,
      calleeId: widget.peerUserId,
      callerRole: widget.myRole,
      offerSdp: offer.sdp ?? '',
    );
    if (!mounted) return;
    setState(() {
      _callId = call.id;
      _status = 'Ringing...';
    });
  }

  Future<void> _answer(Call call) async {
    final pc = _pc!;
    await pc.setRemoteDescription(
      RTCSessionDescription(call.offerSdp, 'offer'),
    );
    final answer = await pc.createAnswer({'offerToReceiveAudio': 1});
    await pc.setLocalDescription(answer);
    await AppServices.calls.answerCall(
      callId: call.id,
      answerSdp: answer.sdp ?? '',
    );
    if (!mounted) return;
    setState(() {
      _callId = call.id;
      _status = 'Connecting...';
    });
  }

  void _listenForSignaling() {
    _callSub = AppServices.calls.subscribeToCalls();
    _callSub!.stream.listen((event) async {
      final payload = event.payload;
      if (payload['\$id'] != _callId) return;
      final call = Call.fromMap(payload);
      if (call.status == 'accepted' &&
          call.answerSdp != null &&
          _pc?.getRemoteDescription() == null) {
        await _pc?.setRemoteDescription(
          RTCSessionDescription(call.answerSdp, 'answer'),
        );
      } else if (call.status == 'declined' || call.status == 'ended') {
        _hangUp(notifyRemote: false);
      }
    });

    _candidateSub = AppServices.calls.subscribeToCandidates();
    _candidateSub!.stream.listen((event) async {
      final payload = event.payload;
      if (payload['callId'] != _callId) return;
      if (payload['senderId'] == widget.myUserId) return;
      final key = payload['\$id'] as String;
      if (_appliedCandidateKeys.contains(key)) return;
      _appliedCandidateKeys.add(key);
      final data =
          jsonDecode(payload['candidate'] as String) as Map<String, dynamic>;
      await _pc?.addCandidate(
        RTCIceCandidate(
          data['candidate'] as String?,
          data['sdpMid'] as String?,
          data['sdpMLineIndex'] as int?,
        ),
      );
    });
  }

  void _toggleMute() {
    final track = _localStream?.getAudioTracks().firstOrNull;
    if (track == null) return;
    setState(() => _muted = !_muted);
    track.enabled = !_muted;
  }

  Future<void> _hangUp({bool notifyRemote = true}) async {
    if (_ended) return;
    _ended = true;
    if (notifyRemote && _callId != null) {
      AppServices.calls
          .updateStatus(callId: _callId!, status: 'ended')
          .catchError((_) {});
    }
    await _callSub?.close();
    await _candidateSub?.close();
    await _pc?.close();
    _localStream?.getTracks().forEach((t) => t.stop());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _callSub?.close();
    _candidateSub?.close();
    _pc?.close();
    _localStream?.getTracks().forEach((t) => t.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.person, size: 96, color: Colors.white54),
              const SizedBox(height: 24),
              Text(
                _status,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: Icon(
                      _muted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                    ),
                    onPressed: _toggleMute,
                  ),
                  const SizedBox(width: 32),
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: _hangUp,
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
