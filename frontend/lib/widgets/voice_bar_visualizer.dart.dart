import 'package:flutter/material.dart';

class VoiceBarVisualizer extends StatefulWidget {
  const VoiceBarVisualizer({super.key, required this.isSpeaking});

  final bool isSpeaking;

  @override
  State<VoiceBarVisualizer> createState() => _VoiceBarVisualizerState();
}

class _VoiceBarVisualizerState extends State<VoiceBarVisualizer>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + index * 100),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 8,
        end: 30,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();
  }

  void _startAnimations() {
    for (var controller in _controllers) {
      controller.repeat(reverse: true);
    }
  }

  void _stopAnimations() {
    for (var controller in _controllers) {
      controller.stop();
      controller.reset();
    }
  }

  @override
  void didUpdateWidget(covariant VoiceBarVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !oldWidget.isSpeaking) {
      _startAnimations();
    } else if (!widget.isSpeaking && oldWidget.isSpeaking) {
      _stopAnimations();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: !widget.isSpeaking
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _animations[index],
                  builder: (context, child) {
                    return Container(
                      width: 6,
                      height: _animations[index].value,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                );
              }),
            ),
    );
  }
}
