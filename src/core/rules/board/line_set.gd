## Completed lines: rows ascending, then columns ascending (board-rules rule 9).
class_name LineSet
extends RefCounted

## Completed row numbers, ascending.
var rows: PackedInt32Array = PackedInt32Array()
## Completed column numbers, ascending.
var cols: PackedInt32Array = PackedInt32Array()


## Total number of lines (R + C).
func count() -> int:
	return rows.size() + cols.size()


## True when no line is complete.
func is_empty() -> bool:
	return rows.is_empty() and cols.is_empty()
