import 'dart:convert';
import 'dart:io';
import '../lib/src/engine/puzzle_engine.dart';
import '../lib/src/models/level_data.dart';

void main() {
  final file = File('assets/levels/levels.json');
  final json = jsonDecode(file.readAsStringSync());
  final levels = (json['levels'] as List).map((l) => LevelData.fromJson(l)).toList();
  final l26 = levels.firstWhere((l) => l.id == 26);
  print('Level 26: ${l26.rows}x${l26.cols}, parcels: ${l26.parcels.length}');
  final engine = PuzzleEngine(rows: l26.rows, cols: l26.cols, parcels: l26.parcels);
  final clear = engine.findClearParcels();
  print('Clear parcels count: ${clear.length}');
  for (final p in clear) {
    print('  - ${p.id} at (${p.row}, ${p.col}) dir: ${p.direction.name}');
  }
}
