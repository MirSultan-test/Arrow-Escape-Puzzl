import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../controllers/maze_game_controller.dart';
import '../models/maze/maze_level.dart';
import 'gameplay_screen.dart';

/// Illustrated 5-District World Map with a winding delivery road and star-rated level nodes.
class LevelSelectScreen extends StatefulWidget {
  final MazeGameController controller;

  const LevelSelectScreen({super.key, required this.controller});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  late int _selectedDistrict;

  @override
  void initState() {
    super.initState();
    final currentId = widget.controller.saveData.mazeCurrentLevelId;
    _selectedDistrict = MazeDistrictInfo.forLevel(currentId).id;
  }

  void _openLevel(int levelId) {
    widget.controller.audioController.playTap();
    widget.controller.selectLevel(levelId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameplayScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final district = MazeDistrictInfo.forDistrict(_selectedDistrict);
        final districtLevels = widget.controller.levels
            .where((l) => l.district == _selectedDistrict)
            .toList();

        int districtStars = 0;
        int districtDone = 0;
        for (final l in districtLevels) {
          districtStars += widget.controller.bestStarsForLevel(l.id);
          if (widget.controller.saveData.mazeCompletedLevels.contains(l.id)) {
            districtDone++;
          }
        }

        return Scaffold(
          backgroundColor: Color(district.skyBgHex),
          appBar: AppBar(
            backgroundColor: Color(district.skyBgHex),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppDesignTokens.deepNavy),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Delivery World Map',
                style: AppDesignTokens.titleMedium),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.goldenYellow.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppDesignTokens.goldenYellow),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 16, color: Color(0xFFE09F1F)),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.controller.totalStars}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: AppDesignTokens.deepNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // 5-District Horizontal Biome Selector
                SizedBox(
                  height: 54,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    itemCount: MazeDistrictInfo.all.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final d = MazeDistrictInfo.all[idx];
                      final selected = d.id == _selectedDistrict;
                      final unlocked =
                          widget.controller.isLevelUnlocked(d.startLevel);
                      return GestureDetector(
                        onTap: () {
                          widget.controller.audioController.playTap();
                          setState(() => _selectedDistrict = d.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? Color(d.wallTopHex)
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? Color(d.wallSideHex)
                                  : AppDesignTokens.surfaceBorder,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                unlocked
                                    ? _iconForDistrict(d.id)
                                    : Icons.lock_rounded,
                                size: 17,
                                color: selected
                                    ? Colors.white
                                    : (unlocked
                                        ? Color(d.wallTopHex)
                                        : Colors.grey),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${d.id}. ${d.name}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? Colors.white
                                      : AppDesignTokens.deepNavy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Active District Illustrated Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(district.wallTopHex),
                          Color(district.wallSideHex),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Color(district.wallSideHex).withOpacity(0.32),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _iconForDistrict(district.id),
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DISTRICT ${district.id} • ${district.name.toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                district.subtitle,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEAF7EE),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$districtDone/10',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 14,
                                    color: AppDesignTokens.goldenYellow),
                                Text(
                                  ' $districtStars/30',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignTokens.goldenYellow,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Winding Delivery Road Map for the 10 District Levels
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        const rowHeight = 86.0;
                        final totalHeight = districtLevels.length * rowHeight + 24;

                        // Precompute winding road coordinates for each node
                        final centers = <Offset>[];
                        for (int i = 0; i < districtLevels.length; i++) {
                          final wave = math.sin(i * 0.95) * (w * 0.27);
                          final cx = (w / 2) + wave;
                          final cy = 44.0 + i * rowHeight;
                          centers.add(Offset(cx, cy));
                        }

                        return SizedBox(
                          height: totalHeight,
                          child: Stack(
                            children: [
                              // Winding cobblestone delivery road painter
                              CustomPaint(
                                size: Size(w, totalHeight),
                                painter: _WindingRoadPainter(
                                  points: centers,
                                  roadColor: Color(district.floorDarkHex),
                                  borderColor: Color(district.wallTopHex),
                                ),
                              ),

                              // Interactive level nodes along the road
                              for (int i = 0; i < districtLevels.length; i++)
                                _buildLevelNode(
                                  level: districtLevels[i],
                                  center: centers[i],
                                  district: district,
                                  maxWidth: w,
                                ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildLevelNode({
    required MazeLevel level,
    required Offset center,
    required MazeDistrictInfo district,
    required double maxWidth,
  }) {
    final unlocked = widget.controller.isLevelUnlocked(level.id);
    final completed =
        widget.controller.saveData.mazeCompletedLevels.contains(level.id);
    final stars = widget.controller.bestStarsForLevel(level.id);
    final isCurrent = level.id == widget.controller.highestUnlockedLevel;
    final isBoss = level.id % 10 == 0;

    final nodeColor = !unlocked
        ? const Color(0xFFD5DADF)
        : (isCurrent
            ? AppDesignTokens.coralPrimary
            : (completed ? Color(district.wallTopHex) : AppDesignTokens.goldenYellow));

    final placeLabelRight = center.dx < maxWidth * 0.52;

    return Positioned(
      left: 0,
      right: 0,
      top: center.dy - 34,
      child: SizedBox(
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Node circle button
            Positioned(
              left: center.dx - 32,
              top: 0,
              child: GestureDetector(
                onTap: unlocked ? () => _openLevel(level.id) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: nodeColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent
                              ? Colors.white
                              : (isBoss
                                  ? AppDesignTokens.goldenYellow
                                  : Colors.white.withOpacity(0.85)),
                          width: isCurrent ? 4 : 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppDesignTokens.deepNavy.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: unlocked
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isBoss)
                                    const Icon(Icons.emoji_events_rounded,
                                        size: 14,
                                        color: AppDesignTokens.goldenYellow),
                                  Text(
                                    '${level.id}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : const Icon(Icons.lock_rounded,
                                color: Color(0xFF7B8A9C), size: 22),
                      ),
                    ),
                    // Stars strip beneath node
                    if (unlocked)
                      Transform.translate(
                        offset: const Offset(0, -6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppDesignTokens.surfaceBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(3, (s) {
                              return Icon(
                                s < stars
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 12,
                                color: s < stars
                                    ? AppDesignTokens.goldenYellow
                                    : const Color(0xFFCBD5E1),
                              );
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Title badge neatly tucked to the open side of the winding path
            Positioned(
              left: placeLabelRight ? center.dx + 40 : 6,
              right: placeLabelRight ? 6 : (maxWidth - center.dx + 40),
              top: 12,
              child: GestureDetector(
                onTap: unlocked ? () => _openLevel(level.id) : null,
                child: Align(
                  alignment: placeLabelRight
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(unlocked ? 0.94 : 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? AppDesignTokens.coralPrimary
                            : AppDesignTokens.surfaceBorder,
                        width: isCurrent ? 1.8 : 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: placeLabelRight
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          level.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: unlocked
                                ? AppDesignTokens.deepNavy
                                : const Color(0xFF7B8A9C),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${level.foods.length} foods • ${level.monsters.length} monsters',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7B8F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForDistrict(int id) {
    switch (id) {
      case 1:
        return Icons.eco_rounded;
      case 2:
        return Icons.storefront_rounded;
      case 3:
        return Icons.forest_rounded;
      case 4:
        return Icons.terrain_rounded;
      case 5:
        return Icons.location_city_rounded;
      default:
        return Icons.map_rounded;
    }
  }
}

class _WindingRoadPainter extends CustomPainter {
  final List<Offset> points;
  final Color roadColor;
  final Color borderColor;

  _WindingRoadPainter({
    required this.points,
    required this.roadColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midY = (p0.dy + p1.dy) / 2;
      path.cubicTo(p0.dx, midY, p1.dx, midY, p1.dx, p1.dy);
    }

    // Outer road edge
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round,
    );

    // Cobblestone road body
    canvas.drawPath(
      path,
      Paint()
        ..color = roadColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round,
    );

    // Center white dashed road line
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WindingRoadPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.roadColor != roadColor;
}
