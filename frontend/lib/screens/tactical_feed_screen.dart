import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/widgets/camera_input.dart';
import 'package:frontend/widgets/voice_bar_visualizer.dart.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:audioplayers/audioplayers.dart';

class TacticalFeedScreen extends StatefulWidget {
  const TacticalFeedScreen({super.key});

  @override
  State<TacticalFeedScreen> createState() => _TacticalFeedScreenState();
}

class _TacticalFeedScreenState extends State<TacticalFeedScreen> {
  bool _isSpeaking = false;

  void _onSendData({File? videoFile, File? audioFile}) async {
    try {
      // Your backend URL (replace with your actual ngrok URL)
      var uri = Uri.parse(
        "https://senasuraksha.onrender.com/ai-analysis/soldier-feed",
      );
      var request = http.MultipartRequest('POST', uri);

      // Add video file if provided
      if (videoFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'video',
            videoFile.path,
            filename: path.basename(videoFile.path),
          ),
        );
      }

      // Add audio file if provided
      if (audioFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'audio',
            audioFile.path,
            filename: path.basename(audioFile.path),
          ),
        );
      }

      print("🚀 Sending data to backend...");
      var response = await request.send();

      if (response.statusCode == 200) {
        print("✅ Data sent successfully!");

        try {
          // Get the audio response from backend
          var audioBytes = await response.stream.toBytes();

          final player = AudioPlayer();

          setState(() {
            _isSpeaking = true;
          });

          // Add delay to ensure file is fully written
          await Future.delayed(Duration(milliseconds: 500));

          await player.play(BytesSource(audioBytes));
          print("🎵 Playing audio response...");

          // Stop animation when audio finishes
          player.onPlayerComplete.listen((event) {
            setState(() {
              _isSpeaking = false;
            });
          });
        } catch (audioError) {
          print("❌ Error playing audio: $audioError");
        }
      } else {
        print("❌ Failed to send data: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error sending data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CameraInput(onSendData: _onSendData),
          Positioned(
            bottom: 120,
            right: MediaQuery.of(context).size.width / 2 - 20,
            child: VoiceBarVisualizer(isSpeaking: _isSpeaking),
          ),
        ],
      ),
    );
  }
}
