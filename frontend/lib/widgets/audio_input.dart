import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/controllers/audio_controller.dart';

bool isAudioEnabled = false;

class AudioInput extends StatefulWidget {
  const AudioInput({
    super.key,
    required this.onStopRecordingAudio,
    required this.audioController,
  });

  final void Function(File audioFile) onStopRecordingAudio;
  final AudioController audioController;

  @override
  State<AudioInput> createState() => _AudioInputState();
}

class _AudioInputState extends State<AudioInput> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  @override
  void initState() {
    super.initState();
    isAudioEnabled = false;
    _initializeRecorder();

    // Register the stop recording function with the controller
    widget.audioController.setStopRecordingFunction(_stopRecording);
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _initializeRecorder() async {
    try {
      final status = await Permission.microphone.request();
      print('🎤 Microphone permission: $status');

      await _recorder.openRecorder();
      print('🎤 Recorder initialized successfully');
    } catch (e) {
      print('❌ Error initializing recorder: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

      print('🎤 Starting recording to: $filePath');
      await _recorder.startRecorder(toFile: filePath);

      setState(() {
        isAudioEnabled = true;
      });
      print('🎤 Recording started, UI updated');
    } catch (e) {
      print('❌ Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      print('🎤 Stopping recording...');
      final filePath = await _recorder.stopRecorder();

      setState(() {
        isAudioEnabled = false;
      });
      print('🎤 Recording stopped, UI updated');

      if (filePath == null) {
        print('❌ No recording URL returned');
        return;
      }

      print('✅ Audio saved to: $filePath');
      widget.onStopRecordingAudio(File(filePath));
    } catch (e) {
      print('❌ Error stopping recording: $e');
      setState(() {
        isAudioEnabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isAudioEnabled
          ? Colors.deepOrangeAccent.shade200
          : Colors.tealAccent.shade400,
      shape: const CircleBorder(),
      elevation: 6,
      child: IconButton(
        icon: Icon(
          isAudioEnabled ? Icons.mic : Icons.mic_off,
          size: 30,
        ),
        color: Colors.white,
        onPressed: isAudioEnabled ? _stopRecording : _startRecording,
        tooltip: isAudioEnabled ? 'Stop Recording' : 'Start Audio',
      ),
    );
  }
}
