import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CallListenerService {
  static final CallListenerService _instance = CallListenerService._internal();
  factory CallListenerService() => _instance;
  CallListenerService._internal();

  WebSocketChannel? _channel;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  String soldierId = "soldier_1";
  String commanderId = "commander_1";

  Future<void> init() async {
    if (_channel != null) return; // avoid re-init

    print("🔌 Soldier connecting to WebSocket...");
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8000/call/ws/$soldierId'),
    );

    _channel!.stream.listen((message) async {
      print("📨 Soldier received message: $message");
      final data = jsonDecode(message);
      final from = data['from'];
      final callType = data['call_type'];
      final payload = data['data'];

      if (payload['type'] == 'offer' && callType == 'commander_call') {
        print("📞 Soldier answering call from $from");
        await _answerCall(payload, from);
      } else if (payload['type'] == 'ice') {
        print("🧊 Soldier adding ICE candidate");
        await _peerConnection?.addCandidate(
          RTCIceCandidate(
            payload['candidate'],
            payload['sdpMid'],
            payload['sdpMLineIndex'],
          ),
        );
      }
    });
    
    print("✅ Soldier WebSocket listener initialized");
  }

  Future<void> _answerCall(Map payload, String from) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    };

    print("🎤 Getting soldier microphone...");
    _localStream ??= await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    print("🔗 Creating peer connection...");
    _peerConnection = await createPeerConnection(config);

    // Handle incoming audio from web (commander)
    _peerConnection!.onTrack = (event) {
      print("🔊 Soldier receiving audio from commander");
      // Audio will automatically play through device speakers
      // No additional setup needed in Flutter WebRTC
    };

    _peerConnection!.onIceCandidate = (candidate) {
      print("🧊 Soldier sending ICE candidate to $from");
      _channel!.sink.add(jsonEncode({
        "to": from,
        "data": {
          "type": "ice",
          "candidate": candidate.candidate,
          "sdpMid": candidate.sdpMid,
          "sdpMLineIndex": candidate.sdpMLineIndex
        },
        "call_type": "commander_call"
      }));
    };

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    print("📝 Setting remote description...");
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(payload['sdp'], payload['type']),
    );

    print("📝 Creating answer...");
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    print("📤 Soldier sending answer to $from");
    _channel!.sink.add(jsonEncode({
      "to": from,
      "data": {
        "type": "answer",
        "sdp": answer.sdp,
      },
      "call_type": "commander_call"
    }));
  }

  Future<void> dispose() async {
    await _peerConnection?.close();
    await _localStream?.dispose();
    _channel?.sink.close();
    _channel = null;
    _peerConnection = null;
    _localStream = null;
  }
}

