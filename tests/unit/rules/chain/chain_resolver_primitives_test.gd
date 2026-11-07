## chain-resolver AC-11, AC-19 (F4) — primitive target geometry and validation.
extends GdUnitTestSuite

const KKANGCHONG_OFFSETS: Array = [Vector2i(-2, -2), Vector2i(-2, 0), Vector2i(-2, 2), Vector2i(0, -2),
	Vector2i(0, 2), Vector2i(2, -2), Vector2i(2, 0), Vector2i(2, 2)]
const MONGSIL_OFFSETS: Array = [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0)]


func _targets(prim: StringName, params: Dictionary, b: BoardState, face: Vector2i) -> PackedInt32Array:
	return PrimitiveLibrary.execute(prim, params, b, b.index_of(face.x, face.y), ChainFixture.ctx())


func _all_in_bounds(b: BoardState, cells: PackedInt32Array) -> bool:
	for idx: int in cells:
		if idx < 0 or idx >= b.cell_count():
			return false
	return true


func test_target_sizes_on_empty_board_at_three_five() -> void:
	# AC-19: 15, 9, 12 (6 + 7 − 1).
	var b := BoardFixture.empty()
	assert_int(_targets(&"clear_cross", {&"reach": -1}, b, Vector2i(3, 5)).size()).is_equal(15)
	assert_int(_targets(&"clear_area", {&"radius": 1}, b, Vector2i(3, 5)).size()).is_equal(9)
	assert_int(_targets(&"clear_diagonals", {&"reach": -1}, b, Vector2i(3, 5)).size()).is_equal(12)


func test_every_primitive_at_corner_stays_on_board() -> void:
	# AC-11: face (0,0), all seven primitives; corner clear_area(1) = 4 cells.
	var b := BoardFixture.empty()
	var cases := {
		&"clear_cross": [{&"reach": -1}, 15],
		&"clear_line": [{&"axis": &"row", &"reach": -1}, 8],
		&"clear_area": [{&"radius": 1}, 4],
		&"clear_diagonals": [{&"reach": -1}, 8],
		&"clear_pattern": [{&"offsets": KKANGCHONG_OFFSETS}, 3],
		&"lay_eggs_in_own_line": [{&"count": 3}, 3],
		&"lay_eggs_pattern": [{&"offsets": MONGSIL_OFFSETS}, 3],
	}
	for prim: StringName in PrimitiveLibrary.ids():
		var cells := _targets(prim, cases[prim][0], b, Vector2i(0, 0))
		assert_bool(_all_in_bounds(b, cells)).override_failure_message(String(prim)).is_true()
		assert_int(cells.size()).override_failure_message(String(prim)).is_equal(cases[prim][1])


func test_limited_reach_cross_and_column_line() -> void:
	var b := BoardFixture.empty()
	assert_int(_targets(&"clear_cross", {&"reach": 1}, b, Vector2i(3, 3)).size()).is_equal(5)
	var col := _targets(&"clear_line", {&"axis": &"col", &"reach": -1}, b, Vector2i(3, 3))
	assert_int(col.size()).is_equal(8)
	for idx: int in col:
		assert_int(idx % 8).is_equal(3)


func test_mongsil_pattern_lays_in_offset_order_and_drops_off_board() -> void:
	# crew-definition AC-12 geometry: (0,0),(0,1),(1,0) in offsets order.
	var b := BoardFixture.empty()
	var cells := _targets(&"lay_eggs_pattern", {&"offsets": MONGSIL_OFFSETS}, b, Vector2i(0, 0))
	assert_array(Array(cells)).is_equal([0, 1, 8])


func test_starter_crew_filled_targets_around_open_center() -> void:
	# crew-definition AC-11 (starter subset): (3,3) empty, other 63 filled.
	var rows: Array = []
	for r: int in 8:
		rows.append("###.####" if r == 3 else "########")
	var b := BoardFixture.board(rows)
	var filled := func(cells: PackedInt32Array) -> int:
		var n := 0
		for idx: int in cells:
			if b.kind[idx] != CellKind.EMPTY:
				n += 1
		return n
	assert_int(filled.call(_targets(&"clear_cross", {&"reach": -1}, b, Vector2i(3, 3)))).is_equal(14)
	assert_int(filled.call(_targets(&"clear_area", {&"radius": 1}, b, Vector2i(3, 3)))).is_equal(8)
	var hop := _targets(&"clear_pattern", {&"offsets": KKANGCHONG_OFFSETS}, b, Vector2i(3, 3))
	assert_int(filled.call(hop)).is_equal(8)
	for idx: int in hop:
		var cell := b.cell_of(idx)
		assert_int(maxi(absi(cell.x - 3), absi(cell.y - 3))).is_equal(2)


func test_validation_rejects_bad_steps() -> void:
	# Rule 18 / AC-11 AND
	assert_str(" ".join(PrimitiveLibrary.validate(&"clear_spiral", {}))).contains("unknown primitive")
	assert_str(" ".join(PrimitiveLibrary.validate(&"clear_area", {&"radius": -1}))).contains("radius")
	assert_str(" ".join(PrimitiveLibrary.validate(&"clear_cross", {&"reach": -2}))).contains("reach")
	assert_str(" ".join(PrimitiveLibrary.validate(&"lay_eggs_in_own_line", {&"count": 0}))).contains("count")
	assert_str(" ".join(PrimitiveLibrary.validate(&"clear_pattern", {&"offsets": []}))).contains("offsets")
	assert_str(" ".join(PrimitiveLibrary.validate(&"clear_line", {}))).contains("axis")
	assert_str(" ".join(PrimitiveLibrary.validate(&"lay_eggs_in_own_line", {&"prefer": &"sideways"}))).contains("prefer")
	assert_str(" ".join(PrimitiveLibrary.validate(&"clear_cross", {&"rech": 1}))).contains("unknown param")


func test_validation_rejects_float_where_int_required() -> void:
	# ADR-0001 Risks: a `.tres` value written as 2.0 loads as a float.
	var params := {&"radius": str_to_var("2.0")}
	assert_int(PrimitiveLibrary.validate(&"clear_area", params).size()).is_equal(1)


func test_validation_accepts_string_keys_and_valid_params() -> void:
	assert_array(Array(PrimitiveLibrary.validate(&"clear_cross", {"reach": -1}))).is_empty()
	assert_array(Array(PrimitiveLibrary.validate(&"lay_eggs_in_own_line", {&"count": 3, &"prefer": &"fuller", &"order": &"nearest"}))).is_empty()
	assert_array(Array(PrimitiveLibrary.validate(&"lay_eggs_pattern", {&"offsets": MONGSIL_OFFSETS}))).is_empty()


func test_kind_of_classifies_vocabulary() -> void:
	assert_int(PrimitiveLibrary.kind_of(&"clear_cross")).is_equal(PrimitiveLibrary.KIND_CLEAR)
	assert_int(PrimitiveLibrary.kind_of(&"lay_eggs_pattern")).is_equal(PrimitiveLibrary.KIND_FILL)
	assert_int(PrimitiveLibrary.kind_of(&"nope")).is_equal(PrimitiveLibrary.KIND_UNKNOWN)
