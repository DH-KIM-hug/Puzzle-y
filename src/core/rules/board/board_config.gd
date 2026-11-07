## Global board data (board-rules "데이터 기반 값" table). Loaded from
## [code]assets/data/rules/board_rules.tres[/code]; read-only at runtime.
class_name BoardConfig
extends Resource

## Board columns (safe range 7–10).
@export var board_width: int = 8
## Board rows (safe range 7–10).
@export var board_height: int = 8
## Maximum cells in one piece shape (safe range 1–9).
@export var max_piece_cells: int = 6
## Shapes must be 4-connected (board-rules D4).
@export var require_connected_shapes: bool = true


## Returns validation errors for the config itself (empty = valid).
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if board_width < 1 or board_height < 1:
		errors.append("BoardConfig: board size must be positive (%dx%d)" % [board_width, board_height])
	if max_piece_cells < 1:
		errors.append("BoardConfig: max_piece_cells must be >= 1 (%d)" % max_piece_cells)
	return errors
