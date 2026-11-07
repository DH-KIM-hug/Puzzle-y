## Cell-kind rule flags (board-rules rule 2, ADR-0001 Decision 2).
##
## Board rules never read a kind's name, only these three flags. A kind table is a
## [PackedByteArray] indexed by kind id whose bytes are flag masks; it travels with
## each [BoardState] so obstacle kinds can be added as data (board-rules AC-12)
## without touching [BoardRules].
class_name CellKind
extends RefCounted

## Kind id of an empty cell.
const EMPTY := 0
## Kind id of a piece / egg tile.
const TILE := 1

## Flag: the cell blocks placement (it is occupied).
const BLOCKS_PLACEMENT := 1
## Flag: the cell counts toward completing a row / column.
const COUNTS_FOR_LINE := 2
## Flag: [method BoardRules.clear_cells] may empty this cell.
const REMOVABLE_BY_CLEAR := 4


## The MVP kind table: EMPTY = no flags, TILE = all three flags.
static func default_table() -> PackedByteArray:
	var table := PackedByteArray()
	table.resize(2)
	table[EMPTY] = 0
	table[TILE] = BLOCKS_PLACEMENT | COUNTS_FOR_LINE | REMOVABLE_BY_CLEAR
	return table


## Returns a copy of [param table] with kind [param kind_id] set to [param flags].
## The input table is not modified.
static func with_kind(table: PackedByteArray, kind_id: int, flags: int) -> PackedByteArray:
	var out := table.duplicate()
	if out.size() <= kind_id:
		out.resize(kind_id + 1)
	out[kind_id] = flags & 0xFF
	return out
