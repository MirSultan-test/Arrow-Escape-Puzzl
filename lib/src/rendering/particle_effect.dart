import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Celebration burst on puzzle completion.
class CelebrationOverlay extends StatefulWidget {
  final bool reducedMotion;
  final VoidCallback onComplete;

  const CelebrationOverlay({
    super.key,
    required this.reducedMotion,
    required this.onComplete,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.reducedMotion ? 400 : 1200),
    );

    if (!widget.reducedMotion) {
      final rand = math.Random();
      final colors = [
        const Color(0xFFF59E0B),
        const Color(0xFF10B981),
        const Color(0xFF3B82F6),
        const Color(0xFFEC4899),
        const Color(0xFF8B5CF6),
      ];
      for (int i = 0; i < 28; i++) {
        _particles.add(_Particle(
          x: 0.5 + (rand.nextDouble() * 0.4 - 0.2),
          y: 0.45,
          vx: (rand.nextDouble() * 2 - 1) * 350,
          vy: -rand.nextDouble() * 320 - 100,
          gravity: 520,
          size: rand.nextDouble() * 8 + 6,
          color: colors[rand.nextInt(colors.length)],
          rotationSpeed: (rand.nextDouble() * 2 - 1) * 8,
        ));
      }
    }

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reducedMotion) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return CustomPaint(
            size: Size.infinite,
            painter: _ParticlePainter(particles: _particles, progress: t),
          );
        },
      ),
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double gravity;
  final double size;
  final Color color;
  final double rotationSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.size,
    required this.color,
    required this.rotationSpeed,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final time = progress * 1.2;
      final px = p.x * size.width + p.vx * time;
      final py = p.y * size.height + p.vy * time + 0.5 * p.gravity * time * time;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotationSpeed * progress);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.7),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
