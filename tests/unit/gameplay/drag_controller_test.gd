## design/gdd/placement-input.md F1–F4, rules 8, 12–14, 16, 18: the pure drag
## state machine. Layout numbers are the GDD worked examples (s = 131, board (16, 300)).
extends GdUnitTestSuite

var _valid: Dictionary = {}
var _asked: Array = []
var _changes: Array = []
var _requests: Array = []
var _ends: Array = []


func _make(canvas_width: float = 1080.0) -> DragController:
	_valid = {}
	_asked = []
	_changes = []
	_requests = []
	_ends = []
	var dc := DragController.new(PlacementInputTuning.new(), func(_slot: int, a: Vector2i) -> bool:
		_asked.append(a)
		return _valid.get(a, false))
	dc.board_origin = Vector2(16, 300)
	dc.cell_size = 131.0
	dc.canvas_width = canvas_width
	dc.anchor_changed.connect(func(s: int, a: Variant) -> void: _changes.append(a))
	dc.placement_requested.connect(func(s: int, a: Vector2i) -> void: _requests.append([s, a]))
	dc.drag_ended.connect(func(s: int, r: DragController.EndReason, on_board: bool) -> void: _ends.append(r))
	dc.set_enabled(true)
	return dc


## Finger position whose F1 piece top-left gives raw anchor (r_raw, c_raw) for a (w, h) piece.
func _finger_for(raw: Vector2, size: Vector2i) -> Vector2:
	var s := 131.0
	var tl := Vector2(16, 300) + Vector2(raw.y, raw.x) * s
	return Vector2(tl.x + size.x * s / 2.0, tl.y + size.y * s + 0.6 * s)


func test_f1_f2_worked_example_gives_anchor_2_1() -> void:
	# Arrange — F1 example: s = 131, finger (400, 900), 3 wide × 2 high piece.
	var tl := DragController.piece_top_left(Vector2(400, 900), Vector2i(3, 2), 131.0, 0.6)
	# Act
	var raw := DragController.raw_anchor(tl, Vector2(16, 300), 131.0)
	# Assert
	assert_float(tl.x).is_equal_approx(203.5, 0.01)
	assert_float(tl.y).is_equal_approx(559.4, 0.01)
	assert_int(DragController.round_half_up(raw.x)).is_equal(2)
	assert_int(DragController.round_half_up(raw.y)).is_equal(1)


func test_f3_hysteresis_examples_hold_and_switch() -> void:
	# Arrange / Act / Assert — F3 example values (Hy = 0.12).
	assert_int(DragController.snap_axis(1.55, 1, 0.12)).is_equal(1)
	assert_int(DragController.snap_axis(1.63, 1, 0.12)).is_equal(2)
	assert_int(DragController.snap_axis(1.40, 2, 0.12)).is_equal(2)
	assert_int(DragController.snap_axis(1.37, 2, 0.12)).is_equal(1)


func test_f2_half_rounds_up_including_negative() -> void:
	assert_int(DragController.round_half_up(0.5)).is_equal(1)
	assert_int(DragController.round_half_up(-0.5)).is_equal(0)
	assert_int(DragController.round_half_up(-1.5)).is_equal(-1)


func test_f4_slop_on_720_canvas_keeps_pressed_until_13_3() -> void:
	# Arrange — F4 example on the 720 canvas.
	var dc := _make(720.0)
	dc.press(0, Vector2i(2, 3), Vector2(300, 1100), 0)
	# Act
	dc.move(Vector2(308, 1090), 0)
	var after_small := dc.state
	dc.move(Vector2(310, 1088), 0)
	# Assert
	assert_int(after_small).is_equal(DragController.State.PRESSED)
	assert_int(dc.state).is_equal(DragController.State.DRAGGING)


func test_tap_inside_slop_returns_without_request() -> void:
	# Arrange
	var dc := _make()
	dc.press(1, Vector2i(1, 1), Vector2(500, 1500), 0)
	# Act
	dc.release(0)
	# Assert
	assert_array(_requests).is_empty()
	assert_array(_ends).contains_exactly([DragController.EndReason.RETURNED])
	assert_int(dc.state).is_equal(DragController.State.READY)


func test_valid_release_requests_last_shown_anchor_and_locks() -> void:
	# Arrange
	var dc := _make()
	_valid[Vector2i(2, 1)] = true
	var start := Vector2(500, 1500)
	dc.press(0, Vector2i(3, 2), start, 0)
	# Act — reach raw (2.0, 1.0), then a tiny slip that stays inside the hysteresis band.
	dc.move(_finger_for(Vector2(2.0, 1.0), Vector2i(3, 2)), 0)
	dc.move(_finger_for(Vector2(2.1, 1.55), Vector2i(3, 2)), 0)
	dc.release(0)
	# Assert
	assert_array(_requests).contains_exactly([[0, Vector2i(2, 1)]])
	assert_array(_ends).contains_exactly([DragController.EndReason.COMMITTED])
	assert_int(dc.state).is_equal(DragController.State.LOCKED)


func test_anchor_changed_only_on_valid_anchor_changes() -> void:
	# Arrange — (2,1) valid, (2,2) invalid, (2,3) valid. F7 example shape.
	var dc := _make()
	_valid[Vector2i(2, 1)] = true
	_valid[Vector2i(2, 3)] = true
	dc.press(0, Vector2i(1, 1), Vector2(500, 1500), 0)
	# Act
	dc.move(_finger_for(Vector2(2.0, 1.0), Vector2i(1, 1)), 0)
	dc.move(_finger_for(Vector2(2.0, 1.1), Vector2i(1, 1)), 0)   # same anchor: nothing
	dc.move(_finger_for(Vector2(2.0, 2.0), Vector2i(1, 1)), 0)   # invalid: clear once
	dc.move(_finger_for(Vector2(2.0, 3.0), Vector2i(1, 1)), 0)   # valid again
	# Assert
	assert_array(_changes).contains_exactly([Vector2i(2, 1), null, Vector2i(2, 3)])
	assert_array(_asked).contains_exactly([Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)])


func test_second_pointer_is_ignored() -> void:
	# Arrange
	var dc := _make()
	dc.press(0, Vector2i(1, 1), Vector2(500, 1500), 0)
	# Act
	dc.move(Vector2(100, 100), 1)
	dc.release(1)
	# Assert
	assert_int(dc.state).is_equal(DragController.State.PRESSED)
	assert_array(_ends).is_empty()


func test_disable_mid_drag_cancels_and_locks() -> void:
	# Arrange
	var dc := _make()
	dc.press(0, Vector2i(1, 1), Vector2(500, 1500), 0)
	# Act
	dc.set_enabled(false)
	# Assert
	assert_array(_ends).contains_exactly([DragController.EndReason.CANCELLED])
	assert_int(dc.state).is_equal(DragController.State.LOCKED)
