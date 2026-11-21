## Pure board & piece rules (design/gdd/board-rules.md, ADR-0001 Decision 1).
##
## Stateless static functions. Inputs are never mutated; every changing operation
## returns a new [BoardState]. Precondition violations ("assert" in the GDD) are
## reported with [method @GlobalScope.push_error] and the input is returned
## unchanged — see the error-message constants below.
class_name BoardRules
extends RefCounted

## Axis id for row queries.
const AXIS_ROW := 0
## Axis id for column queries.
const AXIS_COL := 1

## push_error text for [method place] on an invalid anchor.
const ERR_PLACE_INVALID := "BoardRules.place: can_place is false"
## push_error text for [method fill_cells] on an occupied cell.
const ERR_FILL_OCCUPIED := "BoardRules.fill_cells: target cell is occupied"


## Absolute cells a piece would cover at [param anchor] (shape offset order).
## Cells may lie off the board.
static func piece_cells(piece: PieceInstance, anchor: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o: Vector2i in piece.shape.offsets:
		out.append(anchor + o)
	return out


## board-rules rule 7 / F2: every target cell is on the board and not blocking.
static func can_place(board: BoardState, piece: PieceInstance, anchor: Vector2i) -> bool:
	if piece == null or piece.shape == null or piece.shape.offsets.is_empty():
		return false
	for o: Vector2i in piece.shape.offsets:
		var r := anchor.x + o.x
		var c := anchor.y + o.y
		if not board.in_bounds(r, c):
			return false
		if board.blocks_placement(board.index_of(r, c)):
			return false
	return true


## board-rules rule 8: returns a new board with the piece written as
## [code]TILE(origin = PIECE)[/code]; only offset [code]face_index[/code] is a face.
## On an invalid placement reports [constant ERR_PLACE_INVALID] and returns a copy
## of the input.
static func place(board: BoardState, piece: PieceInstance, anchor: Vector2i, placement_id: int) -> BoardState:
	var out := board.copy()
	if not can_place(board, piece, anchor):
		push_error(ERR_PLACE_INVALID)
		return out
	var offsets := piece.shape.offsets
	for i: int in offsets.size():
		var idx := out.index_of(anchor.x + offsets[i].x, anchor.y + offsets[i].y)
		var face := piece.has_face() and i == piece.face_index
		out.set_tile(idx, piece.crew_id, face, BoardState.ORIGIN_PIECE, placement_id)
	return out


## board-rules rule 9 / F3: completed rows ascending, then columns ascending.
static func full_lines(board: BoardState) -> LineSet:
	var lines := LineSet.new()
	for r: int in board.height:
		var full := true
		for c: int in board.width:
			if not board.counts_for_line(board.index_of(r, c)):
				full = false
				break
		if full:
			lines.rows.append(r)
	for c: int in board.width:
		var full := true
		for r: int in board.height:
			if not board.counts_for_line(board.index_of(r, c)):
				full = false
				break
		if full:
			lines.cols.append(c)
	return lines


## board-rules rule 10: union of the lines' cells, each once, row-major.
static func line_cells(board: BoardState, lines: LineSet) -> PackedInt32Array:
	var mark := PackedByteArray()
	mark.resize(board.cell_count())
	mark.fill(0)
	for r: int in lines.rows:
		for c: int in board.width:
			mark[board.index_of(r, c)] = 1
	for c: int in lines.cols:
		for r: int in board.height:
			mark[board.index_of(r, c)] = 1
	return _marked_indices(mark)


## board-rules rule 11: empties the removable cells among [param cells]
## (any order, duplicates allowed). EMPTY and non-removable cells are skipped
## silently. Returns the new board and the emptied cells row-major.
static func clear_cells(board: BoardState, cells: PackedInt32Array) -> ClearResult:
	var result := ClearResult.new()
	var out := board.copy()
	for idx: int in sorted_unique(cells, board.cell_count()):
		if out.kind[idx] == CellKind.EMPTY or not out.removable_by_clear(idx):
			continue
		var cc := ClearedCell.new()
		cc.index = idx
		cc.row = idx / out.width
		cc.col = idx % out.width
		cc.crew_id = out.crew_at(idx)
		cc.is_face = out.is_face(idx)
		cc.origin = out.origin(idx)
		result.cleared.append(cc)
		out.set_empty(idx)
	result.board = out
	return result


## board-rules rule 12: fills [param cells] (in the given order) with
## [code]TILE(origin, crew_id, is_face = false)[/code]. Every target must be
## non-blocking; otherwise reports [constant ERR_FILL_OCCUPIED] and returns an
## unchanged copy.
static func fill_cells(board: BoardState, cells: PackedInt32Array, origin: int, crew_id: StringName, placement_id: int = 0) -> BoardState:
	var out := board.copy()
	for idx: int in cells:
		if idx < 0 or idx >= board.cell_count() or board.blocks_placement(idx):
			push_error(ERR_FILL_OCCUPIED)
			return board.copy()
	for idx: int in cells:
		out.set_tile(idx, crew_id, false, origin, placement_id)
	return out


## board-rules F5: number of [code]counts_for_line[/code] cells in a line.
static func line_fill_count(board: BoardState, axis: int, index: int) -> int:
	var n := 0
	for idx: int in _line_indices(board, axis, index):
		if board.counts_for_line(idx):
			n += 1
	return n


## board-rules F5: non-blocking cells of a line, row-major.
static func empty_cells_in_line(board: BoardState, axis: int, index: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for idx: int in _line_indices(board, axis, index):
		if not board.blocks_placement(idx):
			out.append(idx)
	return out


## board-rules F1: number of in-bounds anchors for the piece's bounding box.
static func anchor_count(board: BoardState, piece: PieceInstance) -> int:
	var h := piece.shape.height()
	var w := piece.shape.width()
	return maxi(0, board.height - h + 1) * maxi(0, board.width - w + 1)


## board-rules F4: [code]W*R + H*C - R*C[/code].
static func line_cell_count(board: BoardState, rows: int, cols: int) -> int:
	return board.width * rows + board.height * cols - rows * cols


## board-rules rule 14: any anchor (scanned row-major) where [method can_place] holds.
static func any_fit(board: BoardState, piece: PieceInstance) -> bool:
	var h := piece.shape.height()
	var w := piece.shape.width()
	for r: int in board.height - h + 1:
		for c: int in board.width - w + 1:
			if can_place(board, piece, Vector2i(r, c)):
				return true
	return false


## board-rules rule 15: true only when [param pieces] is non-empty and no piece fits.
## An empty tray is "awaiting refill", not stuck (D8).
static func no_moves(board: BoardState, pieces: Array[PieceInstance]) -> bool:
	if pieces.is_empty():
		return false
	for piece: PieceInstance in pieces:
		if any_fit(board, piece):
			return false
	return true


## board-rules rule 16: stage initial-board validation (empty = valid). Checks size,
## registered kinds, zero complete lines (invariant 13) and that faces have a crew.
static func validate_board(board: BoardState, config: BoardConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	if board.width != config.board_width or board.height != config.board_height:
		errors.append("board size %dx%d does not match config %dx%d" % [board.width, board.height, config.board_width, config.board_height])
		return errors
	for i: int in board.cell_count():
		if board.kind[i] >= board.kind_table.size():
			errors.append("cell %s has unregistered kind %d" % [board.cell_of(i), board.kind[i]])
		elif board.kind[i] != CellKind.EMPTY and board.is_face(i) and board.crew_at(i) == &"":
			errors.append("face cell %s has no crew_id" % board.cell_of(i))
	var lines := full_lines(board)
	for r: int in lines.rows:
		errors.append("row %d is already complete" % r)
	for c: int in lines.cols:
		errors.append("column %d is already complete" % c)
	return errors


## board-rules rule 3: shape validation against [param config] (empty = valid).
## Every message names the shape id and the violated condition.
static func validate_shape(shape: PieceShape, config: BoardConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	var sid := String(shape.id) if shape != null else "<null>"
	if shape == null or shape.offsets.is_empty():
		errors.append("shape %s: empty offset list" % sid)
		return errors
	var offs := shape.offsets
	if offs.size() > config.max_piece_cells:
		errors.append("shape %s: %d cells exceeds max_piece_cells %d" % [sid, offs.size(), config.max_piece_cells])
	var seen := {}
	var min_r := offs[0].x
	var min_c := offs[0].y
	for o: Vector2i in offs:
		if seen.has(o):
			errors.append("shape %s: duplicate offset %s" % [sid, o])
		seen[o] = true
		min_r = mini(min_r, o.x)
		min_c = mini(min_c, o.y)
	if min_r != 0 or min_c != 0:
		errors.append("shape %s: not normalised (min dr %d, min dc %d)" % [sid, min_r, min_c])
	if config.require_connected_shapes and not _is_connected(offs):
		errors.append("shape %s: cells are not 4-connected" % sid)
	if shape.height() > config.board_height or shape.width() > config.board_width:
		errors.append("shape %s: bounding box %dx%d larger than board" % [sid, shape.height(), shape.width()])
	return errors


## board-rules rule 5 / AC-04: instance validation. A faceless piece is valid only
## when [param allow_faceless_pieces]; a face index must be in [0, cells - 1].
static func validate_piece(piece: PieceInstance, config: BoardConfig, allow_faceless_pieces: bool) -> PackedStringArray:
	var errors := validate_shape(piece.shape, config)
	var n := piece.shape.cell_count() if piece.shape != null else 0
	if piece.face_index == PieceInstance.NO_FACE:
		if not allow_faceless_pieces:
			errors.append("piece: faceless piece not allowed on this stage")
	elif piece.face_index < 0 or piece.face_index >= n:
		errors.append("piece: face_index %d out of range [0, %d]" % [piece.face_index, n - 1])
	elif piece.crew_id == &"":
		errors.append("piece: face without crew_id")
	return errors


## Returns [param cells] sorted ascending (row-major), deduplicated, in-bounds only.
static func sorted_unique(cells: PackedInt32Array, cell_count: int) -> PackedInt32Array:
	var mark := PackedByteArray()
	mark.resize(cell_count)
	mark.fill(0)
	for idx: int in cells:
		if idx >= 0 and idx < cell_count:
			mark[idx] = 1
	return _marked_indices(mark)


static func _marked_indices(mark: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in mark.size():
		if mark[i] != 0:
			out.append(i)
	return out


static func _line_indices(board: BoardState, axis: int, index: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if axis == AXIS_ROW:
		if index < 0 or index >= board.height:
			return out
		for c: int in board.width:
			out.append(board.index_of(index, c))
	else:
		if index < 0 or index >= board.width:
			return out
		for r: int in board.height:
			out.append(board.index_of(r, index))
	return out


static func _is_connected(offs: Array[Vector2i]) -> bool:
	var cells := {}
	for o: Vector2i in offs:
		cells[o] = true
	var start: Vector2i = offs[0]
	var visited := {start: true}
	var stack: Array[Vector2i] = [start]
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for d: Vector2i in dirs:
			var nxt := cur + d
			if cells.has(nxt) and not visited.has(nxt):
				visited[nxt] = true
				stack.append(nxt)
	return visited.size() == cells.size()
