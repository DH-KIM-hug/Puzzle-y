## One cell actually emptied by [method BoardRules.clear_cells] (board-rules rule 11).
class_name ClearedCell
extends RefCounted

## Cell index ([code]row * width + col[/code]).
var index: int
## Row.
var row: int
## Column.
var col: int
## Crew of the tile ([code]&""[/code] = null).
var crew_id: StringName
## Whether the tile was a face.
var is_face: bool
## [constant BoardState.ORIGIN_PIECE] or [constant BoardState.ORIGIN_EGG].
var origin: int
