import '../models/parcel.dart';

/// Fast 2D spatial indexing structure for parcel lookup and placement.
class BoardMatrix {
  final int rows;
  final int cols;
  final Map<String, Parcel> _idMap = {};
  late final List<List<Parcel?>> _grid;

  BoardMatrix({required this.rows, required this.cols}) {
    assert(rows > 0 && cols > 0, 'Grid dimensions must be positive');
    _grid = List.generate(rows, (_) => List<Parcel?>.filled(cols, null));
  }

  bool isInside(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  Parcel? getAt(int r, int c) {
    if (!isInside(r, c)) return null;
    return _grid[r][c];
  }

  Parcel? getById(String id) => _idMap[id];

  List<Parcel> get allParcels => _idMap.values.toList(growable: false);

  int get parcelCount => _idMap.length;

  bool get isEmpty => _idMap.isEmpty;

  bool get isNotEmpty => _idMap.isNotEmpty;

  /// Places a parcel. Throws if the cell is already occupied or coordinates out of bounds.
  void place(Parcel parcel) {
    if (!isInside(parcel.row, parcel.col)) {
      throw ArgumentError(
        'Coordinate (${parcel.row}, ${parcel.col}) is out of bounds for ${rows}x$cols grid',
      );
    }
    final existingAtPos = _grid[parcel.row][parcel.col];
    if (existingAtPos != null && existingAtPos.id != parcel.id) {
      throw StateError(
        'Cell (${parcel.row}, ${parcel.col}) is already occupied by parcel ${existingAtPos.id}',
      );
    }
    _grid[parcel.row][parcel.col] = parcel;
    _idMap[parcel.id] = parcel;
  }

  /// Removes and returns the parcel with [id], or null if not found.
  Parcel? removeById(String id) {
    final parcel = _idMap.remove(id);
    if (parcel != null) {
      _grid[parcel.row][parcel.col] = null;
    }
    return parcel;
  }

  /// Clears the entire matrix.
  void clear() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        _grid[r][c] = null;
      }
    }
    _idMap.clear();
  }

  /// Clones the current board matrix.
  BoardMatrix clone() {
    final copy = BoardMatrix(rows: rows, cols: cols);
    for (final p in _idMap.values) {
      copy.place(p);
    }
    return copy;
  }
}
