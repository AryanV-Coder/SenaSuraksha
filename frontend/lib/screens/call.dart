import 'package:flutter/material.dart';
import 'dart:math' as math;

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  bool _isRecording = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    try {
      _waveController = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      );
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      // If there's an error, try again after a frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeControllers();
        }
      });
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _waveController.dispose();
      _pulseController.dispose();
    }
    super.dispose();
  }

  void _toggleRecording() {
    if (!_isInitialized) return;
    
    setState(() {
      _isRecording = !_isRecording;
    });
    
    if (_isRecording) {
      _waveController.repeat();
      _pulseController.repeat();
    } else {
      _waveController.stop();
      _pulseController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1C),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3B82F6),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_waveController, _pulseController]),
          builder: (context, child) {
            return CustomPaint(
              painter: WavePainter(
                waveAnimation: _waveController.value,
                pulseAnimation: _pulseController.value,
                isRecording: _isRecording,
              ),
              size: Size(
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height,
              ),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated glow effect behind mic
                    if (_isRecording)
                      Transform.scale(
                        scale: 1.0 + (math.sin(_pulseController.value * 2 * math.pi) * 0.15 + 0.15),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF3B82F6).withOpacity(0.6),
                                const Color(0xFF3B82F6).withOpacity(0.3),
                                const Color(0xFF3B82F6).withOpacity(0.1),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.4, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),
                    // Second glow layer
                    if (_isRecording)
                      Transform.scale(
                        scale: 1.0 + (math.sin(_pulseController.value * 2 * math.pi) * 0.25 + 0.25),
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF60A5FA).withOpacity(0.4),
                                const Color(0xFF60A5FA).withOpacity(0.2),
                                const Color(0xFF60A5FA).withOpacity(0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.3, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                    // Main mic button
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E3A8A).withOpacity(0.3),
                          border: Border.all(
                            color: const Color(0xFF3B82F6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mic,
                          color: Color(0xFF60A5FA),
                          size: 50,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double waveAnimation;
  final double pulseAnimation;
  final bool isRecording;

  WavePainter({
    required this.waveAnimation,
    required this.pulseAnimation,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    if (isRecording) {
      // Draw animated wave rings
      for (int i = 0; i < 8; i++) {
        _drawWaveRing(canvas, center, i, size);
      }
    }
  }

  void _drawWaveRing(Canvas canvas, Offset center, int ringIndex, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Calculate wave properties
    final baseRadius = 150.0 + (ringIndex * 40);
    final waveOffset = (waveAnimation * 2 * math.pi) + (ringIndex * 0.5);
    final opacity = (1.0 - (ringIndex / 8.0)) * 0.6;
    
    // Create path for wavy ring
    final path = Path();
    final points = 60;
    
    for (int i = 0; i <= points; i++) {
      final angle = (i / points) * 2 * math.pi;
      final waveAmplitude = 15.0 * math.sin(waveOffset + angle * 3);
      final radius = baseRadius + waveAmplitude;
      
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Gradient colors based on position
    final isTopHalf = ringIndex < 4;
    if (isTopHalf) {
      // Blue gradient for top rings
      paint.color = Color.lerp(
        const Color(0xFF3B82F6),
        const Color(0xFF1E40AF),
        ringIndex / 4.0,
      )!.withOpacity(opacity);
    } else {
      // Purple/pink gradient for bottom rings
      paint.color = Color.lerp(
        const Color(0xFF8B5CF6),
        const Color(0xFFEC4899),
        (ringIndex - 4) / 4.0,
      )!.withOpacity(opacity);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}