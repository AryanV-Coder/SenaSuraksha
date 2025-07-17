import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:permission_handler/permission_handler.dart';

class TrialCallScreen extends StatefulWidget {
  const TrialCallScreen({super.key});

  @override
  State<TrialCallScreen> createState() => _TrialCallScreenState();
}

class _TrialCallScreenState extends State<TrialCallScreen> {
  bool isCallConnecting = false;
  bool isCallConnected = false;
  bool isReceivingCall = false;

  IO.Socket? socket; // Make nullable - don't connect immediately
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final String selfId = "soldier1"; // Ideally generate or auth this
  String? callerId;

  @override
  void initState() {
    super.initState();
    // Don't auto-connect - only connect when user starts a call
  }

  Future<void> initSocket() async {
    if (socket?.connected == true) {
      return; // Already connected
    }

    try {
      socket = IO.io('https://senasuraksha.onrender.com', <String, dynamic>{
        'transports': ['websocket'],
        'timeout': 20000,
      });

      return await Future(() {
        socket!.onConnect((_) {
          print('Connected to signaling server');
          socket!.emit('join', selfId);
        });

        socket!.onConnectError((error) {
          print('Socket connection error: $error');
        });

        socket!.onDisconnect((_) {
          print('Disconnected from signaling server');
        });

        socket!.on('offer', (data) async {
          try {
            callerId = data['from'];
            showIncomingCallPopup();
          } catch (e) {
            print('Error handling offer: $e');
          }
        });

        socket!.on('answer', (data) async {
          try {
            var answer = RTCSessionDescription(
              data['answer']['sdp'],
              data['answer']['type'],
            );
            await _peerConnection?.setRemoteDescription(answer);
            setState(() {
              isCallConnected = true;
              isCallConnecting = false;
            });
          } catch (e) {
            print('Error handling answer: $e');
          }
        });

        socket!.on('ice-candidate', (data) async {
          try {
            await _peerConnection?.addCandidate(
              RTCIceCandidate(
                data['candidate']['candidate'],
                data['candidate']['sdpMid'],
                data['candidate']['sdpMLineIndex'],
              ),
            );
          } catch (e) {
            print('Error handling ICE candidate: $e');
          }
        });

        // OPTIONAL: Handle remote end call
        socket!.on('end-call', (_) {
          endCall();
        });
      });
    } catch (e) {
      print('Error initializing socket: $e');
    }
  }

  void toggleCall() async {
    // Check and request permissions first
    final micPermission = await Permission.microphone.request();
    
    if (micPermission != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Microphone permission is required for calling'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isCallConnecting = true;
    });

    try {
      // Connect to signaling server first
      await initSocket();
      await startCall();
    } catch (e) {
      print('Error starting call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start call: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isCallConnecting = false;
      });
    }
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
    try {
      callerId = "commander"; // The peer's selfId

      await initializePeerConnection();

      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      socket!.emit('offer', {
        'offer': offer.toMap(),
        'to': callerId, // 👈 IMPORTANT
      });
    } catch (e) {
      print('Error in startCall: $e');
      rethrow;
    }
  }

  Future<void> answerCall() async {
    await initializePeerConnection();

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    socket!.emit('answer', {'answer': answer.toMap(), 'to': callerId});

    setState(() {
      isCallConnected = true;
      isCallConnecting = false;
    });
  }

  Future<void> initializePeerConnection() async {
    try {
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan', // Explicitly use Unified Plan
      };

      _peerConnection = await createPeerConnection(configuration);
      
      // Get user media with error handling
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false, // Set to false since you're only doing audio calls
        });
      } catch (e) {
        print('Error getting user media: $e');
        throw Exception('Failed to access microphone: $e');
      }
      
      // Use addTrack instead of addStream (Unified Plan)
      _localStream!.getAudioTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onIceCandidate = (candidate) {
        if (callerId != null && socket?.connected == true) {
          socket!.emit('ice-candidate', {
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
            'to': callerId,
          });
        }
      };

      // Add connection state monitoring
      _peerConnection!.onConnectionState = (state) {
        print('WebRTC Connection State: $state');
      };

    } catch (e) {
      print('Error initializing peer connection: $e');
      rethrow;
    }
  }

  Future<void> endCall() async {
    await _localStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
    _localStream = null;

    if (socket?.connected == true && callerId != null) {
      socket!.emit('end-call', {'to': callerId});
    }

    // Disconnect socket when call ends
    if (socket?.connected == true) {
      socket!.disconnect();
      socket = null;
    }

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
    socket?.disconnect();
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
