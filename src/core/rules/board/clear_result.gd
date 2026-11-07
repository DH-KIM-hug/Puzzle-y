## Result of [method BoardRules.clear_cells]: the new board and the cells that
## were actually emptied, row-major.
class_name ClearResult
extends RefCounted

## New board (the input board is untouched).
var board: BoardState
## Cells emptied, row-major.
var cleared: Array[ClearedCell] = []
