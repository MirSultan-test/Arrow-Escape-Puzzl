/// An immutable (row, col) coordinate on the puzzle grid.
/// Row 0 is the top edge; Column 0 is the left edge.
class GridPosition {
  final int row;
  final int col;

  const GridPosition(this.row, this.col);

  GridPosition offset(int deltaRow, int deltaCol) =>
      GridPosition(row + deltaRow, col + deltaCol);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row, $col)';
}
