import 'dart:io';
import 'dart:ui'; // Import for ImageFilter
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:frontend/widgets/audio_input.dart';
import 'package:frontend/controllers/audio_controller.dart';
import 'package:frontend/main.dart';

class CameraInput extends StatefulWidget {
  const CameraInput({super.key, required this.onSendData});

  final void Function({File? videoFile, File? audioFile}) onSendData;

  @override
  State<CameraInput> createState() => _CameraInputState();
}

class _CameraInputState extends State<CameraInput> with WidgetsBindingObserver {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late CameraDescription _currentCamera; // 🔄 track current camera

  // Add AudioController to manage audio recording
  final AudioController audioController = AudioController();

  File? _recordedVideo;
  File? _recordedAudio;

  bool isVideoEnabled = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentCamera = cameras.first; // start with back camera
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  void _onStopRecordingAudio(File audioFile) {
    _recordedAudio = audioFile;
  }

  void _showMessage({required String content, required Color color}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: Duration(seconds: 3),
        content: Text(content),
        showCloseIcon: true,
        backgroundColor: color,
      ),
    );
  }

  void _sendData() async {
    setState(() {
      _isSending = true;
    });

    if (_recordedAudio == null &&
        _recordedVideo == null &&
        !isAudioEnabled &&
        !isVideoEnabled) {
      _showMessage(
        content: "Record audio or video before sending !!",
        color: Colors.red,
      );
    } else if (isAudioEnabled || isVideoEnabled) {
      if (isVideoEnabled) {
        _stopVideoRecording();
      }
      if (isAudioEnabled) {
        await audioController.stopRecording();
      }

      if (_recordedAudio == null) {
        widget.onSendData(videoFile: _recordedVideo);
      } else if (_recordedVideo == null) {
        widget.onSendData(audioFile: _recordedAudio);
      } else {
        widget.onSendData(videoFile: _recordedVideo, audioFile: _recordedAudio);
      }
      _showMessage(
        content: "Data sent successfully",
        color: Colors.green,
      );
    } else {
      if (_recordedAudio == null) {
        widget.onSendData(videoFile: _recordedVideo);
      } else if (_recordedVideo == null) {
        widget.onSendData(audioFile: _recordedAudio);
      } else {
        widget.onSendData(videoFile: _recordedVideo, audioFile: _recordedAudio);
      }

      _showMessage(
        content: "Data sent successfully",
        color: Colors.green,
      );
    }

    setState(() {
      _recordedVideo = null;
      _recordedAudio = null;
      _isSending = false;
    });
  }

  void _initializeCamera() {
    _controller = CameraController(
      _currentCamera,
      ResolutionPreset.high,
      enableAudio: true,
    );
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  void _flipCamera() async {
    final lensDirection = _currentCamera.lensDirection;

    final newCamera = cameras.firstWhere(
      (camera) => camera.lensDirection != lensDirection,
      orElse: () => cameras.first,
    );

    // Dispose current controller before switching
    await _controller.dispose();

    setState(() {
      _currentCamera = newCamera;
      _controller = CameraController(
        _currentCamera,
        ResolutionPreset.max,
        enableAudio: true,
      );
      _initializeControllerFuture = _controller.initialize();
    });
  }

  void _startVideoRecording() async {
    await _controller.startVideoRecording();
    setState(() {
      isVideoEnabled = true;
    });
  }

  void _stopVideoRecording() async {
    final XFile videoFile = await _controller.stopVideoRecording();
    setState(() {
      _recordedVideo = File(videoFile.path);
      isVideoEnabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeControllerFuture,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Stack(
          children: [
            Positioned.fill(child: CameraPreview(_controller)),
            // Frosted glass effect for button column
            Positioned(
              bottom: 60,
              right: 18,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Flip camera
                        Material(
                          color: const Color.fromARGB(255, 49, 126, 250),
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: IconButton(
                            icon: const Icon(
                              Icons.flip_camera_android_rounded,
                              size: 28,
                            ),
                            color: Colors.white,
                            onPressed: _flipCamera,
                            tooltip: 'Switch Camera',
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Record/Stop video
                        Material(
                          color: isVideoEnabled
                              ? Colors.redAccent.shade200
                              : Colors.greenAccent.shade400,
                          shape: const CircleBorder(),
                          elevation: 6,
                          child: IconButton(
                            icon: Icon(
                              isVideoEnabled
                                  ? Icons.stop_rounded
                                  : Icons.videocam_rounded,
                              size: 30,
                            ),
                            color: Colors.white,
                            onPressed: () {
                              isVideoEnabled
                                  ? _stopVideoRecording()
                                  : _startVideoRecording();
                            },
                            tooltip: isVideoEnabled
                                ? 'Stop Recording'
                                : 'Start Video',
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Audio record button
                        AudioInput(
                          onStopRecordingAudio: _onStopRecordingAudio,
                          audioController: audioController,
                        ),
                        const SizedBox(height: 18),
                        // Send button
                        Material(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: const CircleBorder(),
                          elevation: 6,
                          child: IconButton(
                            icon: _isSending
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 28),
                            color: Colors.white,
                            onPressed: _isSending ? null : _sendData,
                            tooltip: 'Send Data',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Optional top label
            Positioned(
              top: 50,
              left: MediaQuery.of(context).size.width / 2 - 87,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  "SOLDIER'S FEED",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
