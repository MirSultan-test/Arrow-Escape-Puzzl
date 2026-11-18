import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/direction.dart';

/// Builds crisp, resolution-independent vector paths for directional parcel arrows.
class ArrowPathBuilder {
  const ArrowPathBuilder();

  /// Constructs a distinct arrow path centered in a box of [size] x [size],
  /// rotated towards [direction].
  /// Designed with a broad arrowhead, prominent shaft, and notched tail
  /// so direction is unmistakable even in monochrome.
  static Path buildArrowPath({
    required Size size,
    required Direction direction,
    double scale = 0.58,
  }) {
    final center = Offset(size.width / 2, size.height / 2);
    final dimension = math.min(size.width, size.height) * scale;
    final half = dimension / 2;

    // Define un-rotated arrow pointing RIGHT:
    // Left side is tail, right side is tip (+half, 0).
    final path = Path();

    final tipX = half;
    const tipY = 0.0;
    final headBackX = half * 0.15;
    final headWingY = half * 0.78;
    final shaftTopY = half * 0.32;
    final tailX = -half;
    final tailNotchX = -half * 0.65;

    // Start at arrow tip
    path.moveTo(tipX, tipY);
    // Right upper wing
    path.lineTo(headBackX, -headWingY);
    // Upper shaft join
    path.lineTo(headBackX, -shaftTopY);
    // Upper shaft to tail
    path.lineTo(tailX, -shaftTopY);
    // Tail center notch
    path.lineTo(tailNotchX, 0.0);
    // Lower shaft from tail
    path.lineTo(tailX, shaftTopY);
    // Lower shaft join
    path.lineTo(headBackX, shaftTopY);
    // Lower wing
    path.lineTo(headBackX, headWingY);
    path.close();

    // Rotate matrix around center based on direction
    final matrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..rotateZ(direction.angleRadians);

    return path.transform(matrix.storage);
  }
}
