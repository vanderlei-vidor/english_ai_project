import 'package:flutter/material.dart';
import 'dart:math';

class VoiceOrb extends StatefulWidget {
  final String state;
  final double soundLevel;

  const VoiceOrb({super.key, required this.state, required this.soundLevel});

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _waveController;
  late List<Map<String, double>> particles;

  @override
  void initState() {
    super.initState();

    particles = List.generate(12, (index) {
      return {
        "size": 2.0 + random.nextDouble() * 4,
        "offset": 80 + random.nextDouble() * 100,
        "angle": random.nextDouble() * pi * 2,
        "opacity": 0.2 + random.nextDouble() * 0.5,
      };
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _waveController.dispose();
    super.dispose();
  }

  double getScale() {
    switch (widget.state) {
      case "listening":
        return 1.25;

      case "thinking":
        return 1.1;

      case "speaking":
        return 1.35;

      default:
        return 1.0;
    }
  }

  Color getColor() {
    switch (widget.state) {
      case "listening":
        return Colors.lightBlueAccent;

      case "thinking":
        return Colors.cyanAccent;

      case "speaking":
        return Colors.deepPurpleAccent;

      default:
        return const Color(0xFF334155);
    }
  }

  final random = Random();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,

      builder: (context, child) {
        final audioBoost = (widget.soundLevel / 50).clamp(0.0, 0.5);

        final pulse = 1 + (_controller.value * 0.08) + audioBoost;

        return Transform.scale(
          scale: getScale() * pulse,

          child: Transform.rotate(
            angle: _controller.value * 0.15,

            child: Stack(
              alignment: Alignment.center,

              children: [
                // 🌌 FLOATING PARTICLES
                ...List.generate(12, (index) {
                  final particle = particles[index];

                  final size = particle["size"]!;
                  final offset = particle["offset"]!;
                  final angle = particle["angle"]!;
                  final opacity = particle["opacity"]!;
                  

                  final dx = cos(angle) * offset;
                  final dy = sin(angle) * offset;

                  final movement = sin((_controller.value * pi) + index);

                  return Transform.translate(
                    offset: Offset(dx + movement * 2, dy + movement * 2),

                    child: Opacity(
                      opacity: opacity,

                      child: Container(
                        width: size,
                        height: size,

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          color: getColor(),

                          boxShadow: [
                            BoxShadow(color: getColor(), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                // 🌌 ENERGY WAVES
                AnimatedBuilder(
                  animation: _waveController,

                  builder: (context, child) {
                    final extraWave = widget.state == "speaking" ? 0.5 : 0.0;

                    final waveScale =
                        1 + (_waveController.value * 1.5) + extraWave;

                    final opacity = (1 - _waveController.value) * 0.4;

                    return Transform.scale(
                      scale: waveScale,

                      child: Container(
                        width: 140,
                        height: 140,

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          border: Border.all(
                            color: getColor().withOpacity(opacity),
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 🌌 MAIN ORB
                Container(
                  width: 140,
                  height: 140,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    gradient: RadialGradient(
                      colors: [
                        getColor().withOpacity(0.95),
                        getColor().withOpacity(0.5),
                        Colors.black,
                      ],

                      stops: const [0.2, 0.6, 1],
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: getColor().withOpacity(0.7),
                        blurRadius: 50,
                        spreadRadius: 15,
                      ),

                      BoxShadow(
                        color: Colors.white.withOpacity(0.15),
                        blurRadius: 25,
                        spreadRadius: -8,
                      ),
                    ],
                  ),

                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,

                      decoration: BoxDecoration(
                        shape: BoxShape.circle,

                        color: Colors.white.withOpacity(0.25),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.4),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
