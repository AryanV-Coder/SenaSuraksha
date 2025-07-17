import 'package:flutter/material.dart';
import 'package:frontend/screens/call.dart';
import 'package:frontend/screens/tactical_feed_screen.dart';
import 'package:camera/camera.dart';
import 'package:frontend/screens/trial_call.dart';

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // // Initialize the call listener service
  // await CallListenerService().init();
  
  cameras = await availableCameras();

  runApp(
    MaterialApp(
      theme: ThemeData().copyWith(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color.fromARGB(255, 5, 19, 36),
        ),
      ),
      home: PageView(
        scrollDirection: Axis.horizontal,
        children: const [TacticalFeedScreen(), TrialCallScreen(),CallScreen()],
      ),
    ),
  );
}
