## Piece shape data (board-rules rule 3): offsets [code]Vector2i(dr, dc)[/code]
## (x = row offset, y = column offset). No rotation (rule 4). Data only.
class_name PieceShape
extends Resource

## Catalog id, e.g. [code]&"L3_A"[/code] (crew-definition shape catalog).
@export var id: StringName = &""
## Cell offsets (dr, dc); order defines the cell index used by [code]face_index[/code].
@export var offsets: Array[Vector2i] = []


## Builds an in-memory shape (tests, tools). [param cells] is an Array of Vector2i.
static func make(shape_id: StringName, cells: Array) -> PieceShape:
	var shape := PieceShape.new()
	shape.id = shape_id
	var typed: Array[Vector2i] = []
	for v: Vector2i in cells:
		typed.append(v)
	shape.offsets = typed
	return shape


## Number of cells.
func cell_count() -> int:
	return offsets.size()


## Bounding-box height ([code]max(dr) + 1[/code]); 0 for an empty shape.
func height() -> int:
	var h := 0
	for o: Vector2i in offsets:
		h = maxi(h, o.x + 1)
	return h


## Bounding-box width ([code]max(dc) + 1[/code]); 0 for an empty shape.
func width() -> int:
	var w := 0
	for o: Vector2i in offsets:
		w = maxi(w, o.y + 1)
	return w
