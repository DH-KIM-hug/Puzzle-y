## board-rules AC-02, AC-03, AC-04 — shape and instance validation, no rotation.
extends GdUnitTestSuite


func _errors(shape_id: StringName, offsets: Array) -> PackedStringArray:
	return BoardRules.validate_shape(PieceShape.make(shape_id, offsets), BoardConfig.new())


func test_invalid_shapes_are_all_rejected_with_id_and_reason() -> void:
	# Arrange / Act (AC-02)
	var cases := {
		&"EMPTY": [[], "empty"],
		&"DUP": [[Vector2i(0, 0), Vector2i(0, 0)], "duplicate"],
		&"UNNORM": [[Vector2i(1, 0), Vector2i(2, 0)], "normalised"],
		&"SPLIT": [[Vector2i(0, 0), Vector2i(0, 2)], "connected"],
		&"SEVEN": [[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5), Vector2i(0, 6)], "max_piece_cells"],
		&"NINE": [[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0)], "larger than board"],
	}
	for sid: StringName in cases:
		var errs := _errors(sid, cases[sid][0])
		# Assert
		assert_int(errs.size()).override_failure_message("shape %s accepted" % sid).is_greater(0)
		var joined := " | ".join(errs)
		assert_str(joined).contains(String(sid))
		assert_str(joined).contains(cases[sid][1])


func test_valid_shape_has_no_errors() -> void:
	assert_array(Array(_errors(&"L3_A", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]))).is_empty()


func test_horizontal_piece_does_not_fit_vertical_gap() -> void:
	# AC-03: no rotation. Only column 0 rows 0–2 are free.
	var rows: Array = []
	for r: int in 8:
		rows.append(".#######" if r < 3 else "########")
	var b := BoardFixture.board(rows)
	var bar := BoardFixture.piece([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)])
	assert_bool(BoardRules.any_fit(b, bar)).is_false()


func test_faceless_piece_validity_depends_on_stage_flag() -> void:
	# AC-04
	var config := BoardConfig.new()
	var faceless := BoardFixture.piece([Vector2i(0, 0), Vector2i(0, 1)])
	assert_int(BoardRules.validate_piece(faceless, config, false).size()).is_greater(0)
	assert_array(Array(BoardRules.validate_piece(faceless, config, true))).is_empty()


func test_face_index_equal_to_cell_count_is_rejected_in_both_modes() -> void:
	var config := BoardConfig.new()
	var bad := BoardFixture.piece([Vector2i(0, 0), Vector2i(0, 1)], BoardFixture.NYANGI, 2)
	assert_int(BoardRules.validate_piece(bad, config, false).size()).is_greater(0)
	assert_int(BoardRules.validate_piece(bad, config, true).size()).is_greater(0)
