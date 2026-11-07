## One resolver event (chain-resolver rule 19, ADR-0001 Decision 4).
##
## Common fields are typed; the payload is a read-only [Dictionary] whose keys are
## the [code]K_*[/code] constants below. Coordinates are [code]Vector2i(row, col)[/code].
## "null" values in the GDD schema are encoded as [code]-1[/code] (ints),
## [code]&""[/code] (crew ids) or [constant NO_CELL] (cells).
class_name ChainEvent
extends RefCounted

## Event kinds, in the GDD rule 19 table order.
enum Type { PLACED, WAVE_BEGIN, CELL_MODIFIED, CELLS_CLEARED, FACE_ACTIVATED, ABILITY_EFFECT, FACE_FIZZLED, DEPTH_CAP_REACHED, CHAIN_END }

## Encodes a null cell (e.g. [code]PLACED.face_cell[/code] of a faceless piece).
const NO_CELL := Vector2i(-1, -1)

# Payload keys -----------------------------------------------------------------
const K_CREW_ID := &"crew_id"
const K_ANCHOR := &"anchor"
const K_CELLS := &"cells"
const K_FACE_CELL := &"face_cell"
const K_WAVE := &"wave"
const K_CAUSES := &"causes"
const K_ROWS := &"rows"
const K_COLS := &"cols"
const K_CELL := &"cell"
const K_MODIFIERS_BEFORE := &"modifiers_before"
const K_MODIFIERS_AFTER := &"modifiers_after"
const K_LINE_CELL_COUNT := &"line_cell_count"
const K_ABILITY_CELL_COUNT := &"ability_cell_count"
const K_KEPT := &"kept"
const K_ORDER_INDEX := &"order_index"
const K_ABILITY_ID := &"ability_id"
const K_STAGE := &"stage"
const K_PRIMITIVE := &"primitive"
const K_KIND := &"kind"
const K_REASON := &"reason"
# CELLS_CLEARED.cells[] entry keys
const K_R := &"r"
const K_C := &"c"
const K_IS_FACE := &"is_face"
const K_ORIGIN := &"origin"
const K_BY := &"by"
const K_SOURCE_ORDER := &"source_order"
# CHAIN_END summary keys
const K_CHAIN_DEPTH := &"chain_depth"
const K_WAVES := &"waves"
const K_CELLS_CLEARED_TOTAL := &"cells_cleared_total"
const K_LINES_CLEARED_TOTAL := &"lines_cleared_total"
const K_FACES_ACTIVATED := &"faces_activated"
const K_FACES_FIZZLED := &"faces_fizzled"
const K_EGGS_LAID := &"eggs_laid"
const K_CAP_REACHED := &"cap_reached"
const K_BOARD_HASH := &"board_hash"

# Payload enumeration values ---------------------------------------------------
const CAUSE_LINE := &"LINE"
const CAUSE_ABILITY := &"ABILITY"
const BY_LINE := &"LINE"
const BY_ABILITY := &"ABILITY"
const BY_BOTH := &"BOTH"
const KIND_CLEAR := &"CLEAR"
const KIND_FILL := &"FILL"
const REASON_DEPTH_CAP := &"DEPTH_CAP"
const REASON_SUPPRESSED := &"SUPPRESSED"

## Position in the event list (0..n-1, gap-free).
var seq: int = 0
## Event kind.
var type: Type = Type.PLACED
## Wave number; -1 = null (PLACED, CHAIN_END).
var wave: int = -1
## Read-only payload keyed by [code]K_*[/code].
var data: Dictionary = {}


## Creates an event and freezes its payload (nested Arrays/Dictionaries included).
static func make(p_seq: int, p_type: Type, p_wave: int, p_data: Dictionary) -> ChainEvent:
	var e := ChainEvent.new()
	e.seq = p_seq
	e.type = p_type
	e.wave = p_wave
	e.data = p_data
	_freeze(e.data)
	return e


## Plain Dictionary form (seq, type name, wave, data) for golden comparison.
func to_dict() -> Dictionary:
	return {&"seq": seq, &"type": Type.keys()[type], &"wave": wave, &"data": data}


## Name of the event type, e.g. [code]"WAVE_BEGIN"[/code].
func type_name() -> String:
	return Type.keys()[type]


static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		var d: Dictionary = value
		for v: Variant in d.values():
			_freeze(v)
		d.make_read_only()
	elif value is Array:
		var a: Array = value
		for v: Variant in a:
			_freeze(v)
		a.make_read_only()
