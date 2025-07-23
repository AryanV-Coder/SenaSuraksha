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
  Map<String, dynamic>? _incomingOffer; // Store incoming offer

  @override
  void initState() {
    super.initState();
    // Register immediately for incoming calls
    _registerForIncomingCalls();
  }

  Future<void> _registerForIncomingCalls() async {
    try {
      await initSocket();
      print("Registered for incoming calls");
    } catch (e) {
      print("Failed to register for incoming calls: $e");
    }
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

      // Set up event listeners immediately, not in Future
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
          print('📞 Received offer from: ${data['from']}');
          callerId = data['from'];
          // Store the offer data for later use
          _incomingOffer = data['offer'];
          showIncomingCallPopup();
        } catch (e) {
          print('Error handling offer: $e');
        }
      });

      socket!.on('answer', (data) async {
        try {
          print('📞 Received answer from: ${data['from']}');
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

      socket!.on('end-call', (data) {
        print('📞 Received end-call from: ${data['from']}');
        endCall();
      });

      // Handle call rejection - FIXED!
      socket!.on('call-rejected', (data) {
        print('🚫 MOBILE: Received call-rejected event: $data');
        print('🚫 MOBILE: From user: ${data['from']}');
        
        if (mounted) {
          setState(() {
            isCallConnecting = false;
            isCallConnected = false;
            callerId = null;
          });
          
          // Clean up connection resources
          _localStream?.dispose();
          _peerConnection?.close();
          _peerConnection = null;
          _localStream = null;
          _incomingOffer = null;
          
          // Show user feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call was rejected'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          
          print('🚫 MOBILE: UI updated after call rejection');
        }
      });

      print('✅ Socket event listeners set up successfully');
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
      // Ensure connected to signaling server (should already be connected)
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
              onPressed: () async {
                Navigator.pop(context);
                
                // Request microphone permission before answering
                final micPermission = await Permission.microphone.request();
                if (micPermission != PermissionStatus.granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Microphone permission is required to answer calls'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                setState(() {
                  isCallConnecting = true;
                });
                
                try {
                  await answerCall();
                } catch (e) {
                  print('Error answering call: $e');
                  setState(() {
                    isCallConnecting = false;
                  });
                }
              },
              child: Text("Accept"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                print('🚫 MOBILE: Rejecting call from: $callerId');
                
                // Send rejection notification
                if (socket?.connected == true && callerId != null) {
                  socket!.emit('call-rejected', {'to': callerId});
                  print('🚫 MOBILE: Sent call-rejected to: $callerId');
                  print('🚫 MOBILE: Socket connected: ${socket?.connected}');
                } else {
                  print('🚫 MOBILE: Cannot send rejection - socket connected: ${socket?.connected}, callerId: $callerId');
                }
                
                // Clean up state
                setState(() {
                  isCallConnecting = false;
                  isCallConnected = false;
                });
                callerId = null;
                _incomingOffer = null;
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
    try {
      await initializePeerConnection();

      // Set remote description from stored offer
      if (_incomingOffer != null) {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(_incomingOffer!['sdp'], _incomingOffer!['type'])
        );
      }

      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      socket!.emit('answer', {'answer': answer.toMap(), 'to': callerId});

      setState(() {
        isCallConnected = true;
        isCallConnecting = false;
      });
    } catch (e) {
      print('Error in answerCall: $e');
      setState(() {
        isCallConnecting = false;
      });
      rethrow;
    }
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

      // Handle incoming audio stream
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print("Received remote audio track");
        if (event.streams.isNotEmpty) {
          // Remote audio will be played automatically through the device speaker
          print("Remote stream added: ${event.streams[0].id}");
        }
      };

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

    // DON'T disconnect socket - keep registered for incoming calls
    // socket stays connected so user can receive future calls

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
            if (!isCallConnected && !isCallConnecting)
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
                "✅ Call Connected - Ready to Talk!",
                style: TextStyle(color: Colors.greenAccent, fontSize: 20),
              )
            else
              Text(
                "Ready to receive calls",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
