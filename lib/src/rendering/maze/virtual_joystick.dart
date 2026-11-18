import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_design_tokens.dart';

/// Responsive, zero-latency analog virtual joystick built on raw Pointer events
/// for instant touch-down response, smooth direction switching, and crisp visual feedback.
class VirtualJoystick extends StatefulWidget {
  final double size;
  final bool hapticsEnabled;
  final void Function(double dx, double dy) onChanged;

  const VirtualJoystick({
    super.key,
    this.size = 128,
    this.hapticsEnabled = true,
    required this.onChanged,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  int? _activePointerId;
  Offset _knobOffset = Offset.zero;
  double _normDx = 0.0;
  double _normDy = 0.0;
  bool _isActive = false;

  void _handlePointer(Offset localPos, {bool isInitialTouch = false}) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final maxDist = widget.size * 0.34;
    final delta = localPos - center;
    final dist = delta.distance;

    Offset clamped;
    if (dist > maxDist && dist > 0) {
      clamped = Offset(delta.dx / dist * maxDist, delta.dy / dist * maxDist);
    } else {
      clamped = delta;
    }

    final nx = (clamped.dx / maxDist).clamp(-1.0, 1.0);
    final ny = (clamped.dy / maxDist).clamp(-1.0, 1.0);

    if (isInitialTouch && widget.hapticsEnabled) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }

    setState(() {
      _knobOffset = clamped;
      _normDx = nx;
      _normDy = ny;
      _isActive = true;
    });

    widget.onChanged(nx, ny);
  }

  void _release() {
    _activePointerId = null;
    if (_isActive || _knobOffset != Offset.zero) {
      setState(() {
        _knobOffset = Offset.zero;
        _normDx = 0.0;
        _normDy = 0.0;
        _isActive = false;
      });
      widget.onChanged(0.0, 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final knobSize = widget.size * 0.44;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_activePointerId != null) return;
        _activePointerId = e.pointer;
        _handlePointer(e.localPosition, isInitialTouch: true);
      },
      onPointerMove: (e) {
        if (e.pointer != _activePointerId) return;
        _handlePointer(e.localPosition);
      },
      onPointerUp: (e) {
        if (e.pointer != _activePointerId) return;
        _release();
      },
      onPointerCancel: (e) {
        if (e.pointer != _activePointerId) return;
        _release();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft translucent circular pad with directional indicators
            AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.92),
                    AppDesignTokens.deepNavy.withOpacity(_isActive ? 0.11 : 0.07),
                  ],
                ),
                border: Border.all(
                  color: _isActive
                      ? AppDesignTokens.coralPrimary.withOpacity(0.85)
                      : AppDesignTokens.deepNavy.withOpacity(0.22),
                  width: _isActive ? 3.0 : 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppDesignTokens.deepNavy.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _JoystickDirectionsPainter(
                  normDx: _normDx,
                  normDy: _normDy,
                  isActive: _isActive,
                ),
              ),
            ),

            // Animated draggable thumb knob
            Transform.translate(
              offset: _knobOffset,
              child: AnimatedScale(
                scale: _isActive ? 1.07 : 1.0,
                duration: const Duration(milliseconds: 90),
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isActive
                          ? const [Color(0xFFFF9580), Color(0xFFE8553F)]
                          : const [
                              Color(0xFFFF8A75),
                              AppDesignTokens.coralPrimary
                            ],
                    ),
                    border: Border.all(color: Colors.white, width: 3.0),
                    boxShadow: [
                      BoxShadow(
                        color: (_isActive
                                ? AppDesignTokens.coralPrimary
                                : AppDesignTokens.deepNavy)
                            .withOpacity(0.35),
                        blurRadius: _isActive ? 12 : 7,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.open_with_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoystickDirectionsPainter extends CustomPainter {
  final double normDx;
  final double normDy;
  final bool isActive;

  _JoystickDirectionsPainter({
    required this.normDx,
    required this.normDy,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.39;

    // Subtle inner guide ring
    canvas.drawCircle(
      c,
      size.width * 0.25,
      Paint()
        ..color = AppDesignTokens.deepNavy.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final dirs = <({double angle, bool lit})>[
      (angle: 0.0, lit: isActive && normDx > 0.35), // Right
      (angle: math.pi / 2, lit: isActive && normDy > 0.35), // Down
      (angle: math.pi, lit: isActive && normDx < -0.35), // Left
      (angle: -math.pi / 2, lit: isActive && normDy < -0.35), // Up
    ];

    for (final d in dirs) {
      canvas.save();
      canvas.translate(
        c.dx + math.cos(d.angle) * r,
        c.dy + math.sin(d.angle) * r,
      );
      canvas.rotate(d.angle);
      final tri = Path()
        ..moveTo(6.5, 0)
        ..lineTo(-3.5, -5.2)
        ..lineTo(-3.5, 5.2)
        ..close();
      canvas.drawPath(
        tri,
        Paint()
          ..color = d.lit
              ? AppDesignTokens.coralPrimary
              : AppDesignTokens.deepNavy.withOpacity(0.28)
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _JoystickDirectionsPainter oldDelegate) =>
      oldDelegate.normDx != normDx ||
      oldDelegate.normDy != normDy ||
      oldDelegate.isActive != isActive;
}
