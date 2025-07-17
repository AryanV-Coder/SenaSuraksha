import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class TrialCallScreen extends StatefulWidget {
  const TrialCallScreen({super.key});

  @override
  State<TrialCallScreen> createState() => _TrialCallScreenState();
}

class _TrialCallScreenState extends State<TrialCallScreen> {
  bool isCallConnecting = false;
  bool isCallConnected = false;
  bool isReceivingCall = false;

  late IO.Socket socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final String selfId = "soldier1"; // Ideally generate or auth this
  String? callerId;

  @override
  void initState() {
    super.initState();
    initSocket();
  }

  void initSocket() {
    socket = IO.io('https://senasuraksha.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
    });

    socket.onConnect((_) {
      print('Connected to signaling server');
      socket.emit('join', selfId);
    });

    socket.on('offer', (data) async {
      callerId = data['from'];
      showIncomingCallPopup();
    });

    socket.on('answer', (data) async {
      var answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );
      await _peerConnection?.setRemoteDescription(answer);
      setState(() {
        isCallConnected = true;
        isCallConnecting = false;
      });
    });

    socket.on('ice-candidate', (data) async {
      await _peerConnection?.addCandidate(
        RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        ),
      );
    });

    // OPTIONAL: Handle remote end call
    socket.on('end-call', (_) {
      endCall();
    });
  }

  void toggleCall() async {
    setState(() {
      isCallConnecting = true;
    });

    await startCall();
  }

  void showIncomingCallPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: Text("📞 Incoming Call"),
          content: Text("Someone is calling you..."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                answerCall();
              },
              child: Text("Accept"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Optional: Notify rejection
              },
              child: Text("Reject"),
            ),
          ],
        );
      },
    );
  }

  Future<void> startCall() async {
    callerId = "commander"; // The peer's selfId

    await initializePeerConnection();

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    socket.emit('offer', {
      'offer': offer.toMap(),
      'to': callerId, // 👈 IMPORTANT
    });
  }

  Future<void> answerCall() async {
    await initializePeerConnection();

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    socket.emit('answer', {'answer': answer.toMap(), 'to': callerId});

    setState(() {
      isCallConnected = true;
      isCallConnecting = false;
    });
  }

  Future<void> initializePeerConnection() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(configuration);
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true});
    _peerConnection!.addStream(_localStream!);

    _peerConnection!.onIceCandidate = (candidate) {
      if (callerId != null) {
        socket.emit('ice-candidate', {
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          'to': callerId,
        });
      }
    };
  }

  Future<void> endCall() async {
    await _localStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
    _localStream = null;

    socket.emit('end-call', {'to': callerId});

    setState(() {
      isCallConnecting = false;
      isCallConnected = false;
      callerId = null;
    });
  }

  @override
  void dispose() {
    _peerConnection?.dispose();
    _localStream?.dispose();
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(title: Text("Trial Caller")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCallConnected)
              IconButton(
                onPressed: toggleCall,
                icon: Icon(Icons.mic, size: 50, color: Colors.yellow),
              ),
            if (isCallConnected)
              IconButton(
                onPressed: endCall,
                icon: Icon(Icons.call_end, size: 50, color: Colors.red),
              ),
            const SizedBox(height: 10),
            if (isCallConnecting)
              Text(
                "Connecting...",
                style: TextStyle(color: Colors.white, fontSize: 20),
              )
            else if (isCallConnected)
              Text(
                "✅ Call Connected",
                style: TextStyle(color: Colors.greenAccent, fontSize: 20),
              ),
          ],
        ),
      ),
    );
  }
}
