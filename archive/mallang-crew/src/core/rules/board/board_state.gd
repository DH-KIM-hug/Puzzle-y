## Board value object, structure-of-arrays (ADR-0001 Decision 2).
##
## Coordinates are [code]Vector2i(row, col)[/code]; cell index = row * width + col.
## Public rule functions never mutate a board they receive: they [method copy] it
## and write to the copy. The setters below exist for that copy-then-write pattern
## and for building fixtures — never call them on a board you did not create.
class_name BoardState
extends RefCounted

## Tile came from a placed piece.
const ORIGIN_PIECE := 0
## Tile was laid by a FILL ability (egg / wool puff).
const ORIGIN_EGG := 1

const _FLAG_FACE := 1
const _FLAG_EGG := 2

## Columns.
var width: int = 0
## Rows.
var height: int = 0
## Kind id per cell (see [CellKind]).
var kind: PackedByteArray = PackedByteArray()
## Per-cell content flags (is_face, origin).
var flags: PackedByteArray = PackedByteArray()
## Crew per cell; [code]&""[/code] = null.
var crew: Array[StringName] = []
## Placement number the tile came from (presentation / debug only).
var placement_id: PackedInt32Array = PackedInt32Array()
## Sparse modifiers: cell index -> PackedInt32Array. Preserved, never interpreted.
var modifiers: Dictionary = {}
## Kind flag table (index = kind id). Shared by value (packed arrays are copy-on-write).
var kind_table: PackedByteArray = PackedByteArray()


## Creates an all-EMPTY board. [param table] defaults to [method CellKind.default_table].
static func create(p_width: int, p_height: int, table: PackedByteArray = PackedByteArray()) -> BoardState:
	var b := BoardState.new()
	b.width = p_width
	b.height = p_height
	var n := p_width * p_height
	b.kind.resize(n)
	b.kind.fill(CellKind.EMPTY)
	b.flags.resize(n)
	b.flags.fill(0)
	b.placement_id.resize(n)
	b.placement_id.fill(0)
	b.crew.resize(n)
	b.crew.fill(&"")
	b.kind_table = table if not table.is_empty() else CellKind.default_table()
	return b


## Creates an empty board sized by [param config].
static func from_config(config: BoardConfig, table: PackedByteArray = PackedByteArray()) -> BoardState:
	return create(config.board_width, config.board_height, table)


## Deep copy. Modifiers are deep-duplicated so the copy never shares a
## PackedInt32Array with the original (ADR-0001 Engine Specialist Review 1).
func copy() -> BoardState:
	var b := BoardState.new()
	b.width = width
	b.height = height
	b.kind = kind.duplicate()
	b.flags = flags.duplicate()
	b.crew = crew.duplicate()
	b.placement_id = placement_id.duplicate()
	b.modifiers = modifiers.duplicate(true)
	b.kind_table = kind_table
	return b


## Number of cells.
func cell_count() -> int:
	return width * height


## Cell index of (row, col).
func index_of(row: int, col: int) -> int:
	return row * width + col


## Cell index of [code]Vector2i(row, col)[/code].
func index_of_cell(cell: Vector2i) -> int:
	return cell.x * width + cell.y


## Coordinates of a cell index.
func cell_of(index: int) -> Vector2i:
	return Vector2i(index / width, index % width)


## True when (row, col) is on the board.
func in_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < height and col >= 0 and col < width


## Flag mask of the kind at [param index].
func kind_flags(index: int) -> int:
	var k := kind[index]
	if k >= kind_table.size():
		return 0
	return kind_table[k]


## board-rules flag: occupied.
func blocks_placement(index: int) -> bool:
	return (kind_flags(index) & CellKind.BLOCKS_PLACEMENT) != 0


## board-rules flag: counts toward a full line.
func counts_for_line(index: int) -> bool:
	return (kind_flags(index) & CellKind.COUNTS_FOR_LINE) != 0


## board-rules flag: may be emptied by a clear.
func removable_by_clear(index: int) -> bool:
	return (kind_flags(index) & CellKind.REMOVABLE_BY_CLEAR) != 0


## True when the cell is a face tile.
func is_face(index: int) -> bool:
	return (flags[index] & _FLAG_FACE) != 0


## [constant ORIGIN_PIECE] or [constant ORIGIN_EGG].
func origin(index: int) -> int:
	return ORIGIN_EGG if (flags[index] & _FLAG_EGG) != 0 else ORIGIN_PIECE


## Crew id at the cell ([code]&""[/code] = null).
func crew_at(index: int) -> StringName:
	return crew[index]


## Modifiers at the cell (a copy; empty when none).
func modifiers_at(index: int) -> PackedInt32Array:
	if modifiers.has(index):
		var m: PackedInt32Array = modifiers[index]
		return m.duplicate()
	return PackedInt32Array()


## Writes a TILE (or another kind via [param p_kind]). Copy-then-write only.
func set_tile(index: int, p_crew: StringName, p_is_face: bool, p_origin: int, p_placement_id: int, p_kind: int = CellKind.TILE) -> void:
	kind[index] = p_kind
	var f := 0
	if p_is_face:
		f |= _FLAG_FACE
	if p_origin == ORIGIN_EGG:
		f |= _FLAG_EGG
	flags[index] = f
	crew[index] = p_crew
	placement_id[index] = p_placement_id


## Empties a cell (kind EMPTY, content and modifiers removed). Copy-then-write only.
func set_empty(index: int) -> void:
	kind[index] = CellKind.EMPTY
	flags[index] = 0
	crew[index] = &""
	placement_id[index] = 0
	modifiers.erase(index)


## Replaces a cell's modifiers (stores a private copy). Copy-then-write only.
func set_modifiers(index: int, values: PackedInt32Array) -> void:
	if values.is_empty():
		modifiers.erase(index)
	else:
		modifiers[index] = values.duplicate()


## Cell-by-cell equality (kind, content, placement id, modifiers, size).
func equals(other: BoardState) -> bool:
	if other == null or other.width != width or other.height != height:
		return false
	if other.kind != kind or other.flags != flags or other.placement_id != placement_id:
		return false
	if other.crew != crew:
		return false
	if other.modifiers.size() != modifiers.size():
		return false
	for key: int in modifiers:
		if not other.modifiers.has(key):
			return false
		var a: PackedInt32Array = modifiers[key]
		var b: PackedInt32Array = other.modifiers[key]
		if a != b:
			return false
	return true


## Number of non-EMPTY cells.
func filled_count() -> int:
	var n := 0
	for i: int in cell_count():
		if kind[i] != CellKind.EMPTY:
			n += 1
	return n


## Deterministic board hash (ADR-0001 Implementation Guidelines): one
## [method SeedHash.hash32] call over two parts per cell
## ([code]kind | flags << 8 | (placement_id & 0xFFFF) << 16[/code], crew key)
## followed by sparse modifiers in ascending cell order.
## [param crew_keys] maps crew_id -> cached [method SeedHash.str32]; a missing
## key falls back to computing [method SeedHash.str32].
func board_hash(crew_keys: Dictionary = {}) -> int:
	var parts: Array[int] = []
	var n := cell_count()
	parts.resize(n * 2)
	for i: int in n:
		parts[i * 2] = kind[i] | (flags[i] << 8) | ((placement_id[i] & 0xFFFF) << 16)
		var c := crew[i]
		var key := 0
		if c != &"":
			if crew_keys.has(c):
				key = crew_keys[c]
			else:
				key = SeedHash.str32(String(c))
		parts[i * 2 + 1] = key
	var mod_keys: Array = modifiers.keys()
	mod_keys.sort()
	for idx: int in mod_keys:
		var m: PackedInt32Array = modifiers[idx]
		parts.append(idx)
		parts.append(m.size())
		for v: int in m:
			parts.append(v)
	return SeedHash.hash32(parts)
