## Drag & placement input state machine (design/gdd/placement-input.md rules 5–19,
## F1–F5). Pure logic: no Node, no rendering — the game scene feeds it pointer
## events in canvas coordinates and draws what [member state],
## [member piece_rect] and [member anchor] say.
##
## Transitions (States and Transitions table):
## [codeblock]
## LOCKED   --set_enabled(true)-->            READY
## READY    --press(slot with piece)-->       PRESSED
## PRESSED  --move >= slop-->                 DRAGGING     (first candidate anchor)
## PRESSED  --release-->                      READY        (tap: RETURNED)
## DRAGGING --release on valid anchor-->      LOCKED       (placement_requested, COMMITTED)
## DRAGGING --release otherwise-->            READY        (RETURNED)
## PRESSED/DRAGGING --cancel()-->             READY        (CANCELLED)
## any      --set_enabled(false)-->           LOCKED       (drag cancelled first)
## [/codeblock]
## Validity is asked through the injected [member can_place] callable
## ([code](slot: int, anchor: Vector2i) -> bool[/code]) once per candidate anchor.
## [codeblock]
## var dc := DragController.new(tuning, layout_fn, flow.can_place)
## dc.set_enabled(true)
## dc.press(0, piece_size, pos, pointer_index)
## dc.move(pos, pointer_index); dc.release(pointer_index)
## [/codeblock]
class_name DragController
extends RefCounted

## Input states (RETURNING is a display-only sub-state of READY — see the GDD).
enum State { LOCKED, READY, PRESSED, DRAGGING }
## [signal drag_ended] reasons.
enum EndReason { COMMITTED, RETURNED, CANCELLED }

## Valid anchor changed: [param anchor] is a Vector2i, or null when it became invalid (rule 13).
signal anchor_changed(slot: int, anchor: Variant)
## Valid release (rule 15).
signal placement_requested(slot: int, anchor: Vector2i)
## Every PRESSED/DRAGGING exit, exactly once. [param on_board] = last candidate was on the board (wiggle).
signal drag_ended(slot: int, reason: EndReason, on_board: bool)

## Reference canvas width of px@1080 values (F5).
const REF_WIDTH := 1080.0

## Tuning values.
var tuning: PlacementInputTuning
## (slot, anchor) -> bool, board-rules legality (injected).
var can_place: Callable
## Board top-left in canvas coordinates.
var board_origin: Vector2 = Vector2.ZERO
## Cell size in canvas units.
var cell_size: float = 86.0
## Canvas logical width (F5).
var canvas_width: float = 720.0
## Board size in cells (rows, cols) — only for the on-board wiggle test.
var board_cells: Vector2i = Vector2i(8, 8)

## Current state.
var state: State = State.LOCKED
## Slot being dragged (-1 = none).
var slot: int = -1
## Owning pointer index (rule 18).
var pointer: int = -1
## Press point.
var press_pos: Vector2 = Vector2.ZERO
## Latest owning-pointer position.
var finger: Vector2 = Vector2.ZERO
## Dragged piece size in cells (w, h).
var piece_cells: Vector2i = Vector2i.ONE
## Current candidate anchor (row, col); valid only when [member has_anchor].
var anchor: Vector2i = Vector2i.ZERO
## True once DRAGGING computed a first candidate.
var has_anchor: bool = false
## Legality of [member anchor] (rule 11 cache).
var anchor_valid: bool = false


func _init(p_tuning: PlacementInputTuning = null, p_can_place: Callable = Callable()) -> void:
	tuning = p_tuning if p_tuning != null else PlacementInputTuning.new()
	can_place = p_can_place


## Round flow turns input on/off (rule 19d). Turning off mid-drag cancels it.
func set_enabled(on: bool) -> void:
	if not on:
		if state == State.PRESSED or state == State.DRAGGING:
			cancel()
		state = State.LOCKED
	elif state == State.LOCKED:
		state = State.READY


## Press on tray [param p_slot] holding a piece of [param size] cells (w, h).
## Returns true when the piece was lifted (rule 5).
func press(p_slot: int, size: Vector2i, pos: Vector2, pointer_index: int) -> bool:
	if state != State.READY:
		return false
	state = State.PRESSED
	slot = p_slot
	pointer = pointer_index
	press_pos = pos
	finger = pos
	piece_cells = size
	has_anchor = false
	anchor_valid = false
	return true


## Owning-pointer move. Other pointers are ignored (rule 18).
func move(pos: Vector2, pointer_index: int) -> void:
	if pointer_index != pointer or (state != State.PRESSED and state != State.DRAGGING):
		return
	finger = pos
	if state == State.PRESSED:
		if pos.distance_to(press_pos) < slop_canvas():
			return
		state = State.DRAGGING
	_update_anchor()


## Owning-pointer release (rule 14: uses the last shown anchor, no recompute).
func release(pointer_index: int) -> void:
	if pointer_index != pointer or (state != State.PRESSED and state != State.DRAGGING):
		return
	var s := slot
	if state == State.DRAGGING and has_anchor and anchor_valid:
		state = State.LOCKED
		_reset()
		placement_requested.emit(s, anchor)
		drag_ended.emit(s, EndReason.COMMITTED, true)
		return
	var on_board := state == State.DRAGGING and has_anchor and _on_board(anchor)
	var had_valid := has_anchor and anchor_valid
	state = State.READY
	_reset()
	if had_valid:
		anchor_changed.emit(s, null)
	drag_ended.emit(s, EndReason.RETURNED, on_board)


## Forced cancel (rule 19): return without wiggle, no placement.
func cancel() -> void:
	if state != State.PRESSED and state != State.DRAGGING:
		return
	var s := slot
	var had_valid := has_anchor and anchor_valid
	state = State.READY
	_reset()
	if had_valid:
		anchor_changed.emit(s, null)
	drag_ended.emit(s, EndReason.CANCELLED, false)


## Round flow refused a requested placement (bug path): back to READY.
func refuse() -> void:
	state = State.READY


## F1: dragged piece rect (canvas) for the current finger.
func piece_rect() -> Rect2:
	return Rect2(piece_top_left(finger, piece_cells, cell_size, tuning.lift_offset_cells), Vector2(piece_cells) * cell_size)


## F4 slop in canvas units.
func slop_canvas() -> float:
	return tuning.drag_slop_px * canvas_width / REF_WIDTH


## F5: px@1080 → canvas units.
func ref_px(px_at_1080: float) -> float:
	return px_at_1080 * canvas_width / REF_WIDTH


## F1: top-left of a (w, h) piece for finger [param f].
static func piece_top_left(f: Vector2, size: Vector2i, s: float, lift_cells: float) -> Vector2:
	return Vector2(f.x - size.x * s / 2.0, f.y - size.y * s - lift_cells * s)


## F2: raw anchor (row, col as floats) of a piece whose top-left is [param top_left].
static func raw_anchor(top_left: Vector2, origin: Vector2, s: float) -> Vector2:
	return Vector2((top_left.y - origin.y) / s, (top_left.x - origin.x) / s)


## F2 rounding: floor(x + 0.5).
static func round_half_up(x: float) -> int:
	return int(floor(x + 0.5))


## F3 per-axis hysteresis: keep [param current] while |raw - current| <= 0.5 + hy.
static func snap_axis(raw: float, current: int, hy: float) -> int:
	if absf(raw - current) <= 0.5 + hy:
		return current
	return round_half_up(raw)


func _update_anchor() -> void:
	var raw := raw_anchor(piece_rect().position, board_origin, cell_size)
	var next: Vector2i
	if not has_anchor:
		next = Vector2i(round_half_up(raw.x), round_half_up(raw.y))
	else:
		var hy := tuning.snap_hysteresis_cells
		next = Vector2i(snap_axis(raw.x, anchor.x, hy), snap_axis(raw.y, anchor.y, hy))
	if has_anchor and next == anchor:
		return
	var was_valid := has_anchor and anchor_valid
	has_anchor = true
	anchor = next
	anchor_valid = can_place.is_valid() and bool(can_place.call(slot, anchor))
	if anchor_valid:
		anchor_changed.emit(slot, anchor)
	elif was_valid:
		anchor_changed.emit(slot, null)


func _on_board(a: Vector2i) -> bool:
	return a.x > -piece_cells.y and a.y > -piece_cells.x and a.x < board_cells.x and a.y < board_cells.y


func _reset() -> void:
	slot = -1
	pointer = -1
	has_anchor = false
	anchor_valid = false
