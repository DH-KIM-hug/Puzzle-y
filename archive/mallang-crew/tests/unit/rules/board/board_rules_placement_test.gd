## board-rules AC-01, AC-05, AC-06, AC-14 (F1) — placement validity and purity.
extends GdUnitTestSuite

const L3: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]


func test_empty_board_from_config_is_all_empty() -> void:
	# Arrange
	var config := BoardConfig.new()
	# Act
	var b := BoardState.from_config(config)
	# Assert (AC-01)
	assert_int(b.cell_count()).is_equal(64)
	assert_int(b.filled_count()).is_equal(0)


func test_board_size_changes_with_data_only() -> void:
	var config := BoardConfig.new()
	config.board_width = 7
	config.board_height = 9
	var b := BoardState.from_config(config)
	assert_int(b.cell_count()).is_equal(63)
	assert_int(b.width).is_equal(7)
	assert_int(b.height).is_equal(9)


func test_can_place_l_shape_boundaries() -> void:
	# Arrange (AC-05)
	var b := BoardFixture.empty()
	var piece := BoardFixture.piece(L3)
	# Act / Assert
	assert_bool(BoardRules.can_place(b, piece, Vector2i(6, 0))).is_true()
	assert_bool(BoardRules.can_place(b, piece, Vector2i(7, 0))).is_false()
	assert_bool(BoardRules.can_place(b, piece, Vector2i(6, 7))).is_false()
	assert_bool(BoardRules.can_place(b, piece, Vector2i(-1, 0))).is_false()


func test_can_place_false_when_target_cell_occupied() -> void:
	var b := BoardFixture.board([
		"........", "........", "........", "........",
		"........", "........", "........", ".#......",
	])
	var piece := BoardFixture.piece(L3)
	assert_bool(BoardRules.can_place(b, piece, Vector2i(6, 0))).is_false()


func test_place_marks_only_face_offset_and_leaves_input_unchanged() -> void:
	# Arrange (AC-06)
	var b := BoardFixture.empty()
	var before := b.copy()
	var piece := BoardFixture.piece([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)], BoardFixture.NYANGI, 2)
	# Act
	var out := BoardRules.place(b, piece, Vector2i(0, 0), 5)
	# Assert
	assert_int(out.filled_count()).is_equal(3)
	assert_bool(out.is_face(out.index_of(0, 0))).is_false()
	assert_bool(out.is_face(out.index_of(0, 1))).is_false()
	assert_bool(out.is_face(out.index_of(0, 2))).is_true()
	assert_int(out.origin(out.index_of(0, 2))).is_equal(BoardState.ORIGIN_PIECE)
	assert_str(String(out.crew_at(out.index_of(0, 1)))).is_equal("nyangi")
	assert_int(out.placement_id[out.index_of(0, 0)]).is_equal(5)
	assert_bool(b.equals(before)).is_true()


func test_place_on_invalid_anchor_reports_error_and_keeps_board() -> void:
	var b := BoardFixture.empty()
	var piece := BoardFixture.piece(L3)
	await assert_error(func() -> void: BoardRules.place(b, piece, Vector2i(7, 0), 0)) \
		.is_push_error(BoardRules.ERR_PLACE_INVALID)
	assert_int(b.filled_count()).is_equal(0)


func test_anchor_count_two_by_three_is_42() -> void:
	# AC-14 / F1
	var b := BoardFixture.empty()
	var piece := BoardFixture.piece([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)])
	assert_int(BoardRules.anchor_count(b, piece)).is_equal(42)


func test_copy_does_not_share_modifiers() -> void:
	# ADR-0001 Review 1: modifiers must be deep-copied.
	var b := BoardFixture.empty()
	b.set_tile(0, &"", false, BoardState.ORIGIN_PIECE, 0)
	b.set_modifiers(0, PackedInt32Array([1]))
	var c := b.copy()
	var m: PackedInt32Array = c.modifiers[0]
	m.append(2)
	c.modifiers[0] = m
	assert_int((b.modifiers[0] as PackedInt32Array).size()).is_equal(1)


func test_public_functions_repeat_identically() -> void:
	# AC-13 (reduced): same inputs → same outputs and order, twice.
	var b := BoardFixture.board([
		"#######.", "....#...", "........", "...##...",
		"....#...", "........", "....#...", "#.######",
	])
	var piece := BoardFixture.piece(L3)
	for i: int in 2:
		var lines := BoardRules.full_lines(b)
		assert_int(lines.count()).is_equal(0)
		assert_bool(BoardRules.any_fit(b, piece)).is_true()
		assert_array(Array(BoardRules.empty_cells_in_line(b, BoardRules.AXIS_ROW, 0))).is_equal([7])
	assert_int(b.board_hash()).is_equal(b.copy().board_hash())
